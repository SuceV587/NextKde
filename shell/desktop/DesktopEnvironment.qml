import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.bar
import qs.desktop.modules.dock
import qs.desktop.modules.quicksearch
import qs.desktop.modules.notifications
import qs.desktop.modules.applauncher
import qs.desktop.modules.deskcenter
import qs.desktop.modules.overview
import qs.desktop.modules.common
import qs.desktop.modules.platform
import qs.desktop.modules.shortcuts

Item {
    id: shell

    readonly property bool barIntegratedWithDock:
        AppearanceConfigService.barIntegratedWithDock

    Component {
        id: integratedBarStatus
        BarStatusArea {
            dockHosted: true
            dockEdge: ConfigService.position
        }
    }

    // Theme watching is non-visual and only loads a tiny FileView. The
    // AppLauncher and its icon grid remain lazy.
    //
    // ShortcutsService is a QML singleton, so it only instantiates on first
    // access — and nothing else touches it during startup. Touch it here so
    // the global shortcuts are registered on every Shell start (self-heal);
    // the request queues until the platform daemon connects.
    Component.onCompleted: {
        IconThemeReloadService.initialize()
        ShortcutsService.applyToPlatform()
        if (shell.barIntegratedWithDock)
            WorkspaceLayoutService.clearBar(ScreenLifecycle.activeScreen)
    }

    onBarIntegratedWithDockChanged: {
        if (shell.barIntegratedWithDock)
            WorkspaceLayoutService.clearBar(ScreenLifecycle.activeScreen)
    }

    // The standalone Settings app is intentionally not allowed to import a
    // desktop module. This narrow IPC endpoint is its only Dock write path.
    IpcHandler {
        target: "dock-settings"

        function snapshot(): string {
            const theme = ConfigService.isValidTheme(ConfigService.theme)
                ? ConfigService.theme : "dark"
            const position = ConfigService.isValidPosition(ConfigService.position)
                ? ConfigService.position : "bottom"
            const iconMode = ConfigService.isValidIconMode(ConfigService.iconMode)
                ? ConfigService.iconMode : "color"
            const visibilityMode = ConfigService.isValidVisibilityMode(ConfigService.visibilityMode)
                ? ConfigService.visibilityMode : "always"
            const windowGrouping = ConfigService.isValidWindowGrouping(ConfigService.windowGrouping)
                ? ConfigService.windowGrouping : "grouped"
            return JSON.stringify({
                baseHeight: ConfigService.baseHeight,
                theme: theme,
                position: position,
                iconMode: iconMode,
                iconOpacity: ConfigService.iconOpacity,
                iconTintColor: ConfigService.iconTintColor,
                visibilityMode,
                windowGrouping,
            })
        }

        function updateLayout(height: real): string {
            ConfigService.updateLayout(height)
            return snapshot()
        }

        function updatePosition(newPosition: string): string {
            ConfigService.updatePosition(newPosition)
            return snapshot()
        }

        function updateTheme(theme: string): string {
            ConfigService.updateTheme(theme)
            return snapshot()
        }

        function updateIconMode(mode: string): string {
            ConfigService.updateIconMode(mode)
            return snapshot()
        }

        function updateIconOpacity(opacity: real): string {
            ConfigService.updateIconOpacity(opacity)
            return snapshot()
        }

        function updateIconTintColor(color: string): string {
            ConfigService.updateIconTintColor(color)
            return snapshot()
        }

        function updateVisibilityMode(mode: string): string {
            ConfigService.updateVisibilityMode(mode)
            return snapshot()
        }

        function updateWindowGrouping(mode: string): string {
            ConfigService.updateWindowGrouping(mode)
            return snapshot()
        }

    }

    // Shell-wide appearance controls used by the standalone Settings app.
    // Blur/liquid values are synchronized only with the custom Glass effect,
    // never KDE's stock blur effect. shellStyle selects semantic shape tokens.
    IpcHandler {
        target: "appearance-settings"

        function snapshot(): string {
            return JSON.stringify({
                globalBlurStrength: AppearanceConfigService.globalBlurStrength,
                globalLiquidStrength: AppearanceConfigService.globalLiquidStrength,
                effectiveDockBlur: AppearanceConfigService.effectiveDockBlur,
                effectiveDockLiquid: AppearanceConfigService.effectiveDockLiquid,
                effectiveBarBlur: AppearanceConfigService.effectiveBarBlur,
                effectiveBarLiquid: AppearanceConfigService.effectiveBarLiquid,
                effectiveLauncherBlur:
                    AppearanceConfigService.effectiveLauncherBlur,
                effectiveLauncherLiquid:
                    AppearanceConfigService.effectiveLauncherLiquid,
                blurStrength: AppearanceConfigService.globalBlurStrength,
                liquidStrength: AppearanceConfigService.globalLiquidStrength,
                iconMode: IconAppearanceService.mode,
                iconOpacity: IconAppearanceService.opacity,
                // JSON has no QColor primitive. Send the canonical #rrggbb
                // form so the standalone Settings C++ bridge does not parse
                // the value as an object and fall back to its previous tint.
                iconTintColor: IconAppearanceService.tintColor.toString(),
                shellStyle: AppearanceConfigService.shellStyle,
                materialStyle: AppearanceConfigService.materialStyle,
                barIntegratedWithDock:
                    AppearanceConfigService.barIntegratedWithDock,
                barVisibilityMode: AppearanceConfigService.barVisibilityMode,
                barLayoutMode: AppearanceConfigService.barLayoutMode,
                dockWindowAnimationStyle:
                    AppearanceConfigService.dockWindowAnimationStyle,
                // Dock surface tuning (DDE-derived). The Dock resolves these
                // against the active shell style; the Settings app round-trips
                // the raw multipliers so its sliders stay where the user left
                // them instead of snapping to a recomputed absolute.
                bionicRefract: AppearanceConfigService.bionicRefract,
                bionicEdgeLight: AppearanceConfigService.bionicEdgeLight,
                bionicSoftEdgePx: AppearanceConfigService.bionicSoftEdgePx,
                bionicHsvv: AppearanceConfigService.bionicHsvv,
                classicRefract: AppearanceConfigService.classicRefract,
                classicReflect: AppearanceConfigService.classicReflect,
                classicEdgeLight: AppearanceConfigService.classicEdgeLight,
                classicSoftEdgePx: AppearanceConfigService.classicSoftEdgePx,
                classicStrokeDegree: AppearanceConfigService.classicStrokeDegree,
                classicStrokeSize: AppearanceConfigService.classicStrokeSize,
                classicReflLighten: AppearanceConfigService.classicReflLighten,
                bionicRefractMin: AppearanceConfigService.bionicRefractMin,
                bionicRefractMax: AppearanceConfigService.bionicRefractMax,
                bionicEdgeLightMin: AppearanceConfigService.bionicEdgeLightMin,
                bionicEdgeLightMax: AppearanceConfigService.bionicEdgeLightMax,
                bionicSoftEdgePxMin: AppearanceConfigService.bionicSoftEdgePxMin,
                bionicSoftEdgePxMax: AppearanceConfigService.bionicSoftEdgePxMax,
                bionicHsvvMin: AppearanceConfigService.bionicHsvvMin,
                bionicHsvvMax: AppearanceConfigService.bionicHsvvMax,
                classicRefractMin: AppearanceConfigService.classicRefractMin,
                classicRefractMax: AppearanceConfigService.classicRefractMax,
                classicReflectMin: AppearanceConfigService.classicReflectMin,
                classicReflectMax: AppearanceConfigService.classicReflectMax,
                classicEdgeLightMin: AppearanceConfigService.classicEdgeLightMin,
                classicEdgeLightMax: AppearanceConfigService.classicEdgeLightMax,
                classicSoftEdgePxMin: AppearanceConfigService.classicSoftEdgePxMin,
                classicSoftEdgePxMax: AppearanceConfigService.classicSoftEdgePxMax,
                bionicTransparency: AppearanceConfigService.bionicTransparency,
                bionicActDarken: AppearanceConfigService.bionicActDarken,
                bionicActEdgeLight: AppearanceConfigService.bionicActEdgeLight,
                bionicActOpposite: AppearanceConfigService.bionicActOpposite,
                bionicActHsvv: AppearanceConfigService.bionicActHsvv,
                bionicActRefl: AppearanceConfigService.bionicActRefl,
                bionicActRefract: AppearanceConfigService.bionicActRefract,
                bionicLum0: AppearanceConfigService.bionicLum0,
                bionicLum1: AppearanceConfigService.bionicLum1,
                bionicLum2: AppearanceConfigService.bionicLum2,
                bionicLum3: AppearanceConfigService.bionicLum3,
                bionicLumAmount: AppearanceConfigService.bionicLumAmount,
                bionicDarkBase: AppearanceConfigService.bionicDarkBase,
                bionicDarkRange0: AppearanceConfigService.bionicDarkRange0,
                bionicDarkRange1: AppearanceConfigService.bionicDarkRange1,
                bionicBrightBase: AppearanceConfigService.bionicBrightBase,
                bionicInnerBottom: AppearanceConfigService.bionicInnerBottom,
                bionicInnerWhite: AppearanceConfigService.bionicInnerWhite,
                bionicInnerMix: AppearanceConfigService.bionicInnerMix,
                bionicColorPow: AppearanceConfigService.bionicColorPow,
                bionicAlphaLayer: AppearanceConfigService.bionicAlphaLayer,
                bionicShapeEdgePow: AppearanceConfigService.bionicShapeEdgePow,
                bionicShapeThickness: AppearanceConfigService.bionicShapeThickness,
                bionicReflectOffset: AppearanceConfigService.bionicReflectOffset,
                bionicReflLighten: AppearanceConfigService.bionicReflLighten,
                bionicReflStrength: AppearanceConfigService.bionicReflStrength,
                bionicDirX: AppearanceConfigService.bionicDirX,
                bionicDirY: AppearanceConfigService.bionicDirY,
                bionicDirZ: AppearanceConfigService.bionicDirZ,
                bionicDirInt: AppearanceConfigService.bionicDirInt,
                bionicDirOpp: AppearanceConfigService.bionicDirOpp,
                bionicDirAngle: AppearanceConfigService.bionicDirAngle,
                bionicDirEdgePow: AppearanceConfigService.bionicDirEdgePow,
                bionicBgSat: AppearanceConfigService.bionicBgSat,
                bionicBgBri: AppearanceConfigService.bionicBgBri,
                bionicActColorPow: AppearanceConfigService.bionicActColorPow,
                bionicTransparencyMin: AppearanceConfigService.bionicTransparencyMin,
                bionicTransparencyMax: AppearanceConfigService.bionicTransparencyMax,
                // What the tuning currently resolves to, so Settings can show
                // the user a concrete pixel/alpha readout rather than the
                // opaque multiplier alone.
                resolvedDockRadius: AppearanceTokens.resolvedDockRadius,
                resolvedDockDarkAlpha: AppearanceTokens.resolvedDockDarkAlpha,
                resolvedDockBorderTopAlpha:
                    AppearanceTokens.resolvedDockBorderTopAlpha,
                resolvedDockBorderBottomAlpha:
                    AppearanceTokens.resolvedDockBorderBottomAlpha,
                tokenVersion: AppearanceTokens.version,
            })
        }

        function updateGlobalBlurStrength(value: real): string {
            AppearanceConfigService.updateGlobalBlurStrength(value)
            return snapshot()
        }

        function updateGlobalLiquidStrength(value: real): string {
            AppearanceConfigService.updateGlobalLiquidStrength(value)
            return snapshot()
        }

        function updateGlobalIconMode(mode: string): string {
            IconAppearanceService.updateMode(mode)
            return snapshot()
        }

        function updateGlobalIconOpacity(opacity: real): string {
            IconAppearanceService.updateOpacity(opacity)
            return snapshot()
        }

        function updateGlobalIconTintColor(color: string): string {
            IconAppearanceService.updateTintColor(color)
            return snapshot()
        }

        function updateBlurStrength(value: real): string {
            AppearanceConfigService.updateGlobalBlurStrength(value)
            return snapshot()
        }

        function updateLiquidStrength(value: real): string {
            AppearanceConfigService.updateGlobalLiquidStrength(value)
            return snapshot()
        }

        function updateShellStyle(style: string): string {
            AppearanceConfigService.updateShellStyle(style)
            return snapshot()
        }

        function updateMaterialStyle(style: string): string {
            AppearanceConfigService.updateMaterialStyle(style)
            return snapshot()
        }

        function updateBarIntegratedWithDock(enabled: bool): string {
            AppearanceConfigService.updateBarIntegratedWithDock(enabled)
            return snapshot()
        }

        function updateBarVisibilityMode(mode: string): string {
            AppearanceConfigService.updateBarVisibilityMode(mode)
            return snapshot()
        }

        function updateBarLayoutMode(mode: string): string {
            AppearanceConfigService.updateBarLayoutMode(mode)
            return snapshot()
        }

        function updateDockWindowAnimationStyle(style: string): string {
            AppearanceConfigService.updateDockWindowAnimationStyle(style)
            return snapshot()
        }

        function updateDockRadiusScale(value: real): string {
            AppearanceConfigService.updateDockRadiusScale(value)
            return snapshot()
        }

        function updateDockDarkDensity(value: real): string {
            AppearanceConfigService.updateDockDarkDensity(value)
            return snapshot()
        }

        function updateDockEdgeStrength(value: real): string {
            AppearanceConfigService.updateDockEdgeStrength(value)
            return snapshot()
        }

        function updateBionicRefract(value: real): string {
            AppearanceConfigService.updateBionicRefract(value)
            return snapshot()
        }

        function updateBionicEdgeLight(value: real): string {
            AppearanceConfigService.updateBionicEdgeLight(value)
            return snapshot()
        }

        function updateBionicSoftEdgePx(value: real): string {
            AppearanceConfigService.updateBionicSoftEdgePx(value)
            return snapshot()
        }

        function updateBionicHsvv(value: real): string {
            AppearanceConfigService.updateBionicHsvv(value)
            return snapshot()
        }

        function updateClassicRefract(value: real): string {
            AppearanceConfigService.updateClassicRefract(value)
            return snapshot()
        }

        function updateClassicReflect(value: real): string {
            AppearanceConfigService.updateClassicReflect(value)
            return snapshot()
        }

        function updateClassicEdgeLight(value: real): string {
            AppearanceConfigService.updateClassicEdgeLight(value)
            return snapshot()
        }

        function updateClassicSoftEdgePx(value: real): string {
            AppearanceConfigService.updateClassicSoftEdgePx(value)
            return snapshot()
        }

        function updateClassicStrokeDegree(value: real): string {
            AppearanceConfigService.updateClassicStrokeDegree(value)
            return snapshot()
        }

        function updateClassicStrokeSize(value: real): string {
            AppearanceConfigService.updateClassicStrokeSize(value)
            return snapshot()
        }

        function updateClassicReflLighten(value: real): string {
            AppearanceConfigService.updateClassicReflLighten(value)
            return snapshot()
        }

        function updateBionicTransparency(value: real): string {
            AppearanceConfigService.updateBionicTransparency(value)
            return snapshot()
        }

        function updateBionicActDarken(value: real): string {
            AppearanceConfigService.updateBionicActDarken(value)
            return snapshot()
        }

        function updateBionicActEdgeLight(value: real): string {
            AppearanceConfigService.updateBionicActEdgeLight(value)
            return snapshot()
        }

        function updateBionicActOpposite(value: real): string {
            AppearanceConfigService.updateBionicActOpposite(value)
            return snapshot()
        }

        function updateBionicActHsvv(value: real): string {
            AppearanceConfigService.updateBionicActHsvv(value)
            return snapshot()
        }

        function updateBionicActRefl(value: real): string {
            AppearanceConfigService.updateBionicActRefl(value)
            return snapshot()
        }

        function updateBionicActRefract(value: real): string {
            AppearanceConfigService.updateBionicActRefract(value)
            return snapshot()
        }

        function updateBionicLum0(value: real): string {
            AppearanceConfigService.updateBionicLum0(value)
            return snapshot()
        }

        function updateBionicLum1(value: real): string {
            AppearanceConfigService.updateBionicLum1(value)
            return snapshot()
        }

        function updateBionicLum2(value: real): string {
            AppearanceConfigService.updateBionicLum2(value)
            return snapshot()
        }

        function updateBionicLum3(value: real): string {
            AppearanceConfigService.updateBionicLum3(value)
            return snapshot()
        }

        function updateBionicLumAmount(value: real): string {
            AppearanceConfigService.updateBionicLumAmount(value)
            return snapshot()
        }

        function updateBionicDarkBase(value: real): string {
            AppearanceConfigService.updateBionicDarkBase(value)
            return snapshot()
        }

        function updateBionicDarkRange0(value: real): string {
            AppearanceConfigService.updateBionicDarkRange0(value)
            return snapshot()
        }

        function updateBionicDarkRange1(value: real): string {
            AppearanceConfigService.updateBionicDarkRange1(value)
            return snapshot()
        }

        function updateBionicBrightBase(value: real): string {
            AppearanceConfigService.updateBionicBrightBase(value)
            return snapshot()
        }

        function updateBionicInnerBottom(value: real): string {
            AppearanceConfigService.updateBionicInnerBottom(value)
            return snapshot()
        }

        function updateBionicInnerWhite(value: real): string {
            AppearanceConfigService.updateBionicInnerWhite(value)
            return snapshot()
        }

        function updateBionicInnerMix(value: real): string {
            AppearanceConfigService.updateBionicInnerMix(value)
            return snapshot()
        }

        function updateBionicColorPow(value: real): string {
            AppearanceConfigService.updateBionicColorPow(value)
            return snapshot()
        }

        function updateBionicAlphaLayer(value: real): string {
            AppearanceConfigService.updateBionicAlphaLayer(value)
            return snapshot()
        }

        function updateBionicShapeEdgePow(value: real): string {
            AppearanceConfigService.updateBionicShapeEdgePow(value)
            return snapshot()
        }

        function updateBionicShapeThickness(value: real): string {
            AppearanceConfigService.updateBionicShapeThickness(value)
            return snapshot()
        }

        function updateBionicReflectOffset(value: real): string {
            AppearanceConfigService.updateBionicReflectOffset(value)
            return snapshot()
        }

        function updateBionicReflLighten(value: real): string {
            AppearanceConfigService.updateBionicReflLighten(value)
            return snapshot()
        }

        function updateBionicReflStrength(value: real): string {
            AppearanceConfigService.updateBionicReflStrength(value)
            return snapshot()
        }

        function updateBionicDirX(value: real): string {
            AppearanceConfigService.updateBionicDirX(value)
            return snapshot()
        }

        function updateBionicDirY(value: real): string {
            AppearanceConfigService.updateBionicDirY(value)
            return snapshot()
        }

        function updateBionicDirZ(value: real): string {
            AppearanceConfigService.updateBionicDirZ(value)
            return snapshot()
        }

        function updateBionicDirInt(value: real): string {
            AppearanceConfigService.updateBionicDirInt(value)
            return snapshot()
        }

        function updateBionicDirOpp(value: real): string {
            AppearanceConfigService.updateBionicDirOpp(value)
            return snapshot()
        }

        function updateBionicDirAngle(value: real): string {
            AppearanceConfigService.updateBionicDirAngle(value)
            return snapshot()
        }

        function updateBionicDirEdgePow(value: real): string {
            AppearanceConfigService.updateBionicDirEdgePow(value)
            return snapshot()
        }

        function updateBionicBgSat(value: real): string {
            AppearanceConfigService.updateBionicBgSat(value)
            return snapshot()
        }

        function updateBionicBgBri(value: real): string {
            AppearanceConfigService.updateBionicBgBri(value)
            return snapshot()
        }

        function updateBionicActColorPow(value: real): string {
            AppearanceConfigService.updateBionicActColorPow(value)
            return snapshot()
        }


        function resetMaterialTuning(): string {
            AppearanceConfigService.resetMaterialTuning()
            return snapshot()
        }

        function resetDockSurfaceTuning(): string {
            AppearanceConfigService.resetDockSurfaceTuning()
            return snapshot()
        }

        // The standalone Settings app talks to this narrow Shell endpoint;
        // only the resident platform daemon performs KDE theme operations.
        function applySystemAppearance(dark: bool): string {
            PlatformClient.request("theme.apply-system", { dark: dark },
                function(response) {
                    if (!response?.ok)
                        console.warn("[Appearance] system theme failed: "
                            + (response?.error?.message || "platform unavailable"))
                })
            return JSON.stringify({ accepted: true })
        }

        function resetStrengths(): string {
            AppearanceConfigService.resetStrengths()
            return snapshot()
        }
    }

    // AppLauncher settings endpoint for standalone Settings app and IPC clients.
    IpcHandler {
        target: "applauncher-settings"

        function snapshot(): string {
            return JSON.stringify({
                displayMode: AppLauncherConfigService.displayMode,
                layoutProfiles: AppLauncherConfigService.layoutProfiles,
            })
        }

        function updateDisplayMode(mode: string): string {
            AppLauncherConfigService.updateDisplayMode(mode)
            return snapshot()
        }

        function updateProfileIconSize(mode: string, size: string): string {
            AppLauncherConfigService.updateProfileIconSize(mode, size)
            return snapshot()
        }

        function updateProfileDensity(mode: string, density: string): string {
            AppLauncherConfigService.updateProfileDensity(mode, density)
            return snapshot()
        }

        function updateProfileFontWeight(mode: string, weight: string): string {
            AppLauncherConfigService.updateProfileFontWeight(mode, weight)
            return snapshot()
        }

        function resetProfile(mode: string): string {
            AppLauncherConfigService.resetProfile(mode)
            return snapshot()
        }
    }

    // Global-shortcut endpoint for the standalone Settings app. ShortcutsService
    // owns defaults, overrides, and the kglobalaccel handoff; this handler is
    // the only write path the Settings app gets, matching the other targets.
    IpcHandler {
        target: "shortcuts-settings"

        function snapshot(): string {
            return JSON.stringify(ShortcutsService.snapshot())
        }

        function updateShortcut(id: string, combo: string): string {
            return JSON.stringify(ShortcutsService.updateShortcut(id, combo))
        }

        function resetShortcut(id: string): string {
            return JSON.stringify(ShortcutsService.resetShortcut(id))
        }
    }

    // Read-only health snapshot for the standalone Settings app. Keep these
    // values sourced from the live Shell connections so the UI reports what
    // is actually connected, not merely which units were installed.
    IpcHandler {
        target: "integration-status"

        function snapshot(): string {
            return JSON.stringify({
                shellReady: true,
                platformConnected: PlatformClient.socket.connected,
                dataConnected: DataClient.socket.connected,
                outputAvailable: ScreenLifecycle.outputAvailable,
                desktopWidgetsVisible: ScreenLifecycle.outputAvailable
                    && ScreenLifecycle.activeScreen !== null,
                desktopFilesReady: DesktopFilesService.ready,
            })
        }
    }

    // The KWin effect observes pointer presses at compositor scope and routes
    // them through WindowService's existing local bridge. Keep the policy here
    // so individual desktop, Dock, and tray surfaces need no outside-click
    // listeners.
    Connections {
        target: WindowService
        function onGlobalPointerPressed(x, y, button, timestamp) {
            ContextMenuCoordinator.dismissForGlobalPointerPress(x, y, timestamp)
        }
    }

    QuickSearch {
        id: quickSearch
    }
    AppLauncher {}
    Overview {}
    IpcHandler {
        target: "desktop"
        function toggle(): void { WindowService.toggleShowDesktop() }
        function show(): void { WindowService.toggleShowDesktop() }
    }
    NotificationCenter {}
    DeskCenter {}
    // Do not briefly map the standalone Bar with the default setting and then
    // hide it while its tray delegates are still being constructed. Qt 6.11
    // can crash while cleaning that incomplete QQuickWindow scene. Wait for
    // the persisted integration choice before making the Bar visible.
    Bar {
        enabled: AppearanceConfigService.ready
            && !shell.barIntegratedWithDock
    }
    Dock {
        clockInInfoCarousel: shell.barIntegratedWithDock
            && ConfigService.position === "bottom"
        trailingAccessory: shell.barIntegratedWithDock
            ? integratedBarStatus : null
    }
}
