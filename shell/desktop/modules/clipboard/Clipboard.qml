import QtQuick
import Quickshell
import Quickshell.Io
import qs.desktop.modules.common
import qs.desktop.modules.dock

// Meta+V 的入口，也是「点一下就输入」的调度者。
//
// 为什么注入时机要在这里管而不是给个固定延迟：Ctrl+V 会被合成器投递给
// 「此刻持有键盘焦点的窗口」，而面板关闭后这个焦点是异步交接的。实测固定
// 延迟两头不讨好 —— 350ms 时焦点往往还没回来（粘贴丢失），1s 又明显卡手。
// 所以改成盯着 WindowService 的活动窗口，一变成面板弹出前的那个就立刻注入。
Scope {
    id: root

    property bool open: false
    readonly property var targetScreen: ScreenLifecycle.activeScreen

    // 面板弹出前的活动窗口。layer-shell 面板会抢走键盘焦点，关闭后 KWin 会
    // 把焦点还回来 —— 但那是异步的。记着 id 用来判断「还回来了没」。
    property string _focusReturnId: ""

    // 一次粘贴请求的生命周期：等复制完成 → 等焦点归位 → 注入。
    property bool _pastePending: false
    property bool _copySettled: false
    property bool _copyOk: false

    readonly property string pasteStage: {
        if (!_pastePending)
            return "idle"
        if (!_copySettled)
            return "copying"
        return "waiting-focus"
    }

    function show() {
        if (!ScreenLifecycle.outputAvailable || targetScreen === null) {
            console.warn("[Clipboard] 拒绝显示面板：outputAvailable="
                + ScreenLifecycle.outputAvailable
                + " screen=" + (targetScreen ? targetScreen.name : "null"))
            return
        }
        cancelPaste()
        // 必须在面板显示之前取：layer surface 一旦拿到键盘焦点，
        // WindowService 的 activeWindowId 就会变空。
        _focusReturnId = WindowService.activeWindowId
        open = true
    }
    function hide() { open = false }
    function toggle() {
        if (open)
            hide()
        else
            show()
    }

    function cancelPaste() {
        _pastePending = false
        _copySettled = false
        _copyOk = false
        focusPollTimer.stop()
    }

    // 面板里选中了一条内容。copyOnly 表示只写剪贴板、不往窗口里打字。
    function beginPaste(item, copyOnly) {
        if (!item)
            return
        _pastePending = !copyOnly && ClipboardService.pasteEnabled
        _copySettled = false
        _copyOk = false

        const done = function(ok) {
            root._copySettled = true
            root._copyOk = ok
            if (!ok || !root._pastePending) {
                root._pastePending = false
                return
            }
            // 内容已就位，接下来等焦点归位。
            focusPollTimer.elapsed = 0
            focusPollTimer.restart()
        }

        if (item.source === "pinned")
            ClipboardService.copyPinned(item.pinId, done)
        else
            ClipboardService.copyRecord(item.record, done)
    }

    // 40ms 一拍地看焦点回来没有。等不到就超时放行 —— 宁可偶尔迟到，
    // 也不要让一次点击彻底没反应。
    Timer {
        id: focusPollTimer
        interval: 40
        repeat: true
        property int elapsed: 0
        onTriggered: {
            elapsed += interval
            const target = root._focusReturnId
            const home = target === "" || WindowService.activeWindowId === target
            if (home || elapsed >= 1200) {
                stop()
                elapsed = 0
                root._pastePending = false
                ClipboardService.injectPaste()
            }
        }
    }

    // 调试入口：qs ipc call clipboard state
    function state() {
        return JSON.stringify({
            open: root.open,
            outputAvailable: ScreenLifecycle.outputAvailable,
            screen: root.targetScreen ? String(root.targetScreen.name) : "null",
            panelVisible: panelWindow.visible,
            historyCount: (ClipboardService.entries || []).length,
            pinnedCount: (ClipboardService.pinned || []).length,
            focusReturnId: root._focusReturnId,
            activeWindowId: WindowService.activeWindowId,
            pasteStage: root.pasteStage,
        })
    }

    IpcHandler {
        target: "clipboard"

        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function toggle(): void { root.toggle() }
        function state(): string { return root.state() }
    }

    ClipboardWindow {
        id: panelWindow
        screen: root.targetScreen
        visible: root.open && ScreenLifecycle.outputAvailable
            && root.targetScreen !== null
        open: root.open
        onCloseRequested: root.hide()
        onPasteRequested: function (item, copyOnly) { root.beginPaste(item, copyOnly) }
    }
}
