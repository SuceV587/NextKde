import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join } from "node:path"

const here = dirname(fileURLToPath(import.meta.url))
const editor = readFileSync(join(here, "StatusAreaEditor.qml"), "utf8")
const statusArea = readFileSync(join(here, "BarStatusArea.qml"), "utf8")

// 1. Sizing: editor width must accommodate all status cell cards and margins
assert.match(editor, /implicitWidth:\s*Math\.max\(516,\s*contentRequiredWidth\)/,
    "StatusAreaEditor dynamically sizes to fit all cell cards with a minimum 516px width")

// 2. Viewport adaptation: PopupAdjustment.Slide prevents popup from spilling off-screen
assert.match(editor, /adjustment:\s*PopupAdjustment\.Slide/,
    "StatusAreaEditor uses PopupAdjustment.Slide to avoid viewport clipping")

// 3. Done button: explicit preferred sizing for QtQuick.Layouts
assert.match(editor, /Layout\.preferredWidth:\s*48/,
    "Done button has an explicit Layout.preferredWidth")
assert.match(editor, /Layout\.preferredHeight:\s*26/,
    "Done button has an explicit Layout.preferredHeight")

// 4. Keyboard dismissal: Escape key hides editor
assert.match(editor, /Shortcut\s*\{[\s\S]*?sequence:\s*"Escape"[\s\S]*?editor\.hide\(\)/,
    "StatusAreaEditor declares an Escape shortcut to dismiss")

// 5. Outside-press dismissal: fullscreen transparent catcher
assert.match(editor, /id:\s*dismissalCatcher[\s\S]*?onPressed:\s*editor\.hide\(\)/,
    "StatusAreaEditor declares an outside-press dismissal backdrop")

// 6. Focus loss and context menu coordination
assert.match(editor, /target:\s*WindowService[\s\S]*?onActiveWindowIdChanged[\s\S]*?editor\.hide\(\)/,
    "StatusAreaEditor auto-dismisses on active window focus change")
assert.match(editor, /target:\s*ContextMenuCoordinator[\s\S]*?onActiveMenuChanged[\s\S]*?editor\.hide\(\)/,
    "StatusAreaEditor auto-dismisses when a context menu opens")

// 7. Contextual toggle: right-clicking status area toggles editor visibility
assert.match(statusArea, /statusAreaEditor\.toggleFor\(root\)/,
    "BarStatusArea toggles statusAreaEditor on right click")

console.log("status area editor contract: ok")
