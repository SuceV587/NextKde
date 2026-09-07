pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.desktop.modules.platform

// Global appearance settings shared by shell surfaces. Keep these values out
// of DockConfigService: glass material is a shell-wide concern, while pinned
// items, Dock geometry and visibility remain Dock-owned state.
QtObject {
    id: service

    readonly property string configDir: Quickshell.stateDir + "/appearance"
    readonly property string configPath: configDir + "/config.json"

    // Global baseline settings and per-component overrides.
    property real globalBlurStrength: 0.42
    property real globalLiquidStrength: 1.0

    property real blurStrength: globalBlurStrength
    property real liquidStrength: globalLiquidStrength

    property bool dockBlurInherit: true
    property real dockBlurStrength: 0.42
    property real dockLiquidStrength: 1.0

    property bool barBlurInherit: true
    property real barBlurStrength: 0.42
    property real barLiquidStrength: 1.0

    property bool controlCenterBlurInherit: true
    property real controlCenterBlurStrength: 0.42
    property real controlCenterLiquidStrength: 1.0

    property bool launcherBlurInherit: true
    property real launcherBlurStrength: 0.42
    property real launcherLiquidStrength: 1.0

    // Resolved effective strengths consumed by each surface
    readonly property real effectiveDockBlur: dockBlurInherit ? globalBlurStrength : dockBlurStrength
    readonly property real effectiveDockLiquid: dockBlurInherit ? globalLiquidStrength : dockLiquidStrength
    readonly property real effectiveBarBlur: barBlurInherit ? globalBlurStrength : barBlurStrength
    readonly property real effectiveBarLiquid: barBlurInherit ? globalLiquidStrength : barLiquidStrength
    readonly property real effectiveControlCenterBlur: controlCenterBlurInherit ? globalBlurStrength : controlCenterBlurStrength
    readonly property real effectiveControlCenterLiquid: controlCenterBlurInherit ? globalLiquidStrength : controlCenterLiquidStrength
    readonly property real effectiveLauncherBlur: launcherBlurInherit ? globalBlurStrength : launcherBlurStrength
    readonly property real effectiveLauncherLiquid: launcherBlurInherit ? globalLiquidStrength : launcherLiquidStrength

    // "macos" matches the shell geometry that predates selectable styles,
    // so upgrading an existing installation does not unexpectedly reshape it.
    property string shellStyle: "macos"
    property bool barIntegratedWithDock: false
    property string barVisibilityMode: "always" // "always" | "smart" | "persistent"
    property string barLayoutMode: "transparent" // "full" | "floating" | "transparent"
    property string dockWindowAnimationStyle: "scale"
    property bool ready: false

    function isValidShellStyle(value) {
        return value === "windows12" || value === "macos"
            || value === "material"
    }

    function isValidBarVisibilityMode(value) {
        return value === "always" || value === "smart"
            || value === "persistent"
    }

    function isValidBarLayoutMode(value) {
        return value === "full" || value === "floating" || value === "transparent"
    }

    function isValidDockWindowAnimationStyle(value) {
        return value === "scale" || value === "genie"
    }

    function _normalized(value, fallback = NaN) {
        const number = Number(value)
        return Number.isFinite(number)
            ? Math.max(0.0, Math.min(1.0, number)) : fallback
    }

    // Blur radius is perceived much more strongly in the lower half of the
    // compositor's 15-step range.  A perceptual response keeps the middle of
    // the settings slider clear and refractive, while preserving both end
    // points for users who explicitly want no blur or maximum frosting.
    function _compositorBlurLevel(strength) {
        const value = _normalized(strength)
        return Number.isFinite(value)
            ? Math.round(1 + Math.pow(value, 1.5) * 14) : 1
    }

    function _toBool(value) {
        return value === true || value === 1
            || String(value).toLowerCase() === "true"
    }

    function updateGlobalBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(globalBlurStrength - value) <= 0.001)
            return false
        globalBlurStrength = value
        blurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateGlobalLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(globalLiquidStrength - value) <= 0.001)
            return false
        globalLiquidStrength = value
        liquidStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    // Dock overrides
    function updateDockBlurInherit(rawValue) {
        const value = _toBool(rawValue)
        if (dockBlurInherit === value)
            return false
        dockBlurInherit = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateDockBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(dockBlurStrength - value) <= 0.001)
            return false
        dockBlurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateDockLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(dockLiquidStrength - value) <= 0.001)
            return false
        dockLiquidStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    // Bar overrides
    function updateBarBlurInherit(rawValue) {
        const value = _toBool(rawValue)
        if (barBlurInherit === value)
            return false
        barBlurInherit = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateBarBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(barBlurStrength - value) <= 0.001)
            return false
        barBlurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateBarLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(barLiquidStrength - value) <= 0.001)
            return false
        barLiquidStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    // Control Center overrides
    function updateControlCenterBlurInherit(rawValue) {
        const value = _toBool(rawValue)
        if (controlCenterBlurInherit === value)
            return false
        controlCenterBlurInherit = value
        saveTimer.restart()
        return true
    }

    function updateControlCenterBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(controlCenterBlurStrength - value) <= 0.001)
            return false
        controlCenterBlurStrength = value
        saveTimer.restart()
        return true
    }

    function updateControlCenterLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(controlCenterLiquidStrength - value) <= 0.001)
            return false
        controlCenterLiquidStrength = value
        saveTimer.restart()
        return true
    }

    // Launcher overrides
    function updateLauncherBlurInherit(rawValue) {
        const value = _toBool(rawValue)
        if (launcherBlurInherit === value)
            return false
        launcherBlurInherit = value
        saveTimer.restart()
        return true
    }

    function updateLauncherBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(launcherBlurStrength - value) <= 0.001)
            return false
        launcherBlurStrength = value
        saveTimer.restart()
        return true
    }

    function updateLauncherLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(launcherLiquidStrength - value) <= 0.001)
            return false
        launcherLiquidStrength = value
        saveTimer.restart()
        return true
    }

    // Backward compatibility aliases
    function updateBlurStrength(rawValue) {
        return updateGlobalBlurStrength(rawValue)
    }

    function updateLiquidStrength(rawValue) {
        return updateGlobalLiquidStrength(rawValue)
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
        const value = _toBool(rawValue)
        if (barIntegratedWithDock === value)
            return false
        barIntegratedWithDock = value
        saveTimer.restart()
        return true
    }

    function updateBarVisibilityMode(rawMode) {
        const mode = String(rawMode)
        if (!isValidBarVisibilityMode(mode) || barVisibilityMode === mode)
            return false
        barVisibilityMode = mode
        saveTimer.restart()
        return true
    }

    function updateBarLayoutMode(rawMode) {
        const mode = String(rawMode)
        if (!isValidBarLayoutMode(mode) || barLayoutMode === mode)
            return false
        barLayoutMode = mode
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
        globalBlurStrength = 0.42
        globalLiquidStrength = 1.0
        blurStrength = 0.42
        liquidStrength = 1.0

        dockBlurInherit = true
        dockBlurStrength = 0.42
        dockLiquidStrength = 1.0

        barBlurInherit = true
        barBlurStrength = 0.42
        barLiquidStrength = 1.0

        controlCenterBlurInherit = true
        controlCenterBlurStrength = 0.42
        controlCenterLiquidStrength = 1.0

        launcherBlurInherit = true
        launcherBlurStrength = 0.42
        launcherLiquidStrength = 1.0

        saveTimer.restart()
        effectSyncTimer.restart()
        return true
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
            version: 10,
            globalBlurStrength: service.globalBlurStrength,
            globalLiquidStrength: service.globalLiquidStrength,
            blurStrength: service.globalBlurStrength,
            liquidStrength: service.globalLiquidStrength,
            dockBlurInherit: service.dockBlurInherit,
            dockBlurStrength: service.dockBlurStrength,
            dockLiquidStrength: service.dockLiquidStrength,
            barBlurInherit: service.barBlurInherit,
            barBlurStrength: service.barBlurStrength,
            barLiquidStrength: service.barLiquidStrength,
            controlCenterBlurInherit: service.controlCenterBlurInherit,
            controlCenterBlurStrength: service.controlCenterBlurStrength,
            controlCenterLiquidStrength: service.controlCenterLiquidStrength,
            launcherBlurInherit: service.launcherBlurInherit,
            launcherBlurStrength: service.launcherBlurStrength,
            launcherLiquidStrength: service.launcherLiquidStrength,
            shellStyle: service.shellStyle,
            barIntegratedWithDock: service.barIntegratedWithDock,
            barVisibilityMode: service.barVisibilityMode,
            barLayoutMode: service.barLayoutMode,
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
        })
        process.running = true
    }

    function _syncGlassEffect() {
        const dockBlurLevel = service._compositorBlurLevel(
            service.effectiveDockBlur)
        const contentBlurLevel = service._compositorBlurLevel(
            service.effectiveBarBlur)
        const refractionLevel = Math.round(service.globalLiquidStrength * 20)
        PlatformClient.request("theme.sync-glass", {
            contentBlurLevel: contentBlurLevel,
            dockBlurLevel: dockBlurLevel,
            refractionLevel: refractionLevel,
        }, function(response) {
            if (!response?.ok)
                console.warn("[AppearanceConfig] Glass effect sync failed: "
                    + (response?.error?.message || "platform unavailable"))
            else {
                console.log("[AppearanceConfig] Glass effect dockBlur=" + dockBlurLevel
                    + " contentBlur=" + contentBlurLevel + " liquid=" + refractionLevel)
            }
        })
        const process = _makeProcess([
            "sh", "-c",
            "if [ \"$(kreadconfig6 --file kwinrc --group Plugins --key glassEnabled 2>/dev/null)\" = \"true\" ]; then "
                + "  if [ \"$(qdbus6 org.kde.KWin /Effects org.kde.KWin.Effects.isEffectLoaded glass 2>/dev/null)\" != \"true\" ]; then "
                + "    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect blur 2>/dev/null; "
                + "    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect glass 2>/dev/null; "
                + "  fi; "
                + "else "
                + "  if [ \"$(qdbus6 org.kde.KWin /Effects org.kde.KWin.Effects.isEffectLoaded glass 2>/dev/null)\" = \"true\" ]; then "
                + "    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect glass 2>/dev/null; "
                + "  fi; "
                + "  if [ \"$(qdbus6 org.kde.KWin /Effects org.kde.KWin.Effects.isEffectLoaded blur 2>/dev/null)\" != \"true\" ]; then "
                + "    qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect blur 2>/dev/null; "
                + "  fi; "
                + "fi",
            "appearance-glass-load-unload"
        ])
        if (process) {
            process.exited.connect(function() { process.destroy() })
            process.running = true
        }
    }

    function _syncDockWindowAnimationEffect() {
        PlatformClient.request("theme.sync-dock-animation", {
            style: service.dockWindowAnimationStyle,
        }, function(response) {
            if (!response?.ok)
                console.warn("[AppearanceConfig] Dock animation sync failed: "
                    + (response?.error?.message || "platform unavailable"))
            else {
                console.log("[AppearanceConfig] Dock window animation="
                    + service.dockWindowAnimationStyle)
            }
        })
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
                    const globalBlur = service._normalized(object.globalBlurStrength
                        ?? object.blurStrength ?? object.dockBlurStrength, 0.42)
                    const globalLiquid = service._normalized(object.globalLiquidStrength
                        ?? object.liquidStrength ?? object.dockLiquidStrength, 1.0)
                    const style = String(object.shellStyle ?? "")
                    const hasBarIntegration = typeof object.barIntegratedWithDock === "boolean"
                    const barVisibility = String(object.barVisibilityMode ?? "")
                    const barLayout = String(object.barLayoutMode ?? "")
                    const animationStyle = String(object.dockWindowAnimationStyle ?? "")

                    service.globalBlurStrength = globalBlur
                    service.blurStrength = globalBlur
                    service.globalLiquidStrength = globalLiquid
                    service.liquidStrength = globalLiquid

                    service.dockBlurInherit = object.dockBlurInherit !== undefined
                        ? Boolean(object.dockBlurInherit) : true
                    service.dockBlurStrength = service._normalized(object.dockBlurStrength, globalBlur)
                    service.dockLiquidStrength = service._normalized(object.dockLiquidStrength, globalLiquid)

                    service.barBlurInherit = object.barBlurInherit !== undefined
                        ? Boolean(object.barBlurInherit) : true
                    service.barBlurStrength = service._normalized(object.barBlurStrength, globalBlur)
                    service.barLiquidStrength = service._normalized(object.barLiquidStrength, globalLiquid)

                    service.controlCenterBlurInherit = object.controlCenterBlurInherit !== undefined
                        ? Boolean(object.controlCenterBlurInherit) : true
                    service.controlCenterBlurStrength = service._normalized(object.controlCenterBlurStrength, globalBlur)
                    service.controlCenterLiquidStrength = service._normalized(object.controlCenterLiquidStrength, globalLiquid)

                    service.launcherBlurInherit = object.launcherBlurInherit !== undefined
                        ? Boolean(object.launcherBlurInherit) : true
                    service.launcherBlurStrength = service._normalized(object.launcherBlurStrength, globalBlur)
                    service.launcherLiquidStrength = service._normalized(object.launcherLiquidStrength, globalLiquid)

                    if (service.isValidShellStyle(style))
                        service.shellStyle = style
                    if (hasBarIntegration)
                        service.barIntegratedWithDock = object.barIntegratedWithDock
                    if (service.isValidBarVisibilityMode(barVisibility))
                        service.barVisibilityMode = barVisibility
                    if (service.isValidBarLayoutMode(barLayout))
                        service.barLayoutMode = barLayout
                    if (service.isValidDockWindowAnimationStyle(animationStyle))
                        service.dockWindowAnimationStyle = animationStyle

                    if (Number(object.version) !== 10
                            || !service.isValidShellStyle(style)
                            || !hasBarIntegration
                            || !service.isValidBarVisibilityMode(barVisibility)
                            || !service.isValidBarLayoutMode(barLayout)
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
