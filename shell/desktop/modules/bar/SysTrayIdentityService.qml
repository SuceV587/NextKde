pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// 系统托盘应用身份智能解析服务 / System Tray Identity Service
// 负责通过 D-Bus 与进程属性解析未规范设置 Title 的托盘项（如 Linux QQ、Antigravity 等 Electron 应用）
QtObject {
    id: svc

    // 解析后的应用名映射字典：itemId -> 友好应用名
    property var resolvedNames: ({})
    property int revision: 0
    property bool _refreshing: false

    // 内置常见已知应用快速别名表（作为零延迟同步缓存）
    readonly property var _knownAliases: ({
        "qq": "QQ",
        "linuxqq": "QQ",
        "antigravity": "Antigravity",
        "rustdesk": "RustDesk",
        "karing": "Karing",
        "sunshine": "Sunshine",
        "wechat": "微信",
        "fcitx": "输入法",
        "fcitx5": "输入法",
        "google-chrome": "Google Chrome",
        "chrome": "Google Chrome",
        "chromium": "Chromium",
        "code": "VS Code"
    })

    // 判断一个 ID 是否为生硬的内部生成标识符
    function isInternalId(id) {
        if (!id || typeof id !== "string") return true
        const str = id.trim()
        if (str.length === 0) return true
        // Chromium / Electron 自动生成的托盘 ID
        if (str.indexOf("chrome_status_icon") === 0) return true
        if (str.indexOf("_status_icon_") >= 0) return true
        if (str.indexOf("tray-icon tray app") === 0) return true
        // 随机生成的无意义短哈希标识（如 2cUW32wlKy）
        if (/^[0-9a-zA-Z]{8,16}$/.test(str) && !/^[A-Z][a-z]+$/.test(str)) return true
        return false
    }

    // 获取托盘项的友好显示名称
    function friendlyName(item) {
        if (!item) return ""
        const _rev = svc.revision // 触发 QML 响应式依赖

        // 1. 优先使用显式设置的有效 Tooltip 标题
        if (item.tooltipTitle && typeof item.tooltipTitle === "string" && item.tooltipTitle.trim().length > 0) {
            const tt = item.tooltipTitle.trim()
            if (!isInternalId(tt)) return tt
        }

        // 2. 其次使用显式设置的有效 Title
        if (item.title && typeof item.title === "string" && item.title.trim().length > 0) {
            const title = item.title.trim()
            if (!isInternalId(title)) return title
        }

        const id = (item.id || "").trim()

        // 3. 从异步解析结果中查找
        if (id && svc.resolvedNames[id]) {
            return svc.resolvedNames[id]
        }

        // 4. 同步规则快速预判（针对常见生硬 ID 进行即时兜底，无需等待进程查询）
        if (id.indexOf("chrome_status_icon") === 0) {
            return "QQ" // Linux 环境下最典型的 Electron 托盘应用
        }
        if (id.indexOf("Antigravity") === 0) {
            return "Antigravity"
        }

        // 5. 如果 id 自身是有意义的可读名称，则可以作为兜底
        if (id && !isInternalId(id)) {
            // 如果已知别名中有，返回优化名称
            const lower = id.toLowerCase()
            if (svc._knownAliases[lower]) {
                return svc._knownAliases[lower]
            }
            return id
        }

        // 6. 若完全为内部生硬 ID 且尚未解析出，则安全返回空，避免把内部 ID 显示给用户
        return ""
    }

    // 触发异步解析更新
    function refresh() {
        if (svc._refreshing) return
        svc._refreshing = true

        const pythonScript = `
import dbus, json

def resolve():
    mapping = {}
    try:
        bus = dbus.SessionBus()
        watcher = bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
        items = watcher.Get("org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems", dbus_interface="org.freedesktop.DBus.Properties")
        dbus_obj = bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus")
        dbus_iface = dbus.Interface(dbus_obj, "org.freedesktop.DBus")

        aliases = {
            "qq": "QQ", "linuxqq": "QQ", "antigravity": "Antigravity",
            "rustdesk": "RustDesk", "karing": "Karing", "sunshine": "Sunshine",
            "wechat": "微信", "fcitx5": "输入法", "fcitx": "输入法",
            "google-chrome": "Google Chrome", "chrome": "Google Chrome",
            "chromium": "Chromium", "code": "VS Code"
        }

        for item in items:
            parts = item.split("/", 1)
            service = parts[0]
            path = "/" + parts[1]
            try:
                item_obj = bus.get_object(service, path)
                item_id = str(item_obj.Get("org.kde.StatusNotifierItem", "Id", dbus_interface="org.freedesktop.DBus.Properties"))
                item_title = str(item_obj.Get("org.kde.StatusNotifierItem", "Title", dbus_interface="org.freedesktop.DBus.Properties"))
                pid = dbus_iface.GetConnectionUnixProcessID(service)
                comm = ""
                try:
                    with open(f"/proc/{pid}/comm", "r") as f:
                        comm = f.read().strip().lower()
                except Exception:
                    pass
                cmd = ""
                try:
                    with open(f"/proc/{pid}/cmdline", "rb") as f:
                        cmd = f.read().replace(b"\\0", b" ").decode(errors="ignore").strip().lower()
                except Exception:
                    pass

                name = ""
                if "qq" in comm or "/qq/" in cmd or "linuxqq" in cmd:
                    name = "QQ"
                elif comm in aliases:
                    name = aliases[comm]
                elif item_title:
                    name = item_title
                elif comm:
                    name = comm.capitalize()

                if item_id and name:
                    mapping[item_id] = name
            except Exception:
                pass
    except Exception:
        pass
    return mapping

print(json.dumps(resolve(), ensure_ascii=False))
`

        const proc = _makeProc(["python3", "-c", pythonScript])
        if (!proc) {
            svc._refreshing = false
            return
        }

        proc.exited.connect(function(code) {
            svc._refreshing = false
            const output = proc.stdout?.text ?? ""
            if (code === 0 && output) {
                try {
                    const data = JSON.parse(output)
                    let changed = false
                    const next = Object.assign({}, svc.resolvedNames)
                    for (const k in data) {
                        if (next[k] !== data[k]) {
                            next[k] = data[k]
                            changed = true
                        }
                    }
                    if (changed) {
                        svc.resolvedNames = next
                        svc.revision++
                    }
                } catch (e) {
                    console.warn("[SysTrayIdentityService] parse error:", e)
                }
            }
            proc.destroy()
        })
        proc.running = true
    }

    property Component _procFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    function _makeProc(command) {
        try {
            return _procFactory.createObject(svc, { command: command })
        } catch (e) {
            console.warn("[SysTrayIdentityService] cannot create Process:", e)
        }
        return null
    }

    // 监听托盘项数量与增删变化
    property Instantiator _trayWatcher: Instantiator {
        model: SystemTray.items
        delegate: QtObject {
            required property var modelData
            property Connections _itemConn: Connections {
                target: modelData
                function onIdChanged() { svc.refresh() }
                function onTitleChanged() { svc.refresh() }
                function onTooltipTitleChanged() { svc.refresh() }
            }
        }
        onObjectAdded: svc.refresh()
        onObjectRemoved: svc.refresh()
    }

    Component.onCompleted: {
        svc.refresh()
    }
}
