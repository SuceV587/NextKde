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

    // Global baseline appearance settings: shared default for all shell surfaces.
    property real globalBlurStrength: 0.42
    property real globalLiquidStrength: 1.0

    // Dock blur settings: either inherits global baseline or uses independent values.
    property bool dockBlurInherit: true
    property real dockBlurStrength: 0.42
    property real dockLiquidStrength: 1.0

    // Bar blur settings: either inherits global baseline or uses independent values.
    property bool barBlurInherit: true
    property real barBlurStrength: 0.42
    property real barLiquidStrength: 1.0

    // Launcher blur settings: either inherits global baseline or uses independent values.
    property bool launcherBlurInherit: true
    property real launcherBlurStrength: 0.42
    property real launcherLiquidStrength: 1.0

    // Compatibility aliases:
    property alias barBlurInheritDock: service.barBlurInherit
    property alias launcherBlurInheritDock: service.launcherBlurInherit
    property real blurStrength: globalBlurStrength
    property real liquidStrength: globalLiquidStrength

    // Effective reactive properties for consumers:
    readonly property real effectiveDockBlur: dockBlurInherit
        ? globalBlurStrength : dockBlurStrength
    readonly property real effectiveDockLiquid: dockBlurInherit
        ? globalLiquidStrength : dockLiquidStrength
    readonly property real effectiveBarBlur: barBlurInherit
        ? globalBlurStrength : barBlurStrength
    readonly property real effectiveBarLiquid: barBlurInherit
        ? globalLiquidStrength : barLiquidStrength
    readonly property real effectiveLauncherBlur: launcherBlurInherit
        ? globalBlurStrength : launcherBlurStrength
    readonly property real effectiveLauncherLiquid: launcherBlurInherit
        ? globalLiquidStrength : launcherLiquidStrength

    // "macos" matches the shell geometry that predates selectable styles,
    // so upgrading an existing installation does not unexpectedly reshape it.
    property string shellStyle: "macos"
    property bool barIntegratedWithDock: false
    property string barVisibilityMode: "always" // "always" | "smart" | "persistent"
    property string barLayoutMode: "full" // "full" | "floating"
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
        return value === "full" || value === "floating"
    }

    function _normalized(value) {
        const number = Number(value)
        return Number.isFinite(number)
            ? Math.max(0.0, Math.min(1.0, number)) : NaN
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

    // Backward compatibility aliases
    function updateBlurStrength(rawValue) {
        return updateGlobalBlurStrength(rawValue)
    }

    function updateLiquidStrength(rawValue) {
        return updateGlobalLiquidStrength(rawValue)
    }

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

    function updateLauncherBlurInherit(rawValue) {
        const value = _toBool(rawValue)
        if (launcherBlurInherit === value)
            return false
        launcherBlurInherit = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateLauncherBlurStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(launcherBlurStrength - value) <= 0.001)
            return false
        launcherBlurStrength = value
        saveTimer.restart()
        effectSyncTimer.restart()
        return true
    }

    function updateLauncherLiquidStrength(rawValue) {
        const value = _normalized(rawValue)
        if (!Number.isFinite(value)
                || Math.abs(launcherLiquidStrength - value) <= 0.001)
            return false
        launcherLiquidStrength = value
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

    function resetStrengths() {
        const globalBlurChanged = Math.abs(globalBlurStrength - 0.42) > 0.001
        const globalLiquidChanged = Math.abs(globalLiquidStrength - 1.0) > 0.001
        const dockInheritChanged = !dockBlurInherit
        const dockBlurChanged = Math.abs(dockBlurStrength - 0.42) > 0.001
        const dockLiquidChanged = Math.abs(dockLiquidStrength - 1.0) > 0.001
        const barInheritChanged = !barBlurInherit
        const barBlurChanged = Math.abs(barBlurStrength - 0.42) > 0.001
        const barLiquidChanged = Math.abs(barLiquidStrength - 1.0) > 0.001
        const launcherInheritChanged = !launcherBlurInherit
        const launcherBlurChanged = Math.abs(launcherBlurStrength - 0.42) > 0.001
        const launcherLiquidChanged = Math.abs(launcherLiquidStrength - 1.0) > 0.001

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
        launcherBlurInherit = true
        launcherBlurStrength = 0.42
        launcherLiquidStrength = 1.0

        const changed = globalBlurChanged || globalLiquidChanged
            || dockInheritChanged || dockBlurChanged || dockLiquidChanged
            || barInheritChanged || barBlurChanged || barLiquidChanged
            || launcherInheritChanged || launcherBlurChanged || launcherLiquidChanged

        if (changed) {
            saveTimer.restart()
            effectSyncTimer.restart()
        }
        return changed
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
            version: 6,
            globalBlurStrength: service.globalBlurStrength,
            globalLiquidStrength: service.globalLiquidStrength,
            dockBlurInherit: service.dockBlurInherit,
            dockBlurStrength: service.dockBlurStrength,
            dockLiquidStrength: service.dockLiquidStrength,
            barBlurInherit: service.barBlurInherit,
            barBlurStrength: service.barBlurStrength,
            barLiquidStrength: service.barLiquidStrength,
            launcherBlurInherit: service.launcherBlurInherit,
            launcherBlurStrength: service.launcherBlurStrength,
            launcherLiquidStrength: service.launcherLiquidStrength,
            // Backwards compatibility fields for external tools
            barBlurInheritDock: service.barBlurInherit,
            launcherBlurInheritDock: service.launcherBlurInherit,
            blurStrength: service.globalBlurStrength,
            liquidStrength: service.globalLiquidStrength,
            shellStyle: service.shellStyle,
            barIntegratedWithDock: service.barIntegratedWithDock,
            barVisibilityMode: service.barVisibilityMode,
            barLayoutMode: service.barLayoutMode,
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
        const dockBlurLevel = Math.round(1 + service.effectiveDockBlur * 14)
        const contentBlurLevel = Math.round(1 + service.effectiveLauncherBlur * 14)
        const refractionLevel = Math.round(service.effectiveDockLiquid * 20)
        const process = _makeProcess([
            "sh", "-c",
            "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BlurStrength \"$1\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key DockBlurStrength \"$2\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key RefractionStrength \"$3\" && "
                + "kwriteconfig6 --file kwinrc --group Effect-blur --key BlurStrength \"$1\" && "
                + "if [ \"$(qdbus6 org.kde.KWin /Effects org.kde.KWin.Effects.isEffectLoaded glass 2>/dev/null)\" != \"true\" ]; then "
                + "  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect blur 2>/dev/null; "
                + "  qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect glass 2>/dev/null; "
                + "fi; "
                + "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass 2>/dev/null || "
                + "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect blur 2>/dev/null",
            "appearance-glass-sync",
            String(contentBlurLevel),
            String(dockBlurLevel),
            String(refractionLevel),
        ])
        if (!process)
            return
        process.exited.connect(function(code) {
            if (code !== 0) {
                console.warn("[AppearanceConfig] Glass effect sync failed code="
                    + code + " stderr=" + (process.stderr?.text ?? ""))
            } else {
                console.log("[AppearanceConfig] Glass effect dockBlur=" + dockBlurLevel
                    + " contentBlur=" + contentBlurLevel + " liquid=" + refractionLevel)
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
                    const globalBlur = service._normalized(object.globalBlurStrength ?? object.blurStrength ?? object.dockBlurStrength)
                    const globalLiquid = service._normalized(object.globalLiquidStrength ?? object.liquidStrength ?? object.dockLiquidStrength)
                    const hasDockInherit = typeof object.dockBlurInherit === "boolean"
                    const dockBlur = service._normalized(object.dockBlurStrength)
                    const dockLiquid = service._normalized(object.dockLiquidStrength)
                    const hasBarInherit = typeof object.barBlurInherit === "boolean" || typeof object.barBlurInheritDock === "boolean"
                    const barBlur = service._normalized(object.barBlurStrength)
                    const barLiquid = service._normalized(object.barLiquidStrength)
                    const hasLauncherInherit = typeof object.launcherBlurInherit === "boolean" || typeof object.launcherBlurInheritDock === "boolean"
                    const launcherBlur = service._normalized(object.launcherBlurStrength)
                    const launcherLiquid = service._normalized(object.launcherLiquidStrength)
                    const style = String(object.shellStyle ?? "")
                    const hasBarIntegration = typeof object.barIntegratedWithDock === "boolean"
                    const barVisibility = String(object.barVisibilityMode ?? "")
                    const barLayout = String(object.barLayoutMode ?? "")

                    if (Number.isFinite(globalBlur)) {
                        service.globalBlurStrength = globalBlur
                        service.blurStrength = globalBlur
                    }
                    if (Number.isFinite(globalLiquid)) {
                        service.globalLiquidStrength = globalLiquid
                        service.liquidStrength = globalLiquid
                    }
                    if (hasDockInherit)
                        service.dockBlurInherit = object.dockBlurInherit
                    if (Number.isFinite(dockBlur))
                        service.dockBlurStrength = dockBlur
                    if (Number.isFinite(dockLiquid))
                        service.dockLiquidStrength = dockLiquid
                    if (hasBarInherit)
                        service.barBlurInherit = object.barBlurInherit ?? object.barBlurInheritDock
                    if (Number.isFinite(barBlur))
                        service.barBlurStrength = barBlur
                    if (Number.isFinite(barLiquid))
                        service.barLiquidStrength = barLiquid
                    if (hasLauncherInherit)
                        service.launcherBlurInherit = object.launcherBlurInherit ?? object.launcherBlurInheritDock
                    if (Number.isFinite(launcherBlur))
                        service.launcherBlurStrength = launcherBlur
                    if (Number.isFinite(launcherLiquid))
                        service.launcherLiquidStrength = launcherLiquid
                    if (service.isValidShellStyle(style))
                        service.shellStyle = style
                    if (hasBarIntegration)
                        service.barIntegratedWithDock = object.barIntegratedWithDock
                    if (service.isValidBarVisibilityMode(barVisibility))
                        service.barVisibilityMode = barVisibility
                    if (service.isValidBarLayoutMode(barLayout))
                        service.barLayoutMode = barLayout

                    if (Number(object.version) !== 6
                            || !service.isValidShellStyle(style)
                            || !hasBarIntegration
                            || !service.isValidBarVisibilityMode(barVisibility)
                            || !service.isValidBarLayoutMode(barLayout)
                            || !hasDockInherit
                            || !hasBarInherit
                            || !hasLauncherInherit)
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
