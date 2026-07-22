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
        const dockItems = ConfigService.dockItems || [];
        const items = [];
        for (let i = 0; i < dockItems.length; i++) {
            const dockItem = dockItems[i];

            if (dockItem.type === "app") {
                const identity = AppIdentityService.resolve(dockItem.appId);
                const windows = WindowService.windowsForApp(identity.desktopId);
                items.push({
                    type: "app",
                    appId: identity.desktopId,
                    desktopId: identity.desktopId,
                    name: identity.name || dockItem.appId,
                    icon: windows[0]?.iconSource ?? identity.iconSource,
                    isRunning: windows.length > 0,
                    isActivated: windows.some(window => window.toplevel.activated),
                });
                continue;
            }

            if (dockItem.type === "folder") {
                const folderApps = [];
                for (let j = 0; j < dockItem.appIds.length; j++) {
                    const identity = AppIdentityService.resolve(dockItem.appIds[j]);
                    const windows = WindowService.windowsForApp(identity.desktopId);
                    folderApps.push({
                        appId: identity.desktopId,
                        name: identity.name || dockItem.appIds[j],
                        icon: windows[0]?.iconSource ?? identity.iconSource,
                    });
                }
                items.push({
                    type: "folder",
                    folderId: dockItem.id,
                    name: dockItem.name,
                    apps: folderApps,
                });
            }
        }
        svc.pinnedItems = items;
        svc.pinnedCount = items.length;
    }

    // Only a top-level pinned app owns its fixed Dock slot exclusively.
    // Apps inside folders are members of an aggregate launcher, but their
    // live windows still belong in the separate windows section.
    function _isTopLevelPinnedApp(appId) {
        const items = ConfigService.dockItems || [];
        for (let i = 0; i < items.length; i++) {
            const item = items[i];
            if (item.type === "app"
                    && AppIdentityService.sameApp(item.appId, appId))
                return true;
        }
        return false;
    }

    function _refreshWindowItems() {
        // A top-level pinned app is represented once, in its fixed Dock
        // location. Folder members are intentionally not filtered here, so
        // their live windows appear in the separate windows section.
        const records = WindowService.records || [];
        const nextItems = [];
        for (let i = 0; i < records.length; i++) {
            const record = records[i];
            if (_isTopLevelPinnedApp(record.identity.desktopId))
                continue;

            nextItems.push({
                windowId: record.windowId,
                desktopId: record.identity.desktopId,
                appId: record.identity.desktopId,
                rawAppId: record.identity.rawAppId,
                title: record.title,
                icon: record.iconSource ?? record.identity.iconSource,
                isActivated: record.toplevel.activated || false,
                isMinimized: record.toplevel.minimized || false,
                isFullscreen: record.toplevel.fullscreen || false,
            });
        }

        while (svc.windowModel.count > nextItems.length)
            svc.windowModel.remove(svc.windowModel.count - 1);

        for (let i = 0; i < nextItems.length; i++) {
            const item = nextItems[i];
            if (i >= svc.windowModel.count) {
                svc.windowModel.append(item);
                continue;
            }
            const row = svc.windowModel.get(i);
            const keys = Object.keys(item);
            for (let j = 0; j < keys.length; j++) {
                const key = keys[j];
                if (row[key] !== item[key])
                    svc.windowModel.setProperty(i, key, item[key]);
            }
        }
    }

    function _refreshPresentation() {
        _refreshPinned();
        _refreshWindowItems();
    }

    property Connections _windowConnections: Connections {
        target: WindowService
        function onRevisionChanged() {
            svc._refreshPresentation();
        }
    }

    property Connections _configConnections: Connections {
        target: ConfigService
        function onDockItemsChanged() {
            svc._refreshPresentation();
        }
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

    function movePinnedItem(type, key, targetIndex) {
        if (!ConfigService.moveDockItem(type, key, targetIndex))
            return
        console.log("[DockModel] reorder " + type + "=" + key
                    + " target=" + targetIndex)
        svc._refreshPresentation()
    }

    function renameFolder(folderId, newName) {
        if (!ConfigService.renameFolder(folderId, newName))
            return;
        console.log("[DockModel] rename folder=" + folderId
                    + " name=" + newName);
        svc._refreshPresentation();
    }

    function dissolveFolder(folderId) {
        if (!ConfigService.dissolveFolder(folderId))
            return;
        console.log("[DockModel] dissolve folder=" + folderId);
        svc._refreshPresentation();
    }

    function removeAppFromFolder(folderId, appId) {
        if (!ConfigService.removeAppFromFolder(folderId, appId))
            return;
        console.log("[DockModel] remove folder member folder=" + folderId
                    + " app=" + appId);
        svc._refreshPresentation();
    }

    function moveAppToFolder(folderId, appId) {
        const identity = AppIdentityService.resolve(appId)
        if (!ConfigService.moveAppToFolder(folderId, identity.desktopId))
            return;
        console.log("[DockModel] move app into folder=" + folderId
                    + " app=" + identity.desktopId);
        svc._refreshPresentation();
    }

    function createFolderWithApp(appId) {
        const identity = AppIdentityService.resolve(appId);
        if (!ConfigService.createFolderWithApp(identity.desktopId))
            return;
        console.log("[DockModel] create folder app=" + identity.desktopId
                    + " items=" + JSON.stringify(ConfigService.dockItems));
        svc._refreshPresentation();
    }

    Component.onCompleted: _refreshPresentation()
}
