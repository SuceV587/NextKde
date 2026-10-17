import assert from "node:assert/strict"
import { readFileSync, readdirSync } from "node:fs"
import { fileURLToPath } from "node:url"
import { dirname, join, resolve } from "node:path"

const here = dirname(fileURLToPath(import.meta.url))
const repo = resolve(here, "../../../..")
const read = path => readFileSync(join(repo, path), "utf8")

const service = read("shell/desktop/modules/common/AppearanceConfigService.qml")
const desktop = read("shell/desktop/DesktopEnvironment.qml")
const glassText = read("shell/desktop/modules/common/GlassText.qml")
const bridgeHeader = read("apps/settings/src/SettingsBridge.h")
const bridge = read("apps/settings/src/SettingsBridgeAppearance.cpp")
const page = read("apps/settings/pages/DisplaySettingsPage.qml")
const catalog = read("shared/qml/i18n/ZhCatalog.mjs")

// ── 1. One appearance flag owns the choice ─────────────────────────────────
// Qt's per-channel (LCD subpixel) glyph coverage is what tints every letter
// edge; on a translucent surface each channel blends with a different backdrop,
// which is the coloured fringing the shell used to show over the glass.
// Native, grayscale rasterisation removes it, at the cost of Qt's subpixel
// positioning and gamma-corrected blending -- so it is a choice, and off is
// what every installation rendered with before this flag existed.
assert.match(service, /property bool nativeTextRendering: false/,
    "the service declares the flag with the previous behaviour as its default")
assert.match(service,
    /function updateNativeTextRendering\(rawValue\) \{\s*const value = _toBool\(rawValue\)[\s\S]*?nativeTextRendering = value\s*saveTimer\.restart\(\)/,
    "the setter coerces to bool and persists")
assert.match(service, /nativeTextRendering: service\.nativeTextRendering,/,
    "the flag is part of the persisted payload")
assert.match(service,
    /const hasNativeTextRendering =\s*\n?\s*typeof nativeTextRendering === "boolean"/,
    "a file without the key is detected rather than assumed")
assert.match(service, /if \(hasNativeTextRendering\)\s*\n\s*service\.nativeTextRendering = nativeTextRendering/,
    "a missing key keeps the old rendering instead of rewriting the file")

// ── 2. The Settings app can read and write it ─────────────────────────────
assert.match(desktop,
    /IpcHandler \{\s*target: "appearance-settings"[\s\S]*?nativeTextRendering:\s*\n?\s*AppearanceConfigService\.nativeTextRendering/,
    "the shell snapshot carries the flag to the settings bridge")
assert.match(desktop,
    /function updateNativeTextRendering\(value: bool\): string \{\s*AppearanceConfigService\.updateNativeTextRendering\(value\)\s*return snapshot\(\)/,
    "the shell exposes the same write path as its other appearance flags")
assert.match(bridgeHeader, /Q_INVOKABLE void updateNativeTextRendering\(bool enabled\);/,
    "the bridge declares the invokable")
assert.match(bridge,
    /void SettingsBridge::updateNativeTextRendering\(bool enabled\)\s*\{\s*callAppearance\(\{ QStringLiteral\("updateNativeTextRendering"\)/,
    "the bridge forwards the write to the shell")
assert.match(bridge,
    /\{ QStringLiteral\("nativeTextRendering"\),\s*\n\s*object\.value\(QStringLiteral\("nativeTextRendering"\)\)\.toBool\(false\) \}/,
    "the bridge's state whitelist carries the flag with an off fallback")
assert.match(page, /property bool nativeTextRendering: false/,
    "the page mirrors the flag")
assert.match(page, /if \(state\.nativeTextRendering !== undefined\)\s*\n\s*nativeTextRendering = !!state\.nativeTextRendering/,
    "the page reads it from every snapshot")
assert.match(page,
    /function saveNativeTextRendering\(checked\)[\s\S]*?bridge\.updateNativeTextRendering\(checked\)/,
    "the page writes it through the bridge")
assert.match(page,
    /LiquidControls\.LiquidGlassSwitch \{[\s\S]{0,400}?checked: displayPage\.nativeTextRendering[\s\S]{0,300}?onToggled:[\s\S]{0,120}?saveNativeTextRendering\(checked\)/,
    "the switch is wired to that write path")
// The card must live in the appearance section every shell style shows. Riding
// on showGlassMaterial put it inside the Material-only instance, which hid the
// switch for every other style -- a user on the macOS style could not reach it.
assert.match(page, /property bool showTextRendering: false/,
    "the page has its own flag for the text-rendering section")
assert.match(page, /visible: displayPage\.showTextRendering\s*\n\s*text: I18n\.tr\("Text rendering"\)/,
    "the section header follows that flag")
const themePage = read("apps/settings/pages/ThemeSettingsPage.qml")
const materialInstance = themePage.match(/id: themeMaterialSettings[\s\S]*?(?=id: globalAppearanceSettings)/)?.[0] ?? ""
const globalInstance = themePage.match(/id: globalAppearanceSettings[\s\S]*?(?=WidgetAppearanceSection \{)/)?.[0] ?? ""
assert.ok(materialInstance.length > 0 && globalInstance.length > 0,
    "both appearance instances are present to be told apart")
assert.match(globalInstance, /showTextRendering: true/,
    "the always-visible instance shows the text-rendering section")
assert.doesNotMatch(materialInstance, /showTextRendering: true/,
    "the Material-only instance does not show it a second time")
for (const text of ["Text rendering", "Grayscale text rendering",
                    "Letters no longer carry coloured edges over the glass",
                    "Letters can carry coloured edges over the glass"])
    assert.ok(catalog.includes(`"${text}":`),
        `the catalog carries "${text}"`)

// ── 3. Every shell Text honours the flag ──────────────────────────────────
// The switch has to be honest: a Text that ignores it would keep the fringing
// and make the setting look broken. GlassText applies it once for the glass
// surfaces; the rest are asserted mechanically below.
assert.match(glassText,
    /renderType: AppearanceConfigService\.nativeTextRendering\s*\n?\s*\? Text\.NativeRendering : Text\.QtRendering/,
    "GlassText renders through the flag, so every glass surface follows it")

function* qmlFiles(directory) {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
        const path = join(directory, entry.name)
        if (entry.isDirectory()) yield* qmlFiles(path)
        else if (entry.name.endsWith(".qml")) yield path
    }
}

const textStart = /^(\s*)Text \{$/
const inlineTextStart = /^(\s*)component [A-Za-z0-9_]+: Text \{$/
const offenders = []
let checked = 0
for (const path of qmlFiles(join(repo, "shell/desktop"))) {
    const lines = readFileSync(path, "utf8").split("\n")
    for (let i = 0; i < lines.length; ++i) {
        const start = textStart.test(lines[i]) || inlineTextStart.test(lines[i])
        if (!start)
            continue
        checked++
        const block = lines.slice(i, i + 22).join("\n")
        if (!block.includes("renderType:"))
            offenders.push(`${path.slice(repo.length + 1)}:${i + 1}`)
    }
}
assert.ok(checked > 100, `the sweep covers the shell's Text items (found ${checked})`)
assert.deepEqual(offenders, [],
    "every shell Text chooses its render type (offenders: " + offenders.join(", ") + ")")

console.log(`native text rendering contract: ok (${checked} Text items checked)`)
