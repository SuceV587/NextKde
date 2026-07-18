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
    // Presentation-only window list. WindowService keeps every live window;
    // this model hides windows whose app already has a stable pinned icon.
    // Keeping that policy here lets Alt+Tab and future Stage Manager views use
    // the complete WindowService model without inheriting Dock decisions.
    property ListModel windowModel: ListModel {}
    readonly property int windowCount: windowModel.count

    property var _bouncedKeys: ({})

    function shouldBounce(key) {
        if (!key)
            return false;
        if (svc._bouncedKeys[key])
            return false;
        svc._bouncedKeys[key] = true;
        return true;
    }

    function _refreshPinned() {
        const ids = ConfigService.pinnedAppIds || [];
        const items = [];
        for (let i = 0; i < ids.length; i++) {
            const identity = AppIdentityService.resolve(ids[i]);
            const windows = WindowService.windowsForApp(identity.desktopId);

            // iPadOS-style policy: a pinned app never moves. Runtime state is
            // visual metadata (dot + active background), not a reason to
            // remove its stable launcher position from the Dock.
            items.push({
                appId: identity.desktopId,
                desktopId: identity.desktopId,
                name: identity.name || ids[i],
                icon: identity.iconSource,
                isRunning: windows.length > 0,
                isActivated: windows.some(window => window.toplevel.activated),
            });
        }
        svc.pinnedItems = items;
        svc.pinnedCount = items.length;
    }

    function _isPinnedApp(appId) {
        const ids = ConfigService.pinnedAppIds || [];
        for (let i = 0; i < ids.length; i++) {
            if (AppIdentityService.sameApp(ids[i], appId))
                return true;
        }
        return false;
    }

    function _refreshWindowItems() {
        // A pinned app is represented once, in its fixed Dock location. Its
        // individual windows deliberately stay available in WindowService for
        // window previews, Alt+Tab, and future Stage Manager UI.
        const records = WindowService.records || [];
        svc.windowModel.clear();
        for (let i = 0; i < records.length; i++) {
            const record = records[i];
            if (_isPinnedApp(record.identity.desktopId))
                continue;

            svc.windowModel.append({
                windowId: record.windowId,
                desktopId: record.identity.desktopId,
                appId: record.identity.desktopId,
                rawAppId: record.identity.rawAppId,
                title: record.title,
                icon: record.identity.iconSource,
                isActivated: record.toplevel.activated || false,
                isMinimized: record.toplevel.minimized || false,
                isFullscreen: record.toplevel.fullscreen || false,
            });
        }
    }

    function _refreshPresentation() {
        _refreshPinned();
        _refreshWindowItems();
        const runningPinned = svc.pinnedItems.filter(item => item.isRunning).length;
        console.log("[DockModel] presentation pinned=" + svc.pinnedCount
                    + " runningPinned=" + runningPinned
                    + " unpinnedWindows=" + svc.windowCount);
    }

    property Connections _windowConnections: Connections {
        target: WindowService
        function onRevisionChanged() {
            svc._refreshPresentation();
        }
    }

    property Connections _configConnections: Connections {
        target: ConfigService
        function onPinnedAppIdsChanged() {
            svc._refreshPresentation();
        }
    }

    property Connections _identityConnections: Connections {
        target: AppIdentityService
        function onRevisionChanged() {
            svc._refreshPresentation();
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
        if (!ConfigService.addAppItem(identity.desktopId))
            return;
        console.log("[DockModel] pin app=" + identity.desktopId
                    + " items=" + JSON.stringify(ConfigService.dockItems));
        svc._refreshPresentation();
    }

    function unpinApp(appId) {
        const wanted = AppIdentityService.canonicalId(appId);
        if (!ConfigService.removeAppItem(wanted))
            return;
        console.log("[DockModel] unpin app=" + wanted
                    + " items=" + JSON.stringify(ConfigService.dockItems));
        svc._refreshPresentation();
    }

    Component.onCompleted: _refreshPresentation()
}
