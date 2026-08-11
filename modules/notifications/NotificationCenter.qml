import Quickshell
import Quickshell.Services.Notifications
import qs.modules.bar
import qs.modules.notifications

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
        actionsSupported: true
        imageSupported: true
        bodyImagesSupported: true
        inlineReplySupported: true
        keepOnReload: false

        onNotification: notification => {
            // Do Not Disturb still accepts the notification at D-Bus level,
            // but keeps it out of the visible banner stack. Untracked
            // notifications never reach dismiss/expire, so snapshot them into
            // the session history here or they would be lost entirely.
            if (ControlCenterService.doNotDisturbEnabled) {
                notification.tracked = false
                notifGroupService.pushHistory(notification)
            } else {
                notification.tracked = true
            }
        }
    }

    // Groups trackedNotifications by desktopEntry into a project-owned
    // ListModel. The popup and history views bind to this, not to the raw
    // read-only server model.
    NotificationGroupService {
        id: notifGroupService
        sourceModel: server.trackedNotifications
    }

    Variants {
        model: root.targetScreen ? [root.targetScreen] : []

        NotificationWindow {
            required property var modelData
            screen: modelData
            groupService: notifGroupService
        }
    }
}
