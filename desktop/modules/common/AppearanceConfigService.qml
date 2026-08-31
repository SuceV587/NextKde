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
    property string dockWindowAnimationStyle: "scale"
    property bool ready: false

    function isValidShellStyle(value) {
        return value === "windows12" || value === "macos"
            || value === "material"
    }

    function isValidDockWindowAnimationStyle(value) {
        return value === "scale" || value === "genie"
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

    function updateDockWindowAnimationStyle(rawStyle) {
        const style = String(rawStyle)
        if (!isValidDockWindowAnimationStyle(style)
                || dockWindowAnimationStyle === style)
            return false
        dockWindowAnimationStyle = style
        saveTimer.restart()
        dockAnimationEffectSyncTimer.restart()
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

    property Timer dockAnimationEffectSyncTimer: Timer {
        interval: 80
        repeat: false
        onTriggered: service._syncDockWindowAnimationEffect()
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
            version: 4,
            blurStrength: service.blurStrength,
            liquidStrength: service.liquidStrength,
            shellStyle: service.shellStyle,
            barIntegratedWithDock: service.barIntegratedWithDock,
            dockWindowAnimationStyle: service.dockWindowAnimationStyle,
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

    function _syncDockWindowAnimationEffect() {
        const process = _makeProcess([
            "sh", "-c",
            "kwriteconfig6 --file kwinrc --group Effect-kos_dock_window_animation "
                + "--key AnimationStyle \"$1\" && "
                + "qdbus6 org.kde.KWin /Effects "
                + "org.kde.kwin.Effects.reconfigureEffect kos_dock_window_animation",
            "appearance-dock-animation-sync",
            service.dockWindowAnimationStyle,
        ])
        if (!process)
            return
        process.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("[AppearanceConfig] Dock animation sync failed code="
                    + code + " stderr=" + (process.stderr?.text ?? ""))
            } else {
                console.log("[AppearanceConfig] Dock window animation="
                    + service.dockWindowAnimationStyle)
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
                    const animationStyle = String(object.dockWindowAnimationStyle ?? "")
                    if (Number.isFinite(blur))
                        service.blurStrength = blur
                    if (Number.isFinite(liquid))
                        service.liquidStrength = liquid
                    if (service.isValidShellStyle(style))
                        service.shellStyle = style
                    if (hasBarIntegration)
                        service.barIntegratedWithDock = object.barIntegratedWithDock
                    if (service.isValidDockWindowAnimationStyle(animationStyle))
                        service.dockWindowAnimationStyle = animationStyle
                    // Schema 1 had no shellStyle; schema 2 had no Bar
                    // integration flag. Preserve compatible defaults and
                    // persist once so later readers always see schema 4.
                    if (Number(object.version) !== 4
                            || !service.isValidShellStyle(style)
                            || !hasBarIntegration
                            || !service.isValidDockWindowAnimationStyle(animationStyle))
                        service.saveTimer.restart()
                } catch (error) {
                    console.warn("[AppearanceConfig] parse error: " + error)
                }
            }
            service.ready = true
            service.effectSyncTimer.restart()
            service.dockAnimationEffectSyncTimer.restart()
            process.destroy()
        })
        process.running = true
    }

    Component.onCompleted: _load()
}
