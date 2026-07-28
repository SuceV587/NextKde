import Quickshell
import Quickshell.Io
import QtQuick

// Independent module root. It follows the same output-recreation pattern as
// Dock and QuickSearch, but has no import back into qs.modules.dock.
Scope {
    id: root

    Component.onCompleted: console.log("[AppLauncher] module instantiated"
        + " targetScreen=" + !!targetScreen)

    property bool open: AppLauncherService.open
    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)
    onOpenChanged: console.log("[AppLauncher] root open=" + open)
    onTargetScreenChanged: console.log("[AppLauncher] target screen changed="
        + !!targetScreen)

    IpcHandler {
        target: "applauncher"
        function show(): void { AppLauncherService.show() }
        function hide(): void { AppLauncherService.hide() }
        function toggle(): void { AppLauncherService.toggle() }
    }

    Variants {
        id: launcherVariants
        model: root.targetScreen ? [root.targetScreen] : []
        onModelChanged: console.log("[AppLauncher] variants model changed"
            + " target=" + !!root.targetScreen)

        AppLauncherWindow {
            required property var modelData
            screen: modelData
            open: root.open
        }
    }
}
