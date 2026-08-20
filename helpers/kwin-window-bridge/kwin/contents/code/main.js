// Quickshell's Plasma/KWin window provider.
// KWin owns the authoritative window list on Plasma Wayland. This script
// publishes snapshots to the local bridge and receives requested operations
// through its short D-Bus polling loop.

const service = "org.quickshell.KWinWindowBridge";
const path = "/WindowBridge";
const iface = "org.quickshell.KWinWindowBridge";

function normalizeId(value) {
    return String(value || "").replace(/[{}]/g, "");
}

function windowId(window) {
    return normalizeId(window.internalId);
}

function propertyValue(window, name, fallback) {
    try {
        const value = window[name];
        return value === undefined || value === null ? fallback : value;
    } catch (error) {
        return fallback;
    }
}

// KWin's frameGeometry is a QRect exposed with x/y/width/height. Read each part
// defensively so an older scripting API cannot break the whole snapshot.
function frameGeometry(window) {
    try {
        const g = window.frameGeometry;
        if (!g)
            return null;
        return {
            x: Number(propertyValue(g, "x", 0)),
            y: Number(propertyValue(g, "y", 0)),
            width: Number(propertyValue(g, "width", 0)),
            height: Number(propertyValue(g, "height", 0))
        };
    } catch (error) {
        return null;
    }
}

// KWin versions expose maximization differently: older as a bool, newer as an
// object of horizontal/vertical flags. Normalise to a single boolean meaning
// "maximised in both axes". Always defensive.
function isMaximized(window) {
    const raw = propertyValue(window, "maximized", false);
    if (raw === null || raw === false || raw === undefined)
        return false;
    if (raw === true)
        return true;
    try {
        if (typeof raw === "object") {
            return !!(raw.horizontal && raw.vertical);
        }
        return false;
    } catch (error) {
        return false;
    }
}

// Preferred output for a window. Some KWin scripting versions do not expose
// `window.output`; fall back to empty so foreign-side collisions can fall back
// to geometry overlap.
function outputName(window) {
    try {
        const output = window.output;
        return output ? String(output.name || "") : "";
    } catch (error) {
        return "";
    }
}

function windowDebug(window) {
    return {
        id: windowId(window),
        pid: Number(propertyValue(window, "pid", 0)),
        resourceClass: String(propertyValue(window, "resourceClass", "")),
        resourceName: String(propertyValue(window, "resourceName", "")),
        desktopFileName: String(propertyValue(window, "desktopFileName", "")),
        caption: String(propertyValue(window, "caption", "")),
        normalWindow: !!propertyValue(window, "normalWindow", false),
        skipTaskbar: !!propertyValue(window, "skipTaskbar", false),
        skipSwitcher: !!propertyValue(window, "skipSwitcher", false),
        hidden: !!propertyValue(window, "hidden", false),
        inputMethod: !!propertyValue(window, "inputMethod", false),
        windowType: String(propertyValue(window, "windowType", "")),
        onAllDesktops: !!propertyValue(window, "onAllDesktops", false)
    };
}

function includeWindow(window) {
    // Workspace changes briefly expose transition/internal windows in
    // workspace.windowList(). They do not belong in a taskbar model.
    const pid = Number(propertyValue(window, "pid", 0));
    const resourceClass = String(propertyValue(window, "resourceClass", ""));
    const resourceName = String(propertyValue(window, "resourceName", ""));
    const caption = String(propertyValue(window, "caption", ""));
    const isKWinInternalWindow = pid <= 0
        && !resourceClass
        && !resourceName
        && !caption;
    return !!window
        && !window.deleted
        && window.normalWindow
        && !window.skipTaskbar
        && !window.skipSwitcher
        && !window.hidden
        && !window.inputMethod
        && !isKWinInternalWindow;
}

// The ids of the virtual desktops a window is on. KWin scripting exposes
// `window.desktops` as a list of VirtualDesktop objects with an id; some
// versions expose bare id strings, so accept both shapes.
function desktopIds(window) {
    try {
        const desktops = window.desktops;
        if (!desktops || !desktops.length)
            return [];
        const ids = [];
        for (let i = 0; i < desktops.length; i++) {
            const item = desktops[i];
            const id = item && typeof item === "object" ? item.id : item;
            if (id)
                ids.push(normalizeId(String(id)));
        }
        return ids;
    } catch (error) {
        return [];
    }
}

