import Quickshell
import Quickshell.Services.Notifications
import qs.modules.bar

// The session D-Bus permits only one org.freedesktop.Notifications owner.
// When Plasma's daemon owns it, this server stays inactive, so notifications
// are never displayed twice.
Scope {
    id: root

    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1]
        : (Quickshell.screens[0] ?? null)
    NotificationServer {
        id: server
        bodySupported: true
        bodyMarkupSupported: false
        actionsSupported: false
        imageSupported: true
        bodyImagesSupported: true
        keepOnReload: false

        onNotification: notification => {
            // Do Not Disturb still accepts the notification at D-Bus level,
            // but deliberately keeps it out of the visible QuickShell stack.
            notification.tracked = !ControlCenterService.doNotDisturbEnabled
        }
    }

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        NotificationWindow {
            required property var modelData
            screen: modelData
            notifications: server.trackedNotifications
        }
    }
}
