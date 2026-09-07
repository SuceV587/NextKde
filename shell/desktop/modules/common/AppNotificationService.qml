pragma Singleton

import QtQuick
import Quickshell
import qs.desktop.modules.common

// AppNotificationService — Bridge for active desktop notification counts per app.
// NotificationGroupService populates this service, and DockIcon / other shell
// surfaces query it reactively using countForApp(appId, appName).
QtObject {
    id: svc

    // Array of { groupKey: string, appName: string, count: int }
    property var activeGroups: []
    property int revision: 0

    function updateFromGroups(nextGroups) {
        const groups = []
        if (Array.isArray(nextGroups)) {
            for (let i = 0; i < nextGroups.length; i++) {
                const g = nextGroups[i]
                if (g && g.count > 0) {
                    groups.push({
                        groupKey: String(g.groupKey ?? "").trim(),
                        appName: String(g.appName ?? "").trim(),
                        count: Number(g.count || 0)
                    })
                }
            }
        }
        activeGroups = groups
        revision++
    }

    function _normalize(value) {
        return AppPresentationService.normalize(value)
    }

    function countForApp(appId, appName) {
        // Read revision so QML bindings re-evaluate whenever revision increments
        const _ = svc.revision
        const groups = svc.activeGroups
        if (!groups || groups.length === 0)
            return 0

        const rawAppId = String(appId ?? "").trim()
        const rawAppName = String(appName ?? "").trim()
        const normAppId = _normalize(rawAppId)
        const normAppName = _normalize(rawAppName)

        let total = 0
        for (let i = 0; i < groups.length; i++) {
            const g = groups[i]
            if (!g || !g.count)
                continue

            const gKey = String(g.groupKey ?? "").trim()
            const gApp = String(g.appName ?? "").trim()
            const normGKey = _normalize(gKey)
            const normGApp = _normalize(gApp)

            let match = false
            if (gKey && (gKey === rawAppId || gKey + ".desktop" === rawAppId
                    || rawAppId + ".desktop" === gKey)) {
                match = true
            } else if (normGKey && (normGKey === normAppId || normGKey === normAppName)) {
                match = true
            } else if (normGApp && (normGApp === normAppId || normGApp === normAppName)) {
                match = true
            } else if (normAppId && normGKey && (normAppId.endsWith(normGKey) || normGKey.endsWith(normAppId))) {
                match = true
            }

            if (match)
                total += g.count
        }
        return total
    }

    function hasNotification(appId, appName) {
        return countForApp(appId, appName) > 0
    }
}
