// Test harness for Bar auto-hide behavior, contract bindings, and state machine logic
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
    visibleDockRect, windowEligible, hasConflict, shouldBeVisible, policyWantsHidden
} from "../dock/DockAutoHideMath.mjs";

console.log("Testing Bar auto-hide logic...");

// 1. Verify BarWindow.qml contract bindings
const barWindowSrc = readFileSync(new URL("BarWindow.qml", import.meta.url), "utf8");
assert.doesNotMatch(barWindowSrc, /controlCenterLoaded/,
    "BarWindow popupOpen must NOT bind to controlCenterLoaded (which stays true in memory)");
assert.match(barWindowSrc, /controlCenterOpening/,
    "BarWindow popupOpen must bind to transient controlCenterOpening");
assert.match(barWindowSrc, /anyPanelOpen/,
    "BarWindow popupOpen must bind to anyPanelOpen");
assert.match(barWindowSrc, /topTriggerArea[\s\S]*?\?\s*2\s*:\s*0/,
    "topTriggerArea height must be 2px when hidden, 0px when revealed");

// 2. Verify BarStatusArea.qml lifecycle bindings
const barStatusSrc = readFileSync(new URL("BarStatusArea.qml", import.meta.url), "utf8");
assert.match(barStatusSrc, /property bool controlCenterOpening:\s*false/,
    "BarStatusArea declares controlCenterOpening property");
assert.match(barStatusSrc, /onControlCenterOpenChanged:\s*\{[\s\S]*?controlCenterUnloadTimer\.restart\(\)/,
    "BarStatusArea auto-restarts unload timer whenever controlCenter closes");

// 3. Verify BarAutoHideController.qml input plumbing & target screen
const barControllerSrc = readFileSync(new URL("BarAutoHideController.qml", import.meta.url), "utf8");
assert.match(barControllerSrc, /on_HandleHoveredChanged:\s*ctl\._scheduleEvaluate\(\)/,
    "BarAutoHideController re-evaluates when _handleHovered changes");
assert.match(barControllerSrc, /onLauncherOpenChanged:\s*ctl\._scheduleEvaluate\(\)/,
    "BarAutoHideController re-evaluates when launcherOpen changes");
assert.match(barControllerSrc, /name:\s*s\.name\s*\|\|\s*""/,
    "BarAutoHideController includes screen name in _targetRect for multi-monitor matching");

// 4. Test math & state logic with simulated windows
const screen = { x: 0, y: 0, width: 2560, height: 1440, name: "DP-2" };
const barHeight = 35;
const edgeMargin = 15;
const barRect = visibleDockRect(screen, "top", screen.width - edgeMargin * 2, barHeight, edgeMargin);

// Maximized window on screen
const maxWindow = {
    geometry: { x: 0, y: 0, width: 2560, height: 1440 },
    screenName: "DP-2",
    isMinimized: false,
    isFullscreen: false,
    isMaximized: true,
    isVisible: true,
    onAllDesktops: true,
    desktopIds: []
};

// Check conflict for maximized window
assert.ok(windowEligible(maxWindow, screen, "desktop-1"), "maximized window is eligible");
const conflict = hasConflict([maxWindow], screen, barRect, barRect, false, "desktop-1", true);
assert.equal(conflict, true, "maximized window must conflict with Bar");

// Policy wants hidden on conflict
assert.equal(policyWantsHidden("smart", conflict), true, "smart mode policy wants hidden when conflict exists");
assert.equal(policyWantsHidden("persistent", conflict), true, "persistent mode policy always wants hidden");

// Normal state (no hover, no popup): Bar must NOT be visible
let pointerInsideBar = false;
let handleHovered = false;
let popupOpen = false;
let launcherOpen = false;
let temporaryHold = false;
let hasInhibitor = pointerInsideBar || handleHovered || popupOpen || launcherOpen || temporaryHold;

assert.equal(hasInhibitor, false, "initially no inhibitor");
assert.equal(shouldBeVisible("smart", conflict, hasInhibitor), false,
    "Bar must hide in smart mode when window conflicts and no inhibitor active");
assert.equal(shouldBeVisible("persistent", conflict, hasInhibitor), false,
    "Bar must hide in persistent mode when no inhibitor active");

// Simulated scenario: User hovers top 2px trigger
handleHovered = true;
hasInhibitor = pointerInsideBar || handleHovered || popupOpen || launcherOpen || temporaryHold;
assert.equal(shouldBeVisible("smart", conflict, hasInhibitor), true, "hovering top trigger reveals Bar");

// Cursor moves onto Bar
pointerInsideBar = true;
handleHovered = false;
hasInhibitor = pointerInsideBar || handleHovered || popupOpen || launcherOpen || temporaryHold;
assert.equal(shouldBeVisible("smart", conflict, hasInhibitor), true, "cursor inside Bar keeps it revealed");

// User clicks Control Center: opening transient
let controlCenterLoaded = true;
let controlCenterOpening = true;
let controlCenterOpen = false;
popupOpen = controlCenterOpen || controlCenterOpening;
hasInhibitor = pointerInsideBar || handleHovered || popupOpen || launcherOpen || temporaryHold;
assert.equal(hasInhibitor, true, "control center opening holds Bar");

// Control Center fully open
controlCenterOpening = false;
controlCenterOpen = true;
popupOpen = controlCenterOpen || controlCenterOpening;
hasInhibitor = pointerInsideBar || handleHovered || popupOpen || launcherOpen || temporaryHold;
assert.equal(hasInhibitor, true, "control center open holds Bar");

// User clicks outside Control Center to close it (backdrop click)
controlCenterOpen = false;
controlCenterOpening = false;
// Note: controlCenterLoaded is STILL TRUE in memory (cached), but popupOpen MUST be false!
popupOpen = controlCenterOpen || controlCenterOpening;
assert.equal(popupOpen, false, "popupOpen is FALSE even though controlCenterLoaded is true");

// Cursor moves away from Bar
pointerInsideBar = false;
handleHovered = false;
hasInhibitor = pointerInsideBar || handleHovered || popupOpen || launcherOpen || temporaryHold;
assert.equal(hasInhibitor, false, "all inhibitors cleared after control center closed and cursor left");
assert.equal(shouldBeVisible("smart", conflict, hasInhibitor), false,
    "Bar must auto-hide now that control center is closed");

// Multi-monitor matching: window matched by screenName when screen geometry is offset
const screen2 = { x: 2560, y: 0, width: 1920, height: 1080, name: "HDMI-1" };
const windowOnScreen2 = {
    geometry: { x: 2600, y: 50, width: 800, height: 600 },
    screenName: "HDMI-1",
    isMinimized: false,
    isVisible: true,
    onAllDesktops: true
};
assert.ok(windowEligible(windowOnScreen2, screen2, ""), "multi-monitor window matched by name and geometry");

console.log("Bar auto-hide tests: ALL PASS");
