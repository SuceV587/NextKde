pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Global appearance settings shared by shell surfaces. Keep these values out
// of DockConfigService: glass material is a shell-wide concern, while pinned
// items, Dock geometry and visibility remain Dock-owned state.
QtObject {
    id: service

    readonly property string configDir: Quickshell.stateDir + "/appearance"
    readonly property string configPath: configDir + "/config.json"

    // Defaults preserve the material that existed before these controls:
    // LiquidGlassControl used a 10px blur (10 / 24 ~= 0.42), while large
    // surfaces rendered their liquid layers at full strength.
    property real blurStrength: 0.42
    property real liquidStrength: 1.0
    // "macos" matches the shell geometry that predates selectable styles,
    // so upgrading an existing installation does not unexpectedly reshape it.
    property string shellStyle: "macos"
    property bool barIntegratedWithDock: false
    property bool ready: false

    function isValidShellStyle(value) {
        return value === "windows12" || value === "macos"
            || value === "material"
    }

    function _normalized(value) {
        const number = Number(value)
        return Number.isFinite(number)
            ? Math.max(0.0, Math.min(1.0, number)) : NaN
    }

    function updateBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(blurStrength - value) <= 0.001)
            return false
        blurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(liquidStrength - value) <= 0.001)
            return false
        liquidStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateShellStyle(rawStyle) {
        const style = String(rawStyle)
        if (!isValidShellStyle(style) || shellStyle === style)
            return false
        shellStyle = style
        saveTimer.restart()
        return true
    }

    function updateBarIntegratedWithDock(rawValue) {
        const value = rawValue === true || rawValue === 1
            || String(rawValue).toLowerCase() === "true"
        if (barIntegratedWithDock === value)
            return false
        barIntegratedWithDock = value
        saveTimer.restart()
        return true
    }

    function resetStrengths() {
        const blurChanged = Math.abs(blurStrength - 0.42) > 0.001
        const liquidChanged = Math.abs(liquidStrength - 1.0) > 0.001
        blurStrength = 0.42
        liquidStrength = 1.0
        if (blurChanged || liquidChanged) {
            saveTimer.restart()
            effectSyncTimer.restart()
        }
        return blurChanged || liquidChanged
    }

    property Timer saveTimer: Timer {
        interval: 350
        repeat: false
        onTriggered: service._save()
    }

    // The compositor plugin owns the real backdrop blur/refraction for Dock
    // and other BackgroundEffect regions. Quickshell can publish the region,
    // but Wayland exposes no per-surface strength field, so synchronize the
    // two user-facing values with the custom Glass effect's own settings.
    // This deliberately does not touch KDE's stock [Effect-blur] group.
    property Timer effectSyncTimer: Timer {
        interval: 80
        repeat: false
        onTriggered: service._syncGlassEffect()
    }

    property Component processFactory: Component {
        Process {
            stdout: StdioCollector {}
            stderr: StdioCollector {}
        }
    }

    function _makeProcess(command) {
        try {
            return processFactory.createObject(service, { command })
        } catch (error) {
            console.warn("[AppearanceConfig] cannot create process: " + error)
        }
        return null
    }

    function _save() {
        const payload = JSON.stringify({
            version: 3,
            blurStrength: service.blurStrength,
            liquidStrength: service.liquidStrength,
            shellStyle: service.shellStyle,
            barIntegratedWithDock: service.barIntegratedWithDock,
        }, null, 2)
        const process = _makeProcess([
            "sh", "-c",
            "mkdir -p \"$1\" && printf %s \"$2\" > \"$1/config.json.tmp\" && mv \"$1/config.json.tmp\" \"$1/config.json\"",
            "appearance-config-save",
            service.configDir,
            payload,
        ])
        if (!process)
            return
        process.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("[AppearanceConfig] save failed code=" + code
                    + " stderr=" + (process.stderr?.text ?? ""))
            }
            process.destroy()
        })
        process.running = true
    }

    function _syncGlassEffect() {
        const blurLevel = Math.round(1 + service.blurStrength * 14)
        const refractionLevel = Math.round(service.liquidStrength * 20)
        const process = _makeProcess([
            "sh", "-c",
            "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BlurStrength \"$1\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key DockBlurStrength \"$1\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key RefractionStrength \"$2\" && "
                + "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass",
            "appearance-glass-sync",
            String(blurLevel),
            String(refractionLevel),
        ])
        if (!process)
            return
        process.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("[AppearanceConfig] Glass effect sync failed code="
                    + code + " stderr=" + (process.stderr?.text ?? ""))
            } else {
                console.log("[AppearanceConfig] Glass effect blur=" + blurLevel
                    + " liquid=" + refractionLevel)
            }
            process.destroy()
        })
        process.running = true
    }

    function _load() {
        const process = _makeProcess([
            "sh", "-c", "cat \"$1\"", "appearance-config-load",
            service.configPath,
        ])
        if (!process) {
            ready = true
            return
        }
        process.exited.connect(function(code) {
            if (code === 0 && process.stdout?.text) {
                try {
                    const object = JSON.parse(process.stdout.text)
                    const blur = service._normalized(object.blurStrength)
                    const liquid = service._normalized(object.liquidStrength)
                    const style = String(object.shellStyle ?? "")
                    const hasBarIntegration = typeof object.barIntegratedWithDock
                        === "boolean"
                    if (Number.isFinite(blur))
                        service.blurStrength = blur
                    if (Number.isFinite(liquid))
                        service.liquidStrength = liquid
                    if (service.isValidShellStyle(style))
                        service.shellStyle = style
                    if (hasBarIntegration)
                        service.barIntegratedWithDock = object.barIntegratedWithDock
                    // Schema 1 had no shellStyle; schema 2 had no Bar
                    // integration flag. Preserve compatible defaults and
                    // persist once so later readers always see schema 3.
                    if (Number(object.version) !== 3
                            || !service.isValidShellStyle(style)
                            || !hasBarIntegration)
                        service.saveTimer.restart()
                } catch (error) {
                    console.warn("[AppearanceConfig] parse error: " + error)
                }
            }
            service.ready = true
            service.effectSyncTimer.restart()
            process.destroy()
        })
        process.running = true
    }

    Component.onCompleted: _load()
}
