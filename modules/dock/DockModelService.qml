pragma Singleton
import QtQuick

// DockModelService — compatibility facade for the current Dock UI.
//
// AppIdentityService owns application identity resolution.
// WindowService owns the live Wayland Toplevel model and window actions.
// AppGroupService owns reusable app/window grouping.
// This facade only derives the current Dock presentation and keeps the old
// DockContainer bindings stable while future UIs consume the lower layers.

QtObject {
    id: svc

    property var pinnedItems: []
    property int pinnedCount: 0
    readonly property ListModel windowModel: WindowService.windowModel
    readonly property int windowCount: WindowService.windowCount

    property var _bouncedKeys: ({})
    property string _pinStateCache: ""

    function shouldBounce(key) {
        if (!key)
            return false;
        if (svc._bouncedKeys[key])
            return false;
        svc._bouncedKeys[key] = true;
        return true;
    }

    function _pinnedStateKey() {
        const ids = ConfigService.pinnedAppIds || [];
        const running = [];
        for (let i = 0; i < ids.length; i++) {
            const desktopId = AppIdentityService.canonicalId(ids[i]);
            running.push(WindowService.windowsForApp(desktopId).length > 0 ? "1" : "0");
        }
        return ids.join(",") + "|" + running.join("");
    }

    function _refreshPinned() {
        const stateKey = _pinnedStateKey();
        if (stateKey === svc._pinStateCache)
            return;
        svc._pinStateCache = stateKey;

        const ids = ConfigService.pinnedAppIds || [];
        const items = [];
        for (let i = 0; i < ids.length; i++) {
            const identity = AppIdentityService.resolve(ids[i]);
            const windows = WindowService.windowsForApp(identity.desktopId);

            // Current Dock policy: an app is represented by its live window(s)
            // while running, and by its pinned launcher only when closed.
            if (windows.length > 0)
                continue;

            items.push({
                appId: identity.desktopId,
                desktopId: identity.desktopId,
                name: identity.name || ids[i],
                icon: identity.iconSource,
                isRunning: false,
                isActivated: false,
            });
        }
        svc.pinnedItems = items;
        svc.pinnedCount = items.length;
    }

    property Connections _windowConnections: Connections {
        target: WindowService
        function onRevisionChanged() {
            svc._refreshPinned();
        }
    }

    property Connections _configConnections: Connections {
        target: ConfigService
        function onPinnedAppIdsChanged() {
            svc._pinStateCache = "";
            svc._refreshPinned();
        }
    }

    property Connections _identityConnections: Connections {
        target: AppIdentityService
        function onRevisionChanged() {
            svc._pinStateCache = "";
            svc._refreshPinned();
        }
    }

    function activateApp(appId) {
        const identity = AppIdentityService.resolve(appId);
        const windows = WindowService.windowsForApp(identity.desktopId);

        if (windows.length === 0) {
            console.log("[DockModel] launch app=" + identity.desktopId);
            try {
                if (identity.entry?.execute)
                    identity.entry.execute();
            } catch (e) {
                console.warn("[DockModel] failed to launch app=" + identity.desktopId + ": " + e);
            }
            return;
        }

        let active = null;
        for (let i = 0; i < windows.length; i++) {
            if (windows[i].toplevel.activated) {
                active = windows[i];
                break;
            }
        }

        if (active) {
            console.log("[DockModel] minimize app=" + identity.desktopId
                        + " windows=" + windows.length);
            for (let i = 0; i < windows.length; i++)
                WindowService.minimizeWindow(windows[i].windowId, true);
        } else {
            console.log("[DockModel] activate app=" + identity.desktopId);
            WindowService.activateWindow(windows[0].windowId);
        }
    }

    function activateWindow(windowId) {
        WindowService.activateWindow(windowId);
    }

    function minimizeWindow(windowId) {
        WindowService.minimizeWindow(windowId, true);
    }

    function closeWindow(windowId) {
        WindowService.closeWindow(windowId);
    }

    function pinApp(appId) {
        const identity = AppIdentityService.resolve(appId);
        const ids = (ConfigService.pinnedAppIds || []).slice();
        for (let i = 0; i < ids.length; i++) {
            if (AppIdentityService.sameApp(ids[i], identity.desktopId))
                return;
        }
        ids.push(identity.desktopId);
        ConfigService.pinnedAppIds = ids;
        console.log("[DockModel] pin app=" + identity.desktopId
                    + " pinned=" + JSON.stringify(ids));
        ConfigService.scheduleSave();
        svc._pinStateCache = "";
        svc._refreshPinned();
    }

    function unpinApp(appId) {
        const wanted = AppIdentityService.canonicalId(appId);
        const ids = (ConfigService.pinnedAppIds || []).slice();
        const remaining = [];
        for (let i = 0; i < ids.length; i++) {
            if (!AppIdentityService.sameApp(ids[i], wanted))
                remaining.push(ids[i]);
        }
        if (remaining.length === ids.length)
            return;
        ConfigService.pinnedAppIds = remaining;
        console.log("[DockModel] unpin app=" + wanted
                    + " pinned=" + JSON.stringify(remaining));
        ConfigService.scheduleSave();
        svc._pinStateCache = "";
        svc._refreshPinned();
    }

    Component.onCompleted: _refreshPinned()
}
