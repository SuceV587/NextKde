pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland._ToplevelManagement

// WindowService — provider-neutral runtime window model.
//
// It currently uses Quickshell's Wayland Toplevel API. The public model uses
// canonical desktopId values from AppIdentityService, so a future Hyprland
// metadata adapter can add class/initialClass without changing Dock, Alt+Tab,
// or Stage Manager consumers.

QtObject {
    id: svc

    property ListModel windowModel: ListModel {}
    readonly property int windowCount: windowModel.count
    property var records: []
    property int revision: 0
    property string activeWindowId: ""

    property int _nextWindowNumber: 1
    property var _recordsById: ({})

    property Repeater _topRepeater: Repeater {
        model: ToplevelManager.toplevels
        delegate: Item {
            id: toplevelDelegate
            readonly property Toplevel toplevel: modelData

            property Connections changeConnection: Connections {
                target: toplevelDelegate.toplevel
                function onActivatedChanged() { svc._scheduleUpdate() }
                function onMinimizedChanged() { svc._scheduleUpdate() }
                function onTitleChanged() { svc._scheduleUpdate() }
                function onAppIdChanged() { svc._scheduleUpdate() }
                function onClosed() { svc._scheduleUpdate() }
            }
        }
    }

    property Timer _updateTimer: Timer {
        interval: 40
        repeat: false
        onTriggered: svc._rebuild()
    }

    property Timer _countPoll: Timer {
        interval: 500
        repeat: true
        running: true
        property int previousCount: -1
        onTriggered: {
            if (previousCount !== svc._topRepeater.count) {
                previousCount = svc._topRepeater.count;
                svc._scheduleUpdate();
            }
        }
    }

    property Connections _managerConnections: Connections {
        target: ToplevelManager
        function onActiveToplevelChanged() { svc._scheduleUpdate() }
    }

    // If an app identity was initially resolved before DesktopEntries loaded,
    // rebuild the live model when the identity cache is invalidated so window
    // icons and canonical desktop IDs are corrected without a click.
    property Connections _identityConnections: Connections {
        target: AppIdentityService
        function onRevisionChanged() { svc._scheduleUpdate() }
    }

    function _scheduleUpdate() {
        _updateTimer.restart();
    }

    function _collectToplevels() {
        const result = [];
        for (let i = 0; i < _topRepeater.count; i++) {
            const item = _topRepeater.itemAt(i);
            if (item?.toplevel)
                result.push(item.toplevel);
        }
        return result;
    }

    function _findOldRecord(toplevel) {
        for (let i = 0; i < svc.records.length; i++) {
            if (svc.records[i].toplevel === toplevel)
                return svc.records[i];
        }
        return null;
    }

    function _newWindowId() {
        return "window-" + (svc._nextWindowNumber++);
    }

    function _setRow(row, record) {
        const values = {
            windowId: record.windowId,
            desktopId: record.identity.desktopId,
            appId: record.identity.desktopId,
            rawAppId: record.identity.rawAppId,
            title: record.title,
            icon: record.identity.iconSource,
            isActivated: record.toplevel.activated || false,
            isMinimized: record.toplevel.minimized || false,
            isFullscreen: record.toplevel.fullscreen || false,
        };
        const keys = Object.keys(values);
        for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            if (row[key] !== values[key])
                windowModel.setProperty(row.index, key, values[key]);
        }
    }

    function _rebuild() {
        const tops = _collectToplevels();
        const nextRecords = [];
        const nextById = ({});

        for (let i = 0; i < tops.length; i++) {
            const toplevel = tops[i];
            const old = _findOldRecord(toplevel);
            const identity = AppIdentityService.resolve(toplevel.appId);
            const record = {
                windowId: old?.windowId ?? _newWindowId(),
                toplevel: toplevel,
                identity: identity,
                title: toplevel.title || identity.name || identity.desktopId,
            };
            nextRecords.push(record);
            nextById[record.windowId] = record;
        }

        while (windowModel.count > tops.length)
            windowModel.remove(windowModel.count - 1);

        for (let i = 0; i < nextRecords.length; i++) {
            const record = nextRecords[i];
            if (i >= windowModel.count) {
                windowModel.append({
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
            } else {
                const row = windowModel.get(i);
                const values = {
                    windowId: record.windowId,
                    desktopId: record.identity.desktopId,
                    appId: record.identity.desktopId,
                    rawAppId: record.identity.rawAppId,
                    title: record.title,
                    icon: record.identity.iconSource,
                    isActivated: record.toplevel.activated || false,
                    isMinimized: record.toplevel.minimized || false,
                    isFullscreen: record.toplevel.fullscreen || false,
                };
                const keys = Object.keys(values);
                for (let j = 0; j < keys.length; j++) {
                    const key = keys[j];
                    if (row[key] !== values[key])
                        windowModel.setProperty(i, key, values[key]);
                }
            }
        }

        svc.records = nextRecords;
        svc._recordsById = nextById;
        const active = nextRecords.find(record => record.toplevel.activated);
        svc.activeWindowId = active?.windowId ?? "";
        svc.revision++;
    }

    function windowById(windowId) {
        return _recordsById[String(windowId)] ?? null;
    }

    function windowsForApp(desktopId) {
        const result = [];
        for (let i = 0; i < records.length; i++) {
            if (AppIdentityService.sameApp(records[i].identity, desktopId))
                result.push(records[i]);
        }
        return result;
    }

    function activateWindow(windowId) {
        const record = windowById(windowId);
        if (!record)
            return;
        try { record.toplevel.activate(); } catch (e) {}
    }

    function minimizeWindow(windowId, value) {
        const record = windowById(windowId);
        if (!record)
            return;
        try { record.toplevel.minimized = value === undefined ? true : value; } catch (e) {}
    }

    function closeWindow(windowId) {
        const record = windowById(windowId);
        if (!record)
            return;
        try { record.toplevel.close(); } catch (e) {}
    }

    Component.onCompleted: _scheduleUpdate()
}
