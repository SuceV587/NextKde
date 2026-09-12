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

    // KWin owns one glass pipeline. Surface-specific overrides cannot map
    // reliably to its compositor parameters, so every shell surface shares
    // this one global configuration.
    property real globalBlurStrength: 0.42
    property real globalLiquidStrength: 1.0

    property real blurStrength: globalBlurStrength
    property real liquidStrength: globalLiquidStrength

    // Retain descriptive names at call sites; they intentionally resolve to
    // the one global KWin glass configuration.
    readonly property real effectiveDockBlur: globalBlurStrength
    readonly property real effectiveDockLiquid: globalLiquidStrength
    readonly property real effectiveBarBlur: globalBlurStrength
    readonly property real effectiveBarLiquid: globalLiquidStrength
    readonly property real effectiveLauncherBlur: globalBlurStrength
    readonly property real effectiveLauncherLiquid: globalLiquidStrength

    // "macos" matches the shell geometry that predates selectable styles,
    // so upgrading an existing installation does not unexpectedly reshape it.
    // Global colour-scheme preference shared by every shell style (mainline v10).
    property string themeMode: "system" // "system" | "light" | "dark"
    property color wallpaperSeedColor: "transparent"
    property string shellStyle: "macos"
    // 材质风格（对标澎湃 HyperOS 4「材质风格」）
    // "bionic" = 柔光玻璃 | "classic" = 轻透磨砂
    property string materialStyle: "liquid"
    property bool barIntegratedWithDock: false
    property string barVisibilityMode: "always" // "always" | "smart" | "persistent"
    property string barLayoutMode: "transparent" // "full" | "floating" | "transparent"
    property string dockWindowAnimationStyle: "scale"
    property bool ready: false

    // ── 材质专属微调（柔光玻璃 / 轻透磨砂）───────────────────────────
    // 每组只在对应材质激活时写入 kwinrc 的 [Effect-blurplus] 键；
    // 材质切换时由 _syncMaterialTuning() 按 materialStyle 分支落盘。
    // bionic（柔光玻璃）
    property real bionicRefract: 4.0        // → BionicIOR（包值 refractIOR=4.0）
    property real bionicEdgeLight: 1.4      // → BionicActivatedDirIntensity（悬停点亮强度）
    property real bionicSoftEdgePx: 1.5     // → BionicShapeEdgePx（×5）
    property real bionicHsvv: 1.0           // → BionicHsvvBoost（柔光提亮强度，1.0 = 原生）
    // classic（轻透磨砂）
    property real classicRefract: 1.5       // → ClassicRefractIOR
    property real classicReflect: 0.06     // → ClassicReflStrength
    property real classicEdgeLight: 0.1     // → ClassicStrokeStrength（描边强度）
    property real classicSoftEdgePx: 1.5    // → ClassicMaskSoft
    property real bionicTransparency: 1.0  // → BionicOverallAlpha（1.0=标准；调低更透）
    readonly property real bionicRefractMin: 1.0
    readonly property real bionicRefractMax: 5.0
    readonly property real bionicEdgeLightMin: 0.0
    readonly property real bionicEdgeLightMax: 3.0
    readonly property real bionicSoftEdgePxMin: 0.1
    readonly property real bionicSoftEdgePxMax: 25.0
    readonly property real bionicHsvvMin: 0.0
    readonly property real bionicHsvvMax: 2.0
    readonly property real bionicTransparencyMin: 0.0
    readonly property real bionicTransparencyMax: 1.0
    readonly property real classicRefractMin: 1.0
    readonly property real classicRefractMax: 2.0
    readonly property real classicReflectMin: 0.0
    readonly property real classicReflectMax: 1.5
    readonly property real classicEdgeLightMin: 0.0
    readonly property real classicEdgeLightMax: 0.5
    readonly property real classicSoftEdgePxMin: 0.5
    readonly property real classicSoftEdgePxMax: 25.0

    function isValidThemeMode(value) {
        return value === "system" || value === "light" || value === "dark"
    }

    function updateThemeMode(rawMode) {
        const mode = String(rawMode)
        if (!isValidThemeMode(mode) || themeMode === mode)
            return false
        themeMode = mode
        saveTimer.restart()
        return true
    }

    function isValidShellStyle(value) {
        return value === "windows12" || value === "macos"
            || value === "material" || value === "dde"
            || value === "hyperos"
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

    function _normalized(value) {
        const number = Number(value)
        return Number.isFinite(number)
            ? Math.max(0.0, Math.min(1.0, number)) : NaN
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

    // ── 材质风格（液态玻璃[KOS原有] / 柔光玻璃 / 轻透磨砂）──
    function isValidMaterialStyle(value) {
        return value === "liquid" || value === "bionic" || value === "classic"
    }

    function updateMaterialStyle(rawStyle) {
        const style = String(rawStyle)
        if (!isValidMaterialStyle(style))
            return false
        materialStyle = style
        _applyKwinGlass(style)
        materialTuningSyncTimer.restart()
        saveTimer.restart()
        return true
    }

    // 材质风格 → KWin 玻璃特效完整参数
    //   liquid  = KOS 原有液态玻璃（默认）
    //   bionic  = 柔光玻璃（物理光场全开：斯涅尔折射 + 色散 + 边缘光 + 双向色调）
    //   classic = 轻透磨砂（物理关，经典磨砂）
    // 参数映射自 18 Fold 的 BionicToken 37 参数配方
    function _materialKwinParams(style) {
        if (style === "bionic")
            return {
                BionicMode: "true",
                ClassicMode: "false",
                BlurStrength: "12",
                RefractionStrength: "14",
                PhysicallyBasedRefraction: "true",
                RefractionRGBFringing: "0.7",
                RefractionEdgeSize: "28",
                RefractionBevelIntensity: "14",
                HighlightWidthPx: "4",
                EdgeLightingDock: "true",
                AutoTintAlpha: "true",
                TintColor: "#281c1c1e",
                NoiseStrength: "3",
            }
        if (style === "classic")
            return {
                BionicMode: "false",
                ClassicMode: "true",
                BlurStrength: "6",
                RefractionStrength: "3",
                PhysicallyBasedRefraction: "false",
                RefractionRGBFringing: "0.3",
                RefractionEdgeSize: "12",
                RefractionBevelIntensity: "10",
                HighlightWidthPx: "3",
                EdgeLightingDock: "false",
                AutoTintAlpha: "false",
                TintColor: "#3c0a0a0a",
                NoiseStrength: "5",
            }
        // liquid（KOS 原有）
        return {
            BionicMode: "false",
            ClassicMode: "false",
            BlurStrength: "3",
            RefractionStrength: "8",
            PhysicallyBasedRefraction: "false",
            RefractionRGBFringing: "1.0",
            RefractionEdgeSize: "20",
            RefractionBevelIntensity: "10",
            HighlightWidthPx: "3",
            EdgeLightingDock: "false",
            AutoTintAlpha: "false",
            TintColor: "#3c0a0a0a",
            NoiseStrength: "5",
        }
    }

    function _applyKwinGlass(style) {
        const params = _materialKwinParams(style)
        let cmd = ""
        for (const key in params) {
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key " + key
                + " '" + params[key] + "'; "
        }
        cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key DecorationBlurStrength " + params.BlurStrength
            + "; kwriteconfig6 --file kwinrc --group Effect-blurplus --key DockBlurStrength " + params.BlurStrength
            + "; qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true; "
            // BionicMode 切换的是渲染路径，需要重载已加载的玻璃特效才会生效
            + "for e in glass glass5 glass6 glass7 glass8 glass10; do if qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded \"$e\" 2>/dev/null | grep -q true; then qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect \"$e\"; sleep 0.3; qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect \"$e\"; fi; done"
        const process = _makeProcess(["bash", "-c", cmd])
        if (process)
            process.running = true
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
        const globalBlurChanged = Math.abs(globalBlurStrength - 0.42) > 0.001
        const globalLiquidChanged = Math.abs(globalLiquidStrength - 1.0) > 0.001

        globalBlurStrength = 0.42
        globalLiquidStrength = 1.0
        blurStrength = 0.42
        liquidStrength = 1.0

        const changed = globalBlurChanged || globalLiquidChanged

        if (changed) {
            saveTimer.restart()
            effectSyncTimer.restart()
        }
        return changed
    }

    // ── 材质微调 updaters（每个参数只在对应材质生效）─────────────────
    function updateBionicRefract(rawValue) {
        const value = _clampInRange(rawValue, bionicRefractMin, bionicRefractMax)
        if (!Number.isFinite(value) || Math.abs(bionicRefract - value) <= 0.001)
            return false
        bionicRefract = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicEdgeLight(rawValue) {
        const value = _clampInRange(rawValue, bionicEdgeLightMin, bionicEdgeLightMax)
        if (!Number.isFinite(value) || Math.abs(bionicEdgeLight - value) <= 0.001)
            return false
        bionicEdgeLight = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicSoftEdgePx(rawValue) {
        const value = _clampInRange(rawValue, bionicSoftEdgePxMin, bionicSoftEdgePxMax)
        if (!Number.isFinite(value) || Math.abs(bionicSoftEdgePx - value) <= 0.001)
            return false
        bionicSoftEdgePx = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicHsvv(rawValue) {
        const value = _clampInRange(rawValue, bionicHsvvMin, bionicHsvvMax)
        if (!Number.isFinite(value) || Math.abs(bionicHsvv - value) <= 0.001)
            return false
        bionicHsvv = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateClassicRefract(rawValue) {
        const value = _clampInRange(rawValue, classicRefractMin, classicRefractMax)
        if (!Number.isFinite(value) || Math.abs(classicRefract - value) <= 0.001)
            return false
        classicRefract = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateClassicReflect(rawValue) {
        const value = _clampInRange(rawValue, classicReflectMin, classicReflectMax)
        if (!Number.isFinite(value) || Math.abs(classicReflect - value) <= 0.001)
            return false
        classicReflect = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateClassicEdgeLight(rawValue) {
        const value = _clampInRange(rawValue, classicEdgeLightMin, classicEdgeLightMax)
        if (!Number.isFinite(value) || Math.abs(classicEdgeLight - value) <= 0.001)
            return false
        classicEdgeLight = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateClassicSoftEdgePx(rawValue) {
        const value = _clampInRange(rawValue, classicSoftEdgePxMin, classicSoftEdgePxMax)
        if (!Number.isFinite(value) || Math.abs(classicSoftEdgePx - value) <= 0.001)
            return false
        classicSoftEdgePx = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicTransparency(rawValue) {
        const value = _clampInRange(rawValue, bionicTransparencyMin, bionicTransparencyMax)
        if (!Number.isFinite(value) || Math.abs(bionicTransparency - value) <= 0.001)
            return false
        bionicTransparency = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function resetMaterialTuning() {
        const changed = Math.abs(bionicRefract - 4.0) > 0.001
            || Math.abs(bionicEdgeLight - 1.4) > 0.001
            || Math.abs(bionicSoftEdgePx - 1.5) > 0.001
            || Math.abs(bionicHsvv - 1.0) > 0.001
            || Math.abs(classicRefract - 1.5) > 0.001
            || Math.abs(classicReflect - 0.06) > 0.001
            || Math.abs(classicEdgeLight - 0.1) > 0.001
            || Math.abs(classicSoftEdgePx - 1.5) > 0.001
            || Math.abs(bionicTransparency - 1.0) > 0.001
        bionicRefract = 4.0
        bionicEdgeLight = 1.4
        bionicSoftEdgePx = 1.5
        bionicHsvv = 1.0
        classicRefract = 1.5
        classicReflect = 0.06
        classicEdgeLight = 0.1
        classicSoftEdgePx = 1.5
        bionicTransparency = 1.0
        if (changed) {
            saveTimer.restart()
            materialTuningSyncTimer.restart()
        }
        return changed
    }

    // 材质专属参数 → kwinrc（materialStyle 门控：只写当前材质的键）
    function _syncMaterialTuning() {
        let cmd = ""
        if (service.materialStyle === "bionic") {
            cmd = "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicIOR '" + service.bionicRefract + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedDirIntensity '" + service.bionicEdgeLight + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedDirOppositeIntensity '" + (service.bionicEdgeLight * 0.5) + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicShapeEdgePx '" + (service.bionicSoftEdgePx * 5.0) + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicHsvvBoost '" + service.bionicHsvv + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicOverallAlpha '" + service.bionicTransparency + "'; "
        } else if (service.materialStyle === "classic") {
            cmd = "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicRefractIOR '" + service.classicRefract + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicReflStrength '" + service.classicReflect + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicStrokeStrength '" + service.classicEdgeLight + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicMaskSoft '" + service.classicSoftEdgePx + "'; "
        } else {
            return
        }
        cmd += "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass 2>/dev/null || true"
        const process = _makeProcess(["bash", "-c", cmd])
        if (process)
            process.running = true
    }

    // ────────────────────────────────────────────────────────────────
    // Dock surface tuning updaters
    // ────────────────────────────────────────────────────────────────
    // Each returns false when the value is rejected (non-finite or outside the
    // documented range) so the Settings UI can tell a no-op from a real change.
    function _clampInRange(rawValue, min, max) {
        const number = Number(rawValue)
        if (!Number.isFinite(number))
            return NaN
        return Math.max(min, Math.min(max, number))
    }
    // Restore the DDE-derived surface defaults without touching the selected
    // shell style, blur or liquid strengths.
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

    // 材质微调专用（延迟稍长，避开 _applyKwinGlass 的并行写入）
    property Timer materialTuningSyncTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: service._syncMaterialTuning()
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
            version: 12,
            globalBlurStrength: service.globalBlurStrength,
            globalLiquidStrength: service.globalLiquidStrength,
            blurStrength: service.globalBlurStrength,
            liquidStrength: service.globalLiquidStrength,
            shellStyle: service.shellStyle,
            materialStyle: service.materialStyle,
            themeMode: service.themeMode,
            barIntegratedWithDock: service.barIntegratedWithDock,
            barVisibilityMode: service.barVisibilityMode,
            barLayoutMode: service.barLayoutMode,
            dockWindowAnimationStyle: service.dockWindowAnimationStyle,
            bionicRefract: service.bionicRefract,
            bionicEdgeLight: service.bionicEdgeLight,
            bionicSoftEdgePx: service.bionicSoftEdgePx,
            bionicHsvv: service.bionicHsvv,
            classicRefract: service.classicRefract,
            classicReflect: service.classicReflect,
            classicEdgeLight: service.classicEdgeLight,
            classicSoftEdgePx: service.classicSoftEdgePx,
            bionicTransparency: service.bionicTransparency,
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

    // 材质风格专属的玻璃参数（非 liquid 时接管，忽略用户滑条）
    function _materialGlassParams(style) {
        if (style === "bionic")
            return { blur: 12, refr: 14 }
        if (style === "classic")
            return { blur: 6, refr: 3 }
        return null
    }

    function _syncGlassEffect() {
        // 材质模式：强制模式参数，用户滑条不参与
        const materialParams = service._materialGlassParams(service.materialStyle)
        if (materialParams) {
            PlatformClient.request("theme.sync-glass", {
                contentBlurLevel: materialParams.blur,
                dockBlurLevel: materialParams.blur,
                refractionLevel: materialParams.refr,
            }, function(response) {
                if (!response?.ok)
                    console.warn("[AppearanceConfig] Material glass sync failed: "
                        + (response?.error?.message || "platform unavailable"))
                else
                    console.log("[AppearanceConfig] Material glass=" + service.materialStyle
                        + " blur=" + materialParams.blur + " refr=" + materialParams.refr)
            })
            return
        }
        // liquid（KOS 原有）：用户滑条逻辑
        const dockBlurLevel = service._compositorBlurLevel(
            service.globalBlurStrength)
        const contentBlurLevel = service._compositorBlurLevel(
            service.globalBlurStrength)
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
                    // Old v7 files may have a Dock value but never a global
                    // one. Read it once as the global migration source, then
                    // save the flattened v8 shape below.
                    const globalBlur = service._normalized(object.globalBlurStrength
                        ?? object.blurStrength ?? object.dockBlurStrength)
                    const globalLiquid = service._normalized(object.globalLiquidStrength
                        ?? object.liquidStrength ?? object.dockLiquidStrength)
                    const style = String(object.shellStyle ?? "")
                    const themeMode = String(object.themeMode ?? "")
                    const hasBarIntegration = typeof object.barIntegratedWithDock === "boolean"
                    const barVisibility = String(object.barVisibilityMode ?? "")
                    const barLayout = String(object.barLayoutMode ?? "")
                    const animationStyle = String(object.dockWindowAnimationStyle ?? "")
                    if (Number.isFinite(globalBlur)) {
                        service.globalBlurStrength = globalBlur
                        service.blurStrength = globalBlur
                    }
                    if (Number.isFinite(globalLiquid)) {
                        service.globalLiquidStrength = globalLiquid
                        service.liquidStrength = globalLiquid
                    }
                    if (service.isValidThemeMode(themeMode))
                        service.themeMode = themeMode
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
                    // v11 adds material-specific tuning (bionic/classic).
                    const bRefract = service._clampInRange(
                        object.bionicRefract ?? 1.2, service.bionicRefractMin, service.bionicRefractMax)
                    const bEdge = service._clampInRange(
                        object.bionicEdgeLight ?? 1.4, service.bionicEdgeLightMin, service.bionicEdgeLightMax)
                    const bSoft = service._clampInRange(
                        object.bionicSoftEdgePx ?? 1.5, service.bionicSoftEdgePxMin, service.bionicSoftEdgePxMax)
                    const bHsvv = service._clampInRange(
                        object.bionicHsvv ?? 1.0, service.bionicHsvvMin, service.bionicHsvvMax)
                    if (Number.isFinite(bHsvv))
                        service.bionicHsvv = bHsvv
                    const bTrans = service._clampInRange(
                        object.bionicTransparency ?? 1.0, service.bionicTransparencyMin, service.bionicTransparencyMax)
                    const cRefract = service._clampInRange(
                        object.classicRefract ?? 1.5, service.classicRefractMin, service.classicRefractMax)
                    const cReflect = service._clampInRange(
                        object.classicReflect ?? 0.6, service.classicReflectMin, service.classicReflectMax)
                    const cEdge = service._clampInRange(
                        object.classicEdgeLight ?? 0.1, service.classicEdgeLightMin, service.classicEdgeLightMax)
                    const cSoft = service._clampInRange(
                        object.classicSoftEdgePx ?? 1.5, service.classicSoftEdgePxMin, service.classicSoftEdgePxMax)
                    if (Number.isFinite(bRefract))
                        service.bionicRefract = bRefract
                    if (Number.isFinite(bEdge))
                        service.bionicEdgeLight = bEdge
                    if (Number.isFinite(bSoft))
                        service.bionicSoftEdgePx = bSoft
                    if (Number.isFinite(cRefract))
                        service.classicRefract = cRefract
                    if (Number.isFinite(cReflect))
                        service.classicReflect = cReflect
                    if (Number.isFinite(cEdge))
                        service.classicEdgeLight = cEdge
                    if (Number.isFinite(cSoft))
                        service.classicSoftEdgePx = cSoft
                    if (Number.isFinite(bTrans))
                        service.bionicTransparency = bTrans

                    if (Number(object.version) !== 12
                            || !service.isValidShellStyle(style)
                            || !hasBarIntegration
                            || !service.isValidBarVisibilityMode(barVisibility)
                            || !service.isValidBarLayoutMode(barLayout)
                            || !service.isValidDockWindowAnimationStyle(animationStyle)
                            || !Number.isFinite(radiusScale)
                            || !Number.isFinite(darkDensity)
                            || !Number.isFinite(edgeStrength)
                            || !Number.isFinite(bRefract)
                            || !Number.isFinite(bEdge)
                            || !Number.isFinite(bSoft)
                            || !Number.isFinite(bHsvv)
                            || !Number.isFinite(cRefract)
                            || !Number.isFinite(cReflect)
                            || !Number.isFinite(cEdge)
                            || !Number.isFinite(cSoft))
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
