// Quickshell's Plasma/KWin window provider.
// KWin owns the authoritative window list on Plasma Wayland. This script
// publishes snapshots to the local bridge and receives requested operations
// through its short D-Bus polling loop.

// The resident kos-platform process owns the private bridge endpoint. Shell
// clients never call this object directly; they subscribe through the
// platform JSONL socket instead.
const service = "org.kos.Platform";
const path = "/Platform";
const iface = "org.kos.Platform";

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

// KWin 6 exposes maximizeMode as a flag set: vertical=1, horizontal=2. Read it
// first; the older `maximized` shapes remain only as a compatibility fallback.
function isMaximized(window) {
    const mode = Number(propertyValue(window, "maximizeMode", 0));
    if (Number.isFinite(mode) && (mode & 3) === 3)
        return true;
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

function normalizedRect(value) {
    if (!value)
        return null;
    const rect = {
        x: Number(value.x),
        y: Number(value.y),
        width: Number(value.width),
        height: Number(value.height)
    };
    if (!Number.isFinite(rect.x) || !Number.isFinite(rect.y)
            || !Number.isFinite(rect.width) || !Number.isFinite(rect.height)
            || rect.width <= 0 || rect.height <= 0)
        return null;
    return rect;
}

function safeAreaForLayout(layout) {
    const output = normalizedRect(layout && layout.outputRect);
    const dock = normalizedRect(layout && layout.dockRect);
    if (!output || !dock)
        return null;

    const reserved = Math.max(0, Number(layout.barReservedHeight) || 0);
    let left = output.x;
    let top = output.y + Math.min(output.height, reserved);
    let right = output.x + output.width;
    let bottom = output.y + output.height;
    if (layout.dockPosition === "left")
        left = Math.max(left, dock.x + dock.width);
    else if (layout.dockPosition === "right")
        right = Math.min(right, dock.x);
    else
        bottom = Math.min(bottom, dock.y);

    return {
        x: left,
        y: top,
        width: Math.max(1, right - left),
        height: Math.max(1, bottom - top)
    };
}

// Pure placement function kept free of KWin objects so its negative-output,
// oversized-window and minimum-size behaviour can be exercised by Node tests.
function calculateInitialPlacement(windowRect, minimumSize, safeArea) {
    const frame = normalizedRect(windowRect);
    const safe = normalizedRect(safeArea);
    if (!frame || !safe)
        return null;
    const minWidth = Math.max(1, Number(minimumSize && minimumSize.width) || 1);
    const minHeight = Math.max(1, Number(minimumSize && minimumSize.height) || 1);
    const width = Math.max(minWidth, Math.min(frame.width, safe.width));
    const height = Math.max(minHeight, Math.min(frame.height, safe.height));
    const maxX = safe.x + safe.width - width;
    const maxY = safe.y + safe.height - height;
    return {
        x: width > safe.width ? safe.x : Math.max(safe.x, Math.min(frame.x, maxX)),
        y: height > safe.height ? safe.y : Math.max(safe.y, Math.min(frame.y, maxY)),
        width: width,
        height: height
    };
}

let shellLayouts = {};
let placementTimers = [];
let initialPlacementState = {};

function keepPlacementTimer(timer) {
    placementTimers.push(timer);
    timer.timeout.connect(function() {
        const index = placementTimers.indexOf(timer);
        if (index >= 0)
            placementTimers.splice(index, 1);
    });
}

function finishInitialPlacement(window) {
    const id = windowId(window);
    if (id)
        initialPlacementState[id] = "done";
}

function schedulePlacementAttempt(window, attempt, delay) {
    const timer = new QTimer();
    timer.interval = delay;
    timer.singleShot = true;
    timer.timeout.connect(function() { placeInitialWindow(window, attempt); });
    keepPlacementTimer(timer);
    timer.start();
}

function updateLayout(command) {
    const name = String(command.outputName || "");
    const safeArea = safeAreaForLayout(command);
    if (!name || !safeArea)
        return false;
    shellLayouts[name] = {
        outputName: name,
        outputRect: normalizedRect(command.outputRect),
        barReservedHeight: Math.max(0, Number(command.barReservedHeight) || 0),
        dockPosition: String(command.dockPosition || "bottom"),
        dockRect: normalizedRect(command.dockRect),
        workspaceGap: Math.max(0, Number(command.workspaceGap) || 0)
    };
    return true;
}

function layoutForWindow(window) {
    const direct = outputName(window);
    if (direct && shellLayouts[direct])
        return shellLayouts[direct];
    const frame = frameGeometry(window);
    if (!frame)
        return null;
    const centerX = frame.x + frame.width / 2;
    const centerY = frame.y + frame.height / 2;
    for (const name in shellLayouts) {
        const output = shellLayouts[name].outputRect;
        if (centerX >= output.x && centerX < output.x + output.width
                && centerY >= output.y && centerY < output.y + output.height)
            return shellLayouts[name];
    }
    return null;
}

function eligibleForInitialPlacement(window) {
    return !!window && !window.deleted
        && !!propertyValue(window, "normalWindow", false)
        && !propertyValue(window, "specialWindow", false)
        && !propertyValue(window, "dialog", false)
        && !propertyValue(window, "modal", false)
        && !propertyValue(window, "transient", false)
        && !propertyValue(window, "transientFor", null)
        && !propertyValue(window, "fullScreen", false)
        && !isMaximized(window)
        && propertyValue(window, "moveable", true) !== false
        && propertyValue(window, "resizeable", true) !== false;
}

function placeInitialWindow(window, attempt) {
    const id = windowId(window);
    if (!id || initialPlacementState[id] === "done")
        return;
    if (!eligibleForInitialPlacement(window)) {
        finishInitialPlacement(window);
        return;
    }
    const layout = layoutForWindow(window);
    if (!layout) {
        if (attempt < 3)
            schedulePlacementAttempt(window, attempt + 1, 40);
        else
            finishInitialPlacement(window);
        return;
    }
    const frame = frameGeometry(window);
    if (!frame || frame.width <= 1 || frame.height <= 1) {
        if (attempt < 3)
            schedulePlacementAttempt(window, attempt + 1, 40);
        else
            finishInitialPlacement(window);
        return;
    }
    const minimum = propertyValue(window, "minSize", { width: 1, height: 1 });
    const target = calculateInitialPlacement(frame, minimum, safeAreaForLayout(layout));
    if (!target) {
        finishInitialPlacement(window);
        return;
    }
    if (target.x === frame.x && target.y === frame.y
            && target.width === frame.width && target.height === frame.height) {
        finishInitialPlacement(window);
        return;
    }
    // Mark the request complete before assigning geometry. KWin emits
    // synchronous geometry signals during this write; no later event may
    // reinterpret a maximize or user drag as another initial placement.
    finishInitialPlacement(window);
    try {
        window.frameGeometry = target;
        print("[QuickshellWindowBridge] placed new window id=" + windowId(window)
              + " output=" + layout.outputName);
    } catch (error) {
        print("[QuickshellWindowBridge] initial placement failed id=" + windowId(window)
              + " error=" + error);
    }
}

function scheduleInitialPlacement(window) {
    const id = windowId(window);
    if (!id || initialPlacementState[id])
        return;
    initialPlacementState[id] = "pending";
    schedulePlacementAttempt(window, 0, 0);
}

// Runtime-dependent bridge helpers start here. Tests evaluate the pure layout
// and placement helpers above this marker without a live KWin workspace.

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

// KWin emits several metadata changes while switching virtual desktops. Wait
// for that burst to settle, rather than presenting a transient taskbar icon.
// Geometry is deliberately handled by the separate throttled timer below:
// debouncing frameGeometryChanged here made smart-hide wait until a window had
// stopped moving before it could notice that the Dock boundary was crossed.
const snapshotTimer = new QTimer();
snapshotTimer.interval = 120;
snapshotTimer.singleShot = true;
snapshotTimer.timeout.connect(snapshot);

function scheduleSnapshot() {
    snapshotTimer.start();
}

// Publish at most once per compositor frame while a window is moving. This is
// a leading/trailing-friendly throttle, not a debounce: repeated geometry
// signals do not restart the timer, and snapshot() always reads the latest
// frameGeometry when the timer fires.
const geometrySnapshotTimer = new QTimer();
geometrySnapshotTimer.interval = 24;
geometrySnapshotTimer.singleShot = true;
let geometrySnapshotPending = false;
geometrySnapshotTimer.timeout.connect(function() {
    geometrySnapshotPending = false;
    snapshot();
});

function scheduleGeometrySnapshot() {
    if (geometrySnapshotPending)
        return;
    geometrySnapshotPending = true;
    geometrySnapshotTimer.start();
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
    if (command.action === "update-layout") {
        publishAction(command, updateLayout(command));
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
    const watchedId = windowId(window);
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
    try { window.frameGeometryChanged.connect(scheduleGeometrySnapshot); } catch (error) {}
    try { window.outputChanged.connect(scheduleGeometrySnapshot); } catch (error) {}
    try { window.maximizedChanged.connect(scheduleSnapshot); } catch (error) {}
    try { window.maximizeModeChanged.connect(scheduleSnapshot); } catch (error) {}
    try { window.desktopsChanged.connect(scheduleSnapshot); } catch (error) {}
    window.closed.connect(function() {
        if (watchedId)
            delete initialPlacementState[watchedId];
        scheduleSnapshot();
    });
}

// Runtime wiring.
const initial = workspace.windowList();
for (let i = 0; i < initial.length; i++)
    watchWindow(initial[i]);

workspace.windowAdded.connect(function(window) {
    watchWindow(window);
    scheduleInitialPlacement(window);
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
commandTimer.singleShot = false;
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
