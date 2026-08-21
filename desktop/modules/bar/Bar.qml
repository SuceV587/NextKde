import Quickshell
import Quickshell.Io
import qs.desktop.modules.bar

// Recreate the layer-shell window whenever KWin removes and re-adds outputs,
// which is exactly what happens around a sleep/resume cycle on some systems.
Scope {
    id: root

    // Bridge system tray attention signals into desktop notifications.
    TrayNotificationBridge {}

    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)

    // The global shortcut layer runs `qs ipc call control-center toggle`
    // (registered as a KDE Command Shortcut); the panel lives in BarWindow,
    // so this scope only forwards the intent through the shared service.
    IpcHandler {
        target: "control-center"
        function toggle(): void { ControlCenterService.toggleRequested() }
    }

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        BarWindow {
            required property var modelData
            screen: modelData
        }
    }
}