// Cached serialized snapshot. KWin can emit the same window state many times
// per second (e.g. a signal that fires repeatedly while nothing changed);
// republishing identical snapshots would make Quickshell rebuild its whole
// window model on every copy. Publish only on actual change.
let lastSnapshotJson = "";

function snapshot() {
    const windows = [];
    const all = workspace.windowList();
    for (let i = 0; i < all.length; i++) {
        const window = all[i];
        if (!includeWindow(window))
            continue;
        windows.push({
            id: windowId(window),
            pid: Number(propertyValue(window, "pid", 0)),
            appId: String(window.desktopFileName || window.resourceClass || window.resourceName || ""),
            title: String(window.caption || ""),
            activated: !!window.active,
            minimized: !!window.minimized,
            fullscreen: !!window.fullScreen,
            // KWin's authoritative _NET_WM_STATE_DEMANDS_ATTENTION state.
            // This is the provider boundary for the Dock's urgent styling.
            urgent: !!propertyValue(window, "demandsAttention", false),
            // Virtual desktops this window lives on (ids). Consumed by the
            // workspace overview to place each window on its desktop.
            desktops: desktopIds(window),
            onAllDesktops: !!propertyValue(window, "onAllDesktops", false),
            // Stable full-reveal geometry consumed by the Dock auto-hide
            // collision judgement. frameGeometry is the compositor's resolved
            // placement, so the user's actual drawn window is what occludes
            // the dock, not an app's requested size.
            geometry: frameGeometry(window),
            outputName: outputName(window),
            maximized: isMaximized(window),
            visible: !!propertyValue(window, "visible", true)
        });
    }
    const json = JSON.stringify({ type: "snapshot", windows: windows });
    if (json === lastSnapshotJson)
        return;
    lastSnapshotJson = json;
    callDBus(service, path, iface, "Publish", json);
}

// KWin emits several property changes while switching virtual desktops. Wait
// for that burst to settle, rather than presenting a transient taskbar icon.
const snapshotTimer = new QTimer();
snapshotTimer.interval = 120;
snapshotTimer.repeat = false;
snapshotTimer.timeout.connect(snapshot);

function scheduleSnapshot() {
    snapshotTimer.start();
}

function publishAction(command, found) {
    callDBus(service, path, iface, "Publish", JSON.stringify({
        type: "action",
        action: String(command.action || ""),
        id: normalizeId(command.id),
        found: found
    }));
}

function findWindow(id) {
    const wanted = normalizeId(id);
    const all = workspace.windowList();
    for (let i = 0; i < all.length; i++) {
        if (windowId(all[i]) === wanted)
            return all[i];
    }
    return null;
}

function findDesktop(id) {
    const wanted = normalizeId(id);
    const desktops = workspace.desktops;
    for (let i = 0; i < desktops.length; i++) {
        if (normalizeId(desktops[i].id) === wanted)
            return desktops[i];
    }
    return null;
}

function publishDesktops() {
    const desktops = workspace.desktops;
    const list = [];
    for (let i = 0; i < desktops.length; i++) {
        const item = desktops[i];
        const id = item && typeof item === "object" ? item.id : item;
        list.push({
            id: normalizeId(String(id || "")),
            name: item && typeof item === "object" ? String(item.name || "") : String(item || "")
        });
    }
    const current = workspace.currentDesktop;
    const currentId = current && typeof current === "object" ? current.id : current;
    callDBus(service, path, iface, "Publish", JSON.stringify({
        type: "desktops",
        desktops: list,
        current: normalizeId(String(currentId || ""))
    }));
}

