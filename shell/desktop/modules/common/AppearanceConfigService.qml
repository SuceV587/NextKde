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
    property string shellStyle: "macos"
    // 材质风格（对标澎湃 HyperOS 4「材质风格」）
    // "bionic" = 柔光玻璃 | "classic" = 轻透磨砂
    property string materialStyle: "liquid"
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
    property real classicStrokeDegree: 24.0  // → ClassicStrokeDegree
    property real classicStrokeSize: 2.0  // → ClassicStrokeSize
    property real classicReflLighten: 2.0  // → ClassicReflLighten
    property real bionicTransparency: 1.0  // → BionicOverallAlpha（1.0=标准；调低更透）
    // ── 原生激活参数（悬停/交互时的目标值，对齐 BionicsToken ACTIVATED 组）──
    property real bionicActDarken: 0.42      // → BionicActivatedDarker
    property real bionicActEdgeLight: 3.0    // → BionicActivatedDirIntensity
    property real bionicActOpposite: 2.0     // → BionicActivatedDirOppositeIntensity
    property real bionicActHsvv: 1.6         // → BionicActivatedHsvvBoost
    property real bionicActRefl: 1.3         // → BionicActivatedReflStrength
    property real bionicActRefract: 4.6      // → BionicActivatedRefract
    // ── 批1：亮度组（原生 luminanceValue + darker + brightness）──
    property real bionicLum0: 0.67  // → BionicLumValue0
    property real bionicLum1: 0.16  // → BionicLumValue1
    property real bionicLum2: 0.09  // → BionicLumValue2
    property real bionicLum3: 0.0  // → BionicLumValue3
    property real bionicLumAmount: 0.24  // → BionicLumAmount
    property real bionicDarkBase: 0.3  // → BionicDarker
    property real bionicDarkRange0: 0.6  // → BionicDarkerRange0
    property real bionicDarkRange1: 1.0  // → BionicDarkerRange1
    property real bionicBrightBase: -0.02  // → BionicBrightness
    property real bionicInnerBottom: 0.03  // → BionicInnerBottom
    property real bionicInnerWhite: 0.2  // → BionicInnerColorWhite
    property real bionicInnerMix: 0.3  // → BionicInnerColorMix
    property real bionicColorPow: 1.0  // → BionicColorPow
    property real bionicAlphaLayer: 0.1  // → BionicAlpha
    property real bionicShapeEdgePow: 3.8  // → BionicShapeEdgePow
    property real bionicShapeThickness: 80.0  // → BionicShapeThicknessPx
    property real bionicReflectOffset: 800.0  // → BionicShapeReflectOffsetPx
    property real bionicReflLighten: 1.2  // → BionicReflLighten
    property real bionicReflStrength: 1.0  // → BionicReflStrength
    property real bionicDirX: -0.4  // → BionicDirX
    property real bionicDirY: 0.6  // → BionicDirY
    property real bionicDirZ: -0.8  // → BionicDirZ
    property real bionicDirInt: 1.4  // → BionicDirIntensity
    property real bionicDirOpp: 0.7  // → BionicDirOppositeIntensity
    property real bionicDirAngle: 0.8  // → BionicDirAngleRange
    property real bionicDirEdgePow: 1.15  // → BionicDirEdgePow
    property real bionicBgSat: 2.0  // → BionicBgColorSaturation
    property real bionicBgBri: 0.0  // → BionicBgColorBrightness
    property real bionicActColorPow: 1.0  // → BionicActivatedColorPow
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
    // Global colour-scheme preference shared by every shell style. The Dock
    // settings page historically persisted this value in DockConfigService;
    // that service mirrors the legacy value here during migration.
    property string themeMode: "system" // "system" | "light" | "dark"
    // AppearanceTokens' wallpaper bridge persists this once the shared
    // WallpaperColorSource reports a sampled seed; AppearanceTokens falls back
    // to the KDE accent until then.
    property color wallpaperSeedColor: "transparent"
    property bool barIntegratedWithDock: false
    property string barVisibilityMode: "always" // "always" | "smart" | "persistent"
    property string barLayoutMode: "transparent" // "full" | "floating" | "transparent"
    property string dockWindowAnimationStyle: "scale"
    property bool ready: false

    function isValidShellStyle(value) {
        return value === "windows12" || value === "macos"
            || value === "material"
    }

    function isValidThemeMode(value) {
        return value === "system" || value === "light" || value === "dark"
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

    function isValidMaterialStyle(value) {
        return value === "liquid" || value === "bionic" || value === "classic"
    }

    function _clampInRange(rawValue, min, max) {
        const number = Number(rawValue)
        if (!Number.isFinite(number))
            return NaN
        return Math.max(min, Math.min(max, number))
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
        // liquid（KOS 原有）：只关材质开关，不写任何样式键
        // ——样式键一律删除，让主线默认值生效（避免暗色 tint / 错误模糊）
        return {
            BionicMode: "false",
            ClassicMode: "false",
        }
    }

    function _applyKwinGlass(style) {
        const params = _materialKwinParams(style)
        let cmd = ""
        for (const key in params) {
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key " + key
                + " '" + params[key] + "'; "
        }
        if (style === "liquid") {
            // 切回液态：完整恢复主线用户滑条值与透明 tint
            const liqBlur = service._compositorBlurLevel(service.globalBlurStrength)
            const liqRefr = Math.round(service.globalLiquidStrength * 20)
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key TintColor -- '#00000000'; "
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BlurStrength " + liqBlur + "; "
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key DockBlurStrength " + liqBlur + "; "
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key DecorationBlurStrength " + liqBlur + "; "
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key RefractionStrength " + liqRefr + "; "
        } else {
            cmd += "kwriteconfig6 --file kwinrc --group Effect-blurplus --key DecorationBlurStrength " + params.BlurStrength
                + "; kwriteconfig6 --file kwinrc --group Effect-blurplus --key DockBlurStrength " + params.BlurStrength + "; "
        }
        cmd += "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass 2>/dev/null; "
            + "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect blur 2>/dev/null; "
            + "qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true; "
            // BionicMode 切换的是渲染路径，需要重载已加载的玻璃特效才会生效
            + "for e in glass glass5 glass6 glass7 glass8 glass10; do if qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded \"$e\" 2>/dev/null | grep -q true; then qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect \"$e\"; sleep 0.3; qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect \"$e\"; fi; done"
        console.log("[Material] apply=" + style + " len=" + cmd.length)
        Quickshell.execDetached(["bash", "-c", cmd])
        console.log("[Material] apply=" + style)
        Quickshell.execDetached(["bash", "-c", cmd])
    }

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

    function updateBionicActDarken(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicActDarken - value) <= 0.001)
            return false
        bionicActDarken = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicActEdgeLight(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 5.0)
        if (!Number.isFinite(value) || Math.abs(bionicActEdgeLight - value) <= 0.001)
            return false
        bionicActEdgeLight = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicActOpposite(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 5.0)
        if (!Number.isFinite(value) || Math.abs(bionicActOpposite - value) <= 0.001)
            return false
        bionicActOpposite = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicActHsvv(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 3.0)
        if (!Number.isFinite(value) || Math.abs(bionicActHsvv - value) <= 0.001)
            return false
        bionicActHsvv = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicActRefl(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 3.0)
        if (!Number.isFinite(value) || Math.abs(bionicActRefl - value) <= 0.001)
            return false
        bionicActRefl = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicActRefract(rawValue) {
        const value = _clampInRange(rawValue, 1.0, 8.0)
        if (!Number.isFinite(value) || Math.abs(bionicActRefract - value) <= 0.001)
            return false
        bionicActRefract = value
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

    function updateBionicLum0(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicLum0 - value) <= 0.001)
            return false
        bionicLum0 = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicLum1(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicLum1 - value) <= 0.001)
            return false
        bionicLum1 = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicLum2(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicLum2 - value) <= 0.001)
            return false
        bionicLum2 = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicLum3(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicLum3 - value) <= 0.001)
            return false
        bionicLum3 = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicLumAmount(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicLumAmount - value) <= 0.001)
            return false
        bionicLumAmount = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDarkBase(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicDarkBase - value) <= 0.001)
            return false
        bionicDarkBase = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDarkRange0(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicDarkRange0 - value) <= 0.001)
            return false
        bionicDarkRange0 = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDarkRange1(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicDarkRange1 - value) <= 0.001)
            return false
        bionicDarkRange1 = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicBrightBase(rawValue) {
        const value = _clampInRange(rawValue, -0.2, 0.2)
        if (!Number.isFinite(value) || Math.abs(bionicBrightBase - value) <= 0.001)
            return false
        bionicBrightBase = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicInnerBottom(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicInnerBottom - value) <= 0.001)
            return false
        bionicInnerBottom = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicInnerWhite(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicInnerWhite - value) <= 0.001)
            return false
        bionicInnerWhite = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicInnerMix(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicInnerMix - value) <= 0.001)
            return false
        bionicInnerMix = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicColorPow(rawValue) {
        const value = _clampInRange(rawValue, 0.05, 3.0)
        if (!Number.isFinite(value) || Math.abs(bionicColorPow - value) <= 0.001)
            return false
        bionicColorPow = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicAlphaLayer(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicAlphaLayer - value) <= 0.001)
            return false
        bionicAlphaLayer = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicShapeEdgePow(rawValue) {
        const value = _clampInRange(rawValue, 0.5, 10.0)
        if (!Number.isFinite(value) || Math.abs(bionicShapeEdgePow - value) <= 0.001)
            return false
        bionicShapeEdgePow = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicShapeThickness(rawValue) {
        const value = _clampInRange(rawValue, 10.0, 200.0)
        if (!Number.isFinite(value) || Math.abs(bionicShapeThickness - value) <= 0.001)
            return false
        bionicShapeThickness = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicReflectOffset(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 1600.0)
        if (!Number.isFinite(value) || Math.abs(bionicReflectOffset - value) <= 0.001)
            return false
        bionicReflectOffset = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicReflLighten(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 3.0)
        if (!Number.isFinite(value) || Math.abs(bionicReflLighten - value) <= 0.001)
            return false
        bionicReflLighten = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicReflStrength(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 3.0)
        if (!Number.isFinite(value) || Math.abs(bionicReflStrength - value) <= 0.001)
            return false
        bionicReflStrength = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDirX(rawValue) {
        const value = _clampInRange(rawValue, -1.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicDirX - value) <= 0.001)
            return false
        bionicDirX = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDirY(rawValue) {
        const value = _clampInRange(rawValue, -1.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicDirY - value) <= 0.001)
            return false
        bionicDirY = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDirZ(rawValue) {
        const value = _clampInRange(rawValue, -1.0, 1.0)
        if (!Number.isFinite(value) || Math.abs(bionicDirZ - value) <= 0.001)
            return false
        bionicDirZ = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDirInt(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 5.0)
        if (!Number.isFinite(value) || Math.abs(bionicDirInt - value) <= 0.001)
            return false
        bionicDirInt = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDirOpp(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 5.0)
        if (!Number.isFinite(value) || Math.abs(bionicDirOpp - value) <= 0.001)
            return false
        bionicDirOpp = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDirAngle(rawValue) {
        const value = _clampInRange(rawValue, 0.05, 3.14)
        if (!Number.isFinite(value) || Math.abs(bionicDirAngle - value) <= 0.001)
            return false
        bionicDirAngle = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicDirEdgePow(rawValue) {
        const value = _clampInRange(rawValue, 0.1, 5.0)
        if (!Number.isFinite(value) || Math.abs(bionicDirEdgePow - value) <= 0.001)
            return false
        bionicDirEdgePow = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicBgSat(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 3.0)
        if (!Number.isFinite(value) || Math.abs(bionicBgSat - value) <= 0.001)
            return false
        bionicBgSat = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicBgBri(rawValue) {
        const value = _clampInRange(rawValue, -0.5, 0.5)
        if (!Number.isFinite(value) || Math.abs(bionicBgBri - value) <= 0.001)
            return false
        bionicBgBri = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateBionicActColorPow(rawValue) {
        const value = _clampInRange(rawValue, 0.05, 3.0)
        if (!Number.isFinite(value) || Math.abs(bionicActColorPow - value) <= 0.001)
            return false
        bionicActColorPow = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateClassicStrokeDegree(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 360.0)
        if (!Number.isFinite(value) || Math.abs(classicStrokeDegree - value) <= 0.001)
            return false
        classicStrokeDegree = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateClassicStrokeSize(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 20.0)
        if (!Number.isFinite(value) || Math.abs(classicStrokeSize - value) <= 0.001)
            return false
        classicStrokeSize = value
        saveTimer.restart()
        materialTuningSyncTimer.restart()
        return true
    }

    function updateClassicReflLighten(rawValue) {
        const value = _clampInRange(rawValue, 0.0, 4.0)
        if (!Number.isFinite(value) || Math.abs(classicReflLighten - value) <= 0.001)
            return false
        classicReflLighten = value
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
            || Math.abs(bionicActDarken - 0.42) > 0.001
            || Math.abs(bionicActEdgeLight - 3.0) > 0.001
            || Math.abs(bionicActOpposite - 2.0) > 0.001
            || Math.abs(bionicActHsvv - 1.6) > 0.001
            || Math.abs(bionicActRefl - 1.3) > 0.001
            || Math.abs(bionicActRefract - 4.6) > 0.001
            || Math.abs(bionicLum0 - (0.67)) > 0.001
            || Math.abs(bionicLum1 - (0.16)) > 0.001
            || Math.abs(bionicLum2 - (0.09)) > 0.001
            || Math.abs(bionicLum3 - (0.0)) > 0.001
            || Math.abs(bionicLumAmount - (0.24)) > 0.001
            || Math.abs(bionicDarkBase - (0.3)) > 0.001
            || Math.abs(bionicDarkRange0 - (0.6)) > 0.001
            || Math.abs(bionicDarkRange1 - (1.0)) > 0.001
            || Math.abs(bionicBrightBase - (-0.02)) > 0.001
            || Math.abs(bionicInnerBottom - (0.03)) > 0.001
            || Math.abs(bionicInnerWhite - (0.2)) > 0.001
            || Math.abs(bionicInnerMix - (0.3)) > 0.001
            || Math.abs(bionicColorPow - (1.0)) > 0.001
            || Math.abs(bionicAlphaLayer - (0.1)) > 0.001
            || Math.abs(bionicShapeEdgePow - (3.8)) > 0.001
            || Math.abs(bionicShapeThickness - (80.0)) > 0.001
            || Math.abs(bionicReflectOffset - (800.0)) > 0.001
            || Math.abs(bionicReflLighten - (1.2)) > 0.001
            || Math.abs(bionicReflStrength - (1.0)) > 0.001
            || Math.abs(bionicDirX - (-0.4)) > 0.001
            || Math.abs(bionicDirY - (0.6)) > 0.001
            || Math.abs(bionicDirZ - (-0.8)) > 0.001
            || Math.abs(bionicDirInt - (1.4)) > 0.001
            || Math.abs(bionicDirOpp - (0.7)) > 0.001
            || Math.abs(bionicDirAngle - (0.8)) > 0.001
            || Math.abs(bionicDirEdgePow - (1.15)) > 0.001
            || Math.abs(bionicBgSat - (2.0)) > 0.001
            || Math.abs(bionicBgBri - (0.0)) > 0.001
            || Math.abs(bionicActColorPow - (1.0)) > 0.001
        bionicRefract = 4.0
        bionicEdgeLight = 1.4
        bionicSoftEdgePx = 1.5
        bionicHsvv = 1.0
        classicRefract = 1.5
        classicReflect = 0.06
        classicEdgeLight = 0.1
        classicSoftEdgePx = 1.5
        classicStrokeDegree = 24.0
        classicStrokeSize = 2.0
        classicReflLighten = 2.0
        bionicTransparency = 1.0
        bionicActDarken = 0.42
        bionicActEdgeLight = 3.0
        bionicActOpposite = 2.0
        bionicActHsvv = 1.6
        bionicActRefl = 1.3
        bionicActRefract = 4.6
        bionicLum0 = 0.67
        bionicLum1 = 0.16
        bionicLum2 = 0.09
        bionicLum3 = 0.0
        bionicLumAmount = 0.24
        bionicDarkBase = 0.3
        bionicDarkRange0 = 0.6
        bionicDarkRange1 = 1.0
        bionicBrightBase = -0.02
        bionicInnerBottom = 0.03
        bionicInnerWhite = 0.2
        bionicInnerMix = 0.3
        bionicColorPow = 1.0
        bionicAlphaLayer = 0.1
        bionicShapeEdgePow = 3.8
        bionicShapeThickness = 80.0
        bionicReflectOffset = 800.0
        bionicReflLighten = 1.2
        bionicReflStrength = 1.0
        bionicDirX = -0.4
        bionicDirY = 0.6
        bionicDirZ = -0.8
        bionicDirInt = 1.4
        bionicDirOpp = 0.7
        bionicDirAngle = 0.8
        bionicDirEdgePow = 1.15
        bionicBgSat = 2.0
        bionicBgBri = 0.0
        bionicActColorPow = 1.0
        if (changed) {
            saveTimer.restart()
            materialTuningSyncTimer.restart()
        }
        return changed
    }

    function _syncMaterialTuning() {
        let cmd = ""
        if (service.materialStyle === "bionic") {
            cmd = "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicIOR -- '" + service.bionicRefract + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirIntensity -- '" + service.bionicEdgeLight + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedDirOppositeIntensity -- '" + (service.bionicEdgeLight * 0.5) + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicShapeEdgePx -- '" + (service.bionicSoftEdgePx * 5.0) + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicHsvvBoost -- '" + service.bionicHsvv + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicOverallAlpha -- '" + service.bionicTransparency + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicLumValue0 '" + service.bionicLum0 + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicLumValue1 '" + service.bionicLum1 + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicLumValue2 '" + service.bionicLum2 + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicLumValue3 '" + service.bionicLum3 + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicLumAmount -- '" + service.bionicLumAmount + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDarker -- '" + service.bionicDarkBase + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDarkerRange0 '" + service.bionicDarkRange0 + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDarkerRange1 '" + service.bionicDarkRange1 + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicBrightness -- '" + service.bionicBrightBase + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicInnerBottom -- '" + service.bionicInnerBottom + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicInnerColorWhite -- '" + service.bionicInnerWhite + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicInnerColorMix -- '" + service.bionicInnerMix + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicColorPow -- '" + service.bionicColorPow + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicAlpha -- '" + service.bionicAlphaLayer + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicShapeEdgePow -- '" + service.bionicShapeEdgePow + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicShapeThicknessPx -- '" + service.bionicShapeThickness + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicShapeReflectOffsetPx -- '" + service.bionicReflectOffset + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicReflLighten -- '" + service.bionicReflLighten + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicReflStrength -- '" + service.bionicReflStrength + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirX -- '" + service.bionicDirX + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirY -- '" + service.bionicDirY + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirZ -- '" + service.bionicDirZ + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirIntensity -- '" + service.bionicDirInt + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirOppositeIntensity -- '" + service.bionicDirOpp + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirAngleRange -- '" + service.bionicDirAngle + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicDirEdgePow -- '" + service.bionicDirEdgePow + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicBgColorSaturation -- '" + service.bionicBgSat + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicBgColorBrightness -- '" + service.bionicBgBri + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedColorPow -- '" + service.bionicActColorPow + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedDarker -- '" + service.bionicActDarken + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedDirIntensity -- '" + service.bionicActEdgeLight + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedDirOppositeIntensity -- '" + service.bionicActOpposite + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedHsvvBoost -- '" + service.bionicActHsvv + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedReflStrength -- '" + service.bionicActRefl + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key BionicActivatedRefract -- '" + service.bionicActRefract + "'; "
        } else if (service.materialStyle === "classic") {
            cmd = "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicRefractIOR -- '" + service.classicRefract + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicReflStrength -- '" + service.classicReflect + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicStrokeStrength -- '" + service.classicEdgeLight + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicMaskSoft -- '" + service.classicSoftEdgePx + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicStrokeDegree -- '" + service.classicStrokeDegree + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicStrokeSize -- '" + service.classicStrokeSize + "'; "
                + "kwriteconfig6 --file kwinrc --group Effect-blurplus --key ClassicReflLighten -- '" + service.classicReflLighten + "'; "
        } else {
            return
        }
        cmd += "qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.reconfigureEffect glass 2>/dev/null || true"
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    // 材质微调专用（延迟稍长，避开 _applyKwinGlass 的并行写入）
    property Timer materialTuningSyncTimer: Timer {
        interval: 250
        repeat: false
        onTriggered: service._syncMaterialTuning()
    }

    function _materialGlassParams(style) {
        if (style === "bionic")
            return { blur: 12, refr: 14 }
        if (style === "classic")
            return { blur: 6, refr: 3 }
        return null
    }


    function updateShellStyle(rawStyle) {
        const style = String(rawStyle)
        if (!isValidShellStyle(style) || shellStyle === style)
            return false
        shellStyle = style
        saveTimer.restart()
        return true
    }

    function updateThemeMode(rawMode) {
        const mode = String(rawMode)
        if (!isValidThemeMode(mode) || themeMode === mode)
            return false
        themeMode = mode
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
            materialStyle: service.materialStyle,
            version: 10,
            globalBlurStrength: service.globalBlurStrength,
            globalLiquidStrength: service.globalLiquidStrength,
            blurStrength: service.globalBlurStrength,
            liquidStrength: service.globalLiquidStrength,
            shellStyle: service.shellStyle,
            themeMode: service.themeMode,
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
                    if (service.isValidShellStyle(style))
                        service.shellStyle = style
                    if (typeof object.materialStyle === "string"
                            && (object.materialStyle === "liquid" || object.materialStyle === "bionic"
                                || object.materialStyle === "classic"))
                        service.materialStyle = object.materialStyle
                    if (service.isValidThemeMode(themeMode))
                        service.themeMode = themeMode
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
                            || !service.isValidThemeMode(themeMode)
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
