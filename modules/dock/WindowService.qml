pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
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

    // KWin does not implement zwlr-foreign-toplevel-management-v1. Its local
    // bridge receives snapshots from our KWin Script over D-Bus and is used
    // only when the standard Wayland provider has no windows.
    property var _kwinWindows: []
    property bool _kwinReceivedInitialSnapshot: false
    property var _pendingKwinActivation: null
    property int _kwinBridgeOutputLength: 0
    // StdioCollector can deliver one newline-delimited bridge event in more
    // than one chunk. Keep the incomplete tail until its terminating newline
    // arrives instead of attempting to parse partial JSON.
    property string _kwinBridgePendingLine: ""
    property bool _kwinScriptStarted: false
    readonly property string _kwinBridgePath:
        Quickshell.shellDir + "/tools/kwin-window-bridge/build/quickshell-kwin-window-bridge"
    readonly property string _kwinScriptPath:
        Quickshell.shellDir + "/tools/kwin-window-bridge/kwin/contents/code/main.js"

    property Process _kwinBridge: Process {
        command: [svc._kwinBridgePath]
        running: true
        // Persistent low-latency command channel to the local bridge. The
        // bridge forwards KWin snapshots and receives commands on stdin.
        stdinEnabled: true
        stdout: StdioCollector {
            waitForEnd: false
            onTextChanged: svc._consumeKwinBridgeOutput(text)
        }
        stderr: StdioCollector { waitForEnd: false }
        onExited: function(code) {
            if (code !== 0)
                console.log("[WindowService] KWin bridge unavailable code=" + code)
        }
    }

    property Component _commandProcessFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

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

    // Merge pointer double-clicks or quick target changes before spawning a
    // qdbus6 process. The bridge also coalesces requests, but doing it here
    // avoids creating needless processes in the first place.
    property Timer _kwinActivationTimer: Timer {
        interval: 24
        repeat: false
        onTriggered: {
            const command = svc._pendingKwinActivation;
            svc._pendingKwinActivation = null;
            if (command)
                svc._sendKwinCommand(command);
        }
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

    function _findOldRecord(toplevel, provider, handleId) {
        for (let i = 0; i < svc.records.length; i++) {
            const record = svc.records[i];
            if (provider === "kwin") {
                if (record.provider === "kwin" && record.handleId === handleId)
                    return record;
            } else if (record.provider === "foreign" && record.toplevel === toplevel) {
                return svc.records[i];
            }
        }
        return null;
    }

    function _newWindowId() {
        return "window-" + (svc._nextWindowNumber++);
    }

    function _recordsEqual(left, right) {
        return left.windowId === right.windowId
            && left.provider === right.provider
            && left.handleId === right.handleId
            && left.title === right.title
            && left.identity.desktopId === right.identity.desktopId
            && left.identity.rawAppId === right.identity.rawAppId
            && left.iconSource === right.iconSource
            && !!left.toplevel.activated === !!right.toplevel.activated
            && !!left.toplevel.minimized === !!right.toplevel.minimized
            && !!left.toplevel.fullscreen === !!right.toplevel.fullscreen;
    }

    function _setRow(row, record) {
        const values = {
            windowId: record.windowId,
            desktopId: record.identity.desktopId,
            appId: record.identity.desktopId,
            rawAppId: record.identity.rawAppId,
            title: record.title,
            icon: record.iconSource,
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
        const foreignTops = _collectToplevels();
        const useKwin = foreignTops.length === 0 && svc._kwinWindows.length > 0;
        const tops = useKwin ? svc._kwinWindows : foreignTops;
        const nextRecords = [];
        const nextById = ({});

        for (let i = 0; i < tops.length; i++) {
            const source = tops[i];
            const provider = useKwin ? "kwin" : "foreign";
            const handleId = useKwin ? String(source.id) : "";
            const toplevel = useKwin ? {
                activated: !!source.activated,
                minimized: !!source.minimized,
                fullscreen: !!source.fullscreen,
                appId: source.appId || "",
                title: source.title || ""
            } : source;
            const old = _findOldRecord(toplevel, provider, handleId);
            const identity = AppIdentityService.resolve(toplevel.appId);
            // For KWin, the bridge resolves the desktop icon name through the
            // active KDE icon theme. Only a user's explicit Dock override may
            // take precedence over that authoritative themed result.
            const iconSource = useKwin && source.iconPath && !identity.hasIconOverride
                ? "file://" + source.iconPath : identity.iconSource;
            const record = {
                windowId: old?.windowId ?? _newWindowId(),
                toplevel: toplevel,
                provider: provider,
                handleId: handleId,
                identity: identity,
                iconSource: iconSource,
                title: toplevel.title || identity.name || identity.desktopId,
            };
            nextRecords.push(record);
            nextById[record.windowId] = record;
        }

        let changed = svc.records.length !== nextRecords.length;
        if (!changed) {
            for (let i = 0; i < nextRecords.length; i++) {
                if (!svc._recordsEqual(svc.records[i], nextRecords[i])) {
                    changed = true;
                    break;
                }
            }
        }
        if (!changed)
            return;

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
                    icon: record.iconSource,
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
                    icon: record.iconSource,
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
        if (!record) {
            console.warn("[WindowService] activate missing windowId=" + windowId);
            return;
        }
        console.log("[WindowService] activate windowId=" + windowId
                    + " provider=" + record.provider
                    + " handleId=" + record.handleId);
        if (record.provider === "kwin") {
            _enqueueKwinCommand({ action: "activate", id: record.handleId });
            return;
        }
        try { record.toplevel.activate(); } catch (e) {}
    }

    function minimizeWindow(windowId, value) {
        const record = windowById(windowId);
        if (!record)
            return;
        if (record.provider === "kwin") {
            _enqueueKwinCommand({
                action: "minimize",
                id: record.handleId,
                value: value === undefined ? true : value
            });
            return;
        }
        try { record.toplevel.minimized = value === undefined ? true : value; } catch (e) {}
    }

    function closeWindow(windowId) {
        const record = windowById(windowId);
        if (!record)
            return;
        if (record.provider === "kwin") {
            _enqueueKwinCommand({ action: "close", id: record.handleId });
            return;
        }
        try { record.toplevel.close(); } catch (e) {}
    }

    function _consumeKwinBridgeOutput(output) {
        const data = String(output ?? "");
        const fresh = data.slice(svc._kwinBridgeOutputLength);
        svc._kwinBridgeOutputLength = data.length;
        const lines = (svc._kwinBridgePendingLine + fresh).split("\n");
        svc._kwinBridgePendingLine = lines.pop();
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line === "READY") {
                svc._startKwinScript();
            } else if (line.startsWith("EVENT ")) {
                try {
                    const event = JSON.parse(line.slice(6));
                    if (event.type === "snapshot" && Array.isArray(event.windows)) {
                        // Keep activation direct. Virtual-desktop transient
                        // filtering is handled separately; delaying this
                        // authoritative list also delayed focus changes.
                        svc._kwinWindows = event.windows;
                        if (!svc._kwinReceivedInitialSnapshot) {
                            svc._kwinReceivedInitialSnapshot = true;
                        }
                        svc._scheduleUpdate();
                    } else if (event.type === "action") {
                        console.log("[WindowService] KWin action=" + event.action
                                    + " id=" + event.id
                                    + " found=" + event.found);
                    }
                } catch (e) {
                    console.warn("[WindowService] invalid KWin event: " + e);
                }
            }
        }
    }

    function _startKwinScript() {
        if (svc._kwinScriptStarted)
            return;
        svc._kwinScriptStarted = true;
        const unload = _commandProcessFactory.createObject(svc, {
            command: ["qdbus6", "org.kde.KWin", "/Scripting",
                      "org.kde.kwin.Scripting.unloadScript", "quickshell-window-bridge"]
        });
        unload.exited.connect(function() {
            unload.destroy();
            svc._loadKwinScript();
        });
        unload.running = true;
    }

    function _loadKwinScript() {
        const proc = _commandProcessFactory.createObject(svc, {
            command: ["qdbus6", "org.kde.KWin", "/Scripting",
                      "org.kde.kwin.Scripting.loadScript", svc._kwinScriptPath,
                      "quickshell-window-bridge"]
        });
        proc.exited.connect(function(code) {
            if (code === 0) {
                const starter = _commandProcessFactory.createObject(svc, {
                    command: ["qdbus6", "org.kde.KWin", "/Scripting",
                              "org.kde.kwin.Scripting.start"]
                });
                starter.exited.connect(function() { starter.destroy(); });
                starter.running = true;
            } else {
                console.log("[WindowService] KWin script not started: "
                            + (proc.stderr?.text ?? ""));
            }
            proc.destroy();
        });
        proc.running = true;
    }

    function _enqueueKwinCommand(command) {
        if (command.action === "activate") {
            svc._pendingKwinActivation = command;
            svc._kwinActivationTimer.restart();
            return;
        }
        svc._sendKwinCommand(command);
    }

    function _sendKwinCommand(command) {
        console.log("[WindowService] KWin enqueue action=" + command.action
                    + " id=" + command.id);
        if (!svc._kwinBridge.running) {
            console.warn("[WindowService] KWin bridge is not running");
            return;
        }
        svc._kwinBridge.write(JSON.stringify(command) + "\n");
    }

    Component.onCompleted: _scheduleUpdate()
}