function handleCommand(serialized) {
    if (!serialized)
        return;

    print("[QuickshellWindowBridge] polled command=" + serialized);

    let command;
    try {
        command = JSON.parse(serialized);
    } catch (error) {
        print("[QuickshellWindowBridge] command JSON error=" + error);
        return;
    }

    // Virtual-desktop commands do not target a window. Handle them before the
    // window lookup below.
    if (command.action === "desktops") {
        publishDesktops();
        return;
    }
    if (command.action === "switch-desktop") {
        const desktop = findDesktop(command.id);
        if (!desktop) {
            print("[QuickshellWindowBridge] switch-desktop missing id=" + command.id);
            publishAction(command, false);
            return;
        }
        workspace.currentDesktop = desktop;
        publishAction(command, true);
        return;
    }
    if (command.action === "move-to-desktop") {
        const window = findWindow(command.windowId);
        const desktop = findDesktop(command.desktopId);
        if (!window || !desktop) {
            print("[QuickshellWindowBridge] move-to-desktop missing window/desktop");
            publishAction(command, false);
            return;
        }
        window.desktops = [desktop];
        if (command.activate)
            workspace.activeWindow = window;
        publishAction(command, true);
        scheduleSnapshot();
        return;
    }

    const window = findWindow(command.id);
    if (!window) {
        print("[QuickshellWindowBridge] command target missing id=" + command.id);
        publishAction(command, false);
        return;
    }

    try {
        if (command.action === "activate") {
            // An app on another virtual desktop can be minimized. Restore it
            // before making it active, otherwise KWin may accept the request but
            // leave it invisible.
            window.minimized = false;
            workspace.activeWindow = window;
        } else if (command.action === "minimize") {
            window.minimized = command.value !== false;
        } else if (command.action === "close") {
            window.closeWindow();
        }
        print("[QuickshellWindowBridge] command executed action=" + command.action
              + " id=" + windowId(window));
    } catch (error) {
        print("[QuickshellWindowBridge] command failed action=" + command.action
              + " id=" + windowId(window) + " error=" + error);
        publishAction(command, false);
        return;
    }

    publishAction(command, true);
    scheduleSnapshot();
}

function watchWindow(window) {
    if (!window)
        return;
    window.captionChanged.connect(scheduleSnapshot);
    window.desktopFileNameChanged.connect(scheduleSnapshot);
    window.activeChanged.connect(scheduleSnapshot);
    window.minimizedChanged.connect(scheduleSnapshot);
    window.fullScreenChanged.connect(scheduleSnapshot);
    // Kept defensive for an older KWin scripting API that lacks this signal.
    try { window.demandsAttentionChanged.connect(scheduleSnapshot); } catch (error) {}
    window.skipTaskbarChanged.connect(scheduleSnapshot);
    // Geometry/placement changes drive the Dock auto-hide collision judgement.
    // Each connect is defensive: one missing signal must not kill the bridge.
    try { window.frameGeometryChanged.connect(scheduleSnapshot); } catch (error) {}
    try { window.outputChanged.connect(scheduleSnapshot); } catch (error) {}
    try { window.maximizedChanged.connect(scheduleSnapshot); } catch (error) {}
    try { window.desktopsChanged.connect(scheduleSnapshot); } catch (error) {}
    window.closed.connect(scheduleSnapshot);
}

const initial = workspace.windowList();
for (let i = 0; i < initial.length; i++)
    watchWindow(initial[i]);

workspace.windowAdded.connect(function(window) {
    watchWindow(window);
    scheduleSnapshot();
});
workspace.windowRemoved.connect(scheduleSnapshot);
workspace.windowActivated.connect(scheduleSnapshot);

// Virtual-desktop lifecycle signals. KWin's QtScript API does not expose every
// signal name in every version, and one missing connect aborts the whole
// script (which would also stop the window snapshots). Connect defensively;
// snapshot() republishes the desktop list as a fallback, so the overview stays
// fresh even when every signal is unavailable.
function connectDesktopSignals() {
    const hooks = {
        desktopAdded: publishDesktops,
        desktopRemoved: publishDesktops,
        desktopNameChanged: publishDesktops,
        currentDesktopChanged: publishDesktops
    };
    for (const name in hooks) {
        try {
            if (workspace[name] && workspace[name].connect)
                workspace[name].connect(hooks[name]);
            else
                print("[QuickshellWindowBridge] desktop signal unavailable: " + name);
        } catch (error) {
            print("[QuickshellWindowBridge] desktop signal connect failed: " + name);
        }
    }
}
connectDesktopSignals();

const commandTimer = new QTimer();
// Commands are UI actions, so 100 ms keeps the Dock responsive while cutting
// idle D-Bus traffic from 40 polls per second to 10.
commandTimer.interval = 100;
commandTimer.repeat = true;
let commandPollInFlight = false;
commandTimer.timeout.connect(function() {
    if (commandPollInFlight)
        return;
    commandPollInFlight = true;
    callDBus(service, path, iface, "TakeCommand", function(command) {
        commandPollInFlight = false;
        if (command)
            print("[QuickshellWindowBridge] polling callback received command");
        handleCommand(command);
    });
});
commandTimer.start();

snapshot();
publishDesktops();
