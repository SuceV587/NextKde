pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.desktop.modules.platform

// 剪贴板模型的唯一所有者：历史条目、固定条目、图片缩略图，以及
// 「点一下就输入」的粘贴调度。
//
// 职责边界：
//   - 历史采集仍由 kos-platform 托管的 cliphist 负责（wl-paste --watch），
//     这里只解析并持有模型；
//   - 固定条目与缩略图落在 Quickshell.stateDir/clipboard/ 下，由 kos-clipboard
//     辅助脚本维护 —— 图片等二进制内容不进 QML 字符串；
//   - 剪贴板写入走 kos-platform 的 clipboard.history.* op（它已封装
//     cliphist decode + wl-copy 的完整链路），只有按键注入必须用脚本，
//     因为那需要 uinput 权限。
QtObject {
    id: service

    // ---- 辅助脚本 ----
    // 必须用绝对路径：Shell 由 systemd 拉起，PATH 未必包含 ~/.local/bin。
    readonly property string helper: {
        const home = Quickshell.env("HOME")
        return home ? home + "/.local/bin/kos-clipboard" : "kos-clipboard"
    }

    // ---- 持久化偏好（沿用原有 config.json 契约） ----
    readonly property string configDir: Quickshell.stateDir + "/clipboard"
    readonly property string configPath: configDir + "/config.json"
    property bool watchImages: true
    property int maxItems: 200

    // ---- 历史 ----
    property var entries: []
    property int revision: 0

    // ---- 固定条目：[{ pinId, isImage, preview }] ----
    property var pinned: []
    property int pinnedRevision: 0

    // ---- 缩略图：条目 id -> file:// URL ----
    property var thumbnails: ({})
    property int thumbnailRevision: 0

    // 粘贴注入总开关。关掉后所有动作退化成「只复制」，便于排查是复制
    // 环节还是注入环节出了问题。
    property bool pasteEnabled: true

    readonly property string pinnedDir: service.configDir + "/pinned"

    // ================================================================ 偏好
    function setWatchImages(enabled) {
        if (service.watchImages === enabled)
            return
        service.watchImages = enabled
        _syncWatchImages()
        service.scheduleSave()
    }

    function setMaxItems(count) {
        const clamped = Math.max(20, Math.min(1000, count))
        if (service.maxItems === clamped)
            return
        service.maxItems = clamped
        service.scheduleSave()
        service.refresh()
    }

    property Timer _saveTimer: Timer {
        interval: 300
        repeat: false
        onTriggered: service._save()
    }
    function scheduleSave() { _saveTimer.restart() }

    function _save() {
        const json = JSON.stringify({
            watchImages: service.watchImages,
            maxItems: service.maxItems,
        }, null, 2)
        const proc = processFactory.createObject(service, {
            command: ["sh", "-c",
                      "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/config.json.tmp\" && mv \"$1/config.json.tmp\" \"$1/config.json\"",
                      "clipboard-config-save", configDir, json],
        })
        proc.exited.connect(function(code) {
            if (code !== 0)
                console.warn("[Clipboard] 保存偏好失败")
            proc.destroy()
        })
        proc.running = true
    }

    function _syncWatchImages() {
        PlatformClient.request("clipboard.history.watch-images",
            { enabled: service.watchImages }, function(response) {
            if (!response?.ok)
                console.warn("[Clipboard] 图片历史监听不可用: "
                    + (response?.error?.message || "platform 不可用"))
        })
    }

    function load() {
        const proc = processFactory.createObject(service, {
            command: ["sh", "-c", "cat \"$1\"", "clipboard-config-load", configPath],
        })
        proc.exited.connect(function(code) {
            const output = proc.stdout?.text ?? ""
            if (code === 0 && output) {
                try {
                    const saved = JSON.parse(output)
                    if (typeof saved.watchImages === "boolean")
                        service.watchImages = saved.watchImages
                    if (typeof saved.maxItems === "number" && saved.maxItems > 0)
                        service.maxItems = saved.maxItems
                } catch (e) {
                    console.warn("[Clipboard] 偏好解析失败: " + e)
                }
            }
            service._syncWatchImages()
            proc.destroy()
        })
        proc.running = true
    }

    // ================================================================ 历史
    function refresh() {
        if (_listInFlight)
            return
        _listInFlight = true
        PlatformClient.request("clipboard.history.list", {}, function(response) {
            service._listInFlight = false
            if (response?.ok)
                service._readList(response.result?.stdout ?? "")
            else if (response?.error?.code !== "command-unavailable")
                console.warn("[Clipboard] 读取历史失败: "
                    + (response?.error?.message || "platform 不可用"))
        })
    }
    property bool _listInFlight: false

    function deleteEntry(selectionRecord) {
        if (!selectionRecord)
            return
        PlatformClient.request("clipboard.history.delete",
            { record: String(selectionRecord) }, function(response) {
            if (response?.ok)
                service.refresh()
            else
                console.warn("[Clipboard] 删除条目失败: "
                    + (response?.error?.message || "platform 不可用"))
        })
    }

    function clearAll() {
        PlatformClient.request("clipboard.history.clear", {}, function(response) {
            if (response?.ok) {
                service.entries = []
                service.revision += 1
                service.refresh()
            } else {
                console.warn("[Clipboard] 清空历史失败: "
                    + (response?.error?.message || "platform 不可用"))
            }
        })
    }

    function _readList(output) {
        const parsed = []
        const lines = output.split("\n")
        const limit = service.maxItems > 0 ? service.maxItems : 200
        for (let i = 0; i < lines.length && parsed.length < limit; i++) {
            const tab = lines[i].indexOf("\t")
            if (tab <= 0)
                continue
            const entryId = lines[i].slice(0, tab)
            const preview = lines[i].slice(tab + 1).trim()
            if (preview) {
                // cliphist 把解码后的图片预览格式化成
                // "[[ binary data 123 KiB png 1920x1080 ]]"。
                // 不能凭文件名推断图片，比如 "screenshot.png" 是纯文本。
                const isImage = /^\[\[ binary data .+ (png|jpe?g|gif|bmp|tiff?|webp) \d+x\d+ \]\]$/i.test(preview)
                parsed.push({
                    id: entryId,
                    preview: preview,
                    record: lines[i],
                    isImage: isImage,
                })
            }
        }
        entries = parsed
        revision += 1
    }

    // ================================================================ 固定
    function refreshPinned() {
        if (_pinnedInFlight)
            return
        _pinnedInFlight = true
        _runHelper(["pinned-list"], function(code, proc) {
            service._pinnedInFlight = false
            if (code === 0)
                service._readPinned(proc.stdout?.text ?? "")
            else
                console.warn("[Clipboard] 读取固定条目失败: "
                    + (proc.stderr?.text ?? ""))
        })
    }
    property bool _pinnedInFlight: false

    function _readPinned(output) {
        const parsed = []
        const lines = output.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split("\t")
            if (parts.length < 3 || !parts[0])
                continue
            parsed.push({
                pinId: parts[0],
                isImage: parts[1] === "image",
                // preview 原文可能含制表符，所以第 3 段之后要重新拼回去。
                preview: parts.slice(2).join("\t"),
                // 固定图片已经以真 PNG 落盘，Image 元素可以直接加载。
                thumbnail: parts[1] === "image"
                    ? "file://" + service.pinnedDir + "/" + parts[0] + ".png"
                    : "",
            })
        }
        pinned = parsed
        pinnedRevision += 1
    }

    function pinEntry(entry) {
        if (!entry || !entry.record)
            return
        if (pinIdFor(entry))
            return   // 已经固定过，避免重复
        _runHelper(["pin", String(entry.record)], function(code, proc) {
            if (code === 0)
                service.refreshPinned()
            else
                console.warn("[Clipboard] 固定条目失败: " + (proc.stderr?.text ?? ""))
        })
    }

    function unpinById(pinId) {
        if (!pinId)
            return
        _runHelper(["unpin", String(pinId)], function(code, proc) {
            if (code === 0)
                service.refreshPinned()
            else
                console.warn("[Clipboard] 取消固定失败: " + (proc.stderr?.text ?? ""))
        })
    }

    // 历史条目与固定条目之间靠 preview + 类型对应：cliphist 的 id 会随
    // 历史轮转变化，不能拿它当稳定标识。
    function pinIdFor(entry) {
        if (!entry)
            return ""
        for (let i = 0; i < service.pinned.length; i++) {
            const item = service.pinned[i]
            if (item.preview === entry.preview && item.isImage === entry.isImage)
                return item.pinId
        }
        return ""
    }

    // ================================================================ 缩略图
    // 幂等：同一条目重复调用只会起一次解码进程，未就绪时返回空串，
    // 就绪后通过 thumbnailRevision 通知调用方重新求值。
    function thumbnailFor(entry) {
        if (!entry || !entry.isImage || !entry.id)
            return ""
        const cached = service.thumbnails[entry.id]
        if (cached !== undefined)
            return cached
        if (service._thumbnailPending[entry.id])
            return ""
        service._thumbnailPending[entry.id] = true
        _runHelper(["thumb", String(entry.record)], function(code, proc) {
            const pending = Object.assign({}, service._thumbnailPending)
            delete pending[entry.id]
            service._thumbnailPending = pending
            const path = (proc.stdout?.text ?? "").trim()
            if (code === 0 && path) {
                const next = Object.assign({}, service.thumbnails)
                next[entry.id] = "file://" + path
                service.thumbnails = next
                service.thumbnailRevision += 1
            }
            // 解码失败不重试，否则列表滚动时会反复起进程。
        })
        return ""
    }
    property var _thumbnailPending: ({})

    // ================================================================ 剪贴板写入
    // 「点一下就输入」在这里只做前半段：把内容写进剪贴板。
    //
    // 用回调而不是定时器通知调用方「写好了」：历史条目的写入由 kos-platform
    // 在 wl-copy 真正退出后才回 ok，那个回调就是可靠的「内容已就位」判定点。
    // 注入时机留给控制器决定 —— 只有它知道面板弹出前的活动窗口是谁。
    function copyRecord(record, done) {
        if (!record) {
            if (done)
                done(false)
            return
        }
        PlatformClient.request("clipboard.history.copy",
            { record: String(record) }, function(response) {
            const ok = !!response?.ok
            if (!ok)
                console.warn("[Clipboard] 复制失败: "
                    + (response?.error?.message || "platform 不可用"))
            if (done)
                done(ok)
        })
    }

    function copyPinned(pinId, done) {
        if (!pinId) {
            if (done)
                done(false)
            return
        }
        _runHelper(["pinned-copy", String(pinId)], function(code, proc) {
            const ok = code === 0
            if (!ok)
                console.warn("[Clipboard] 固定条目写入剪贴板失败: "
                    + (proc.stderr?.text ?? ""))
            if (done)
                done(ok)
        })
    }

    // 把 Ctrl+V 打到当前持有键盘焦点的窗口。调用方负责先确认焦点已经回到
    // 目标窗口 —— 排队中的按键注入不会等任何人。
    function injectPaste() {
        _runHelper(["paste"], function(code, proc) {
            if (code !== 0)
                console.warn("[Clipboard] 按键注入失败: " + (proc.stderr?.text ?? ""))
        })
    }

    // ================================================================ 杂项
    function openShortcutSettings() {
        PlatformClient.request("settings.open", { module: "kcm_keys" },
            function(response) {
                if (!response?.ok)
                    console.warn("[Clipboard] 快捷键设置不可用: "
                        + (response?.error?.message || "platform 不可用"))
            })
    }

    function _runHelper(args, onDone) {
        const proc = processFactory.createObject(service, {
            command: [service.helper].concat(args),
        })
        proc.exited.connect(function(code) {
            if (onDone)
                onDone(code, proc)
            proc.destroy()
        })
        proc.running = true
        return proc
    }

    property Connections platformTransport: Connections {
        target: PlatformClient
        function onTransportChanged(connected) {
            if (connected) {
                service._syncWatchImages()
                service.refresh()
                service.refreshPinned()
            }
        }
    }

    Component.onCompleted: {
        load()
        refresh()
        refreshPinned()
    }

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }
}
