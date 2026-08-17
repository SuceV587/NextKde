import Quickshell
import Quickshell.Io
import QtQuick

// Independent module root. It follows the same output-recreation pattern as
// Dock and QuickSearch, but has no import back into qs.modules.dock.
Scope {
    id: root

    // Load only the persisted presentation overrides at shell startup. This
    // instantiates a small service and one short-lived read process; it does
    // not create the launcher's window, GridView, or icon textures.
    function initializePresentationOverrides() {
        return AppLauncherConfigService.appOverrides
    }

    Component.onCompleted: {
        root.initializePresentationOverrides()
        console.log("[AppLauncher] module instantiated"
            + " targetScreen=" + !!targetScreen)
    }

    property bool open: AppLauncherService.open
    // The launcher owns a sizeable GridView, icon texture set, and glass
    // rendering chain. Keeping its window merely invisible still retains all
    // of those resources. Instantiate it when opened and release it shortly
    // after close, once the compositor has processed the visibility change.
    property bool windowLoaded: root.open
    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)
    onOpenChanged: {
        console.log("[AppLauncher] root open=" + open)
        if (open) {
            windowUnloadTimer.stop()
            windowLoaded = true
        } else {
            windowUnloadTimer.restart()
        }
    }
    onTargetScreenChanged: console.log("[AppLauncher] target screen changed="
        + !!targetScreen)

    IpcHandler {
        target: "applauncher"
        function show(): void { AppLauncherService.show() }
        function hide(): void { AppLauncherService.hide() }
        function toggle(): void { AppLauncherService.toggle() }
    }

    Timer {
        id: windowUnloadTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (!root.open)
                root.windowLoaded = false
        }
    }

    Variants {
        id: launcherVariants
        model: root.targetScreen ? [root.targetScreen] : []
        onModelChanged: console.log("[AppLauncher] variants model changed"
            + " target=" + !!root.targetScreen)

        Loader {
            id: launcherWindowLoader
            required property var modelData

            active: root.windowLoaded
            sourceComponent: Component {
                AppLauncherWindow {
                    screen: launcherWindowLoader.modelData
                    open: root.open
                }
            }
        }
    }
}
