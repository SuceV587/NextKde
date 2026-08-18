import Quickshell
import Quickshell.Io

// Workspace overview controller. KWin owns the actual virtual-desktop
// switching; this module reads WindowService's desktop/window model and shows
// a Stage-Manager-style grid for the current desktop.
Scope {
    id: root

    property bool open: false
    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)

    function show() { open = true }
    function hide() { open = false }
    function toggle() { open = !open }

    IpcHandler {
        target: "overview"
        function show(): void { root.show() }
        function hide(): void { root.hide() }
        function toggle(): void { root.toggle() }
    }

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        OverviewWindow {
            required property var modelData
            screen: modelData
            open: root.open
        }
    }
}
