import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"

const here = dirname(fileURLToPath(import.meta.url))
const editor = readFileSync(join(here, "StatusAreaEditor.qml"), "utf8")
const statusArea = readFileSync(join(here, "BarStatusArea.qml"), "utf8")
const barWindow = readFileSync(join(here, "BarWindow.qml"), "utf8")

// 1. The Bar holds its reveal while the editor is open ------------------------
// Without this the editor's anchor surface slides away underneath it and leaves
// the window mapped at a stale screen position.
assert.match(statusArea,
    /readonly property bool statusEditorOpen:\s*statusAreaEditor\.requestedOpen/,
    "BarStatusArea publishes the editor's open state as its own property")
assert.match(barWindow,
    /popupOpen:[\s\S]*?statusArea\?\.statusEditorOpen/,
    "BarWindow feeds that state into the Bar's auto-hide inhibitor")

// The inhibitor must stay per surface: the editor lives inside one BarWindow's
// BarStatusArea, and nothing global may gate another screen's Bar.
assert.doesNotMatch(barWindow,
    /popupOpen:[\s\S]{0,400}?ControlCenterService\.anyPanelOpen/,
    "the inhibitor is not read from a shared service singleton")

// 2. The editor must not join `anyPanelOpen` ---------------------------------
// `anyPanelOpen` also reports to ControlCenterService.notePanelOpen, which
// raises the audio/network polls to 3s and 1.8s; the editor shows no live data.
const anyPanelOpen = statusArea.match(
    /readonly property bool anyPanelOpen:([\s\S]*?)\n\n/)?.[1] ?? ""
assert.ok(anyPanelOpen.length > 0, "BarStatusArea still declares anyPanelOpen")
assert.doesNotMatch(anyPanelOpen, /statusAreaEditor/,
    "the editor stays out of anyPanelOpen so it cannot start the fast polls")
assert.match(statusArea,
    /onAnyPanelOpenChanged[\s\S]*?ControlCenterService\.notePanelOpen\(anyPanelOpen\)/,
    "anyPanelOpen keeps reporting only the data-showing panels")

// 3. The window is created only once the Bar rests ---------------------------
assert.match(editor,
    /readonly property bool anchorSettled:\s*barRevealProgress > 0\.999/,
    "the editor tracks whether the Bar has stopped moving")
assert.match(editor,
    /function openFor\(item\)[\s\S]*?if \(anchorSettled\)\s*\n\s*show\(\)[\s\S]*?pendingOpen = true/,
    "opening defers while the Bar is still moving")
assert.match(editor,
    /onAnchorSettledChanged:[\s\S]*?editor\.pendingOpen = false[\s\S]*?editor\.show\(\)/,
    "the deferred request runs once the Bar settles")
assert.match(editor,
    /Bar reveal never settled; opening anyway/,
    "a swallowed deferred request has a bounded fallback")
assert.match(editor,
    /onTriggered:[\s\S]*?editor\.barRevealProgress <= 0\.001[\s\S]*?editor\.pendingOpen = false/,
    "the fallback drops a request whose Bar never came back")
assert.match(statusArea,
    /StatusAreaEditor\s*\{[\s\S]*?barRevealProgress:\s*root\.barRevealProgress[\s\S]*?targetScreen:\s*root\.targetScreen/,
    "the editor receives the Bar's reveal progress and its screen")
assert.match(barWindow,
    /BarStatusArea\s*\{[\s\S]*?targetScreen:\s*root\.screen/,
    "the Bar binds the status cluster to its own screen")

// 4. No orphan window when the Bar goes away for another reason --------------
assert.match(editor,
    /onBarRevealProgressChanged:[\s\S]*?editor\.barRevealProgress > 0\.001[\s\S]*?editor\.close\(\)/,
    "an editor never outlives a Bar that stopped being revealed")
assert.match(editor,
    /target:\s*ScreenLifecycle[\s\S]*?onOutputAvailableChanged[\s\S]*?!ScreenLifecycle\.outputAvailable[\s\S]*?editor\.close\(\)/,
    "losing the output closes the editor")
assert.match(editor,
    /onClosed:[\s\S]*?if \(editor\.requestedOpen\)\s*\n\s*editor\.close\(\)/,
    "a display-server close folds the open state back")

// 5. Every dismissal path exists and clears the deferred request -------------
assert.match(editor, /function close\(\)[\s\S]*?pendingOpen = false[\s\S]*?hide\(\)/,
    "close() drops the deferred request and hides")
assert.doesNotMatch(editor, /editor\.hide\(\)/,
    "no path hides the editor without clearing the deferred request")
assert.match(editor, /TapHandler \{ onTapped: editor\.close\(\) \}/,
    "the Done button closes the editor")
assert.match(editor, /Shortcut\s*\{[\s\S]*?sequence:\s*"Escape"[\s\S]*?editor\.close\(\)/,
    "Escape closes the editor")
assert.match(editor, /id:\s*dismissalCatcher/,
    "the editor declares an outside-press dismissal catcher")
assert.match(editor, /screen:\s*editor\.targetScreen/,
    "the dismissal catcher binds to the Bar's own screen")
assert.match(editor, /onPressed:\s*editor\.close\(\)/,
    "the dismissal catcher closes the editor on outside click")
assert.match(editor, /WlrLayershell\.layer:\s*WlrLayer\.Top/,
    "the dismissal catcher is placed on WlrLayer.Top")
assert.match(editor, /WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None/,
    "the dismissal catcher does not steal keyboard focus")

// 6. One Bar popup at a time -------------------------------------------------
assert.match(statusArea,
    /function openStatusEditor\(item\)[\s\S]*?networkPanel\.close\(\)[\s\S]*?notificationPanel\.close\(\)[\s\S]*?statusAreaEditor\.openFor\(item\)/,
    "opening the editor closes the other status panels first")
assert.match(statusArea,
    /onTapped:\s*root\.openStatusEditor\(root\)/,
    "the status cluster's right-click opens the editor through that one path")
assert.ok((statusArea.match(/closeStatusEditor\(\)/g) || []).length >= 4,
    "every other status panel closes the editor when it takes over")

console.log("status area editor panel contract: ok")
