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

    Component {
        id: integratedSideClock
        SideDockClockStatus {}
    }

    // Theme watching is non-visual and only loads a tiny FileView. The
    // AppLauncher and its icon grid remain lazy.
    Component.onCompleted: IconThemeReloadService.initialize()

    // The standalone Settings app is intentionally not allowed to import a
    // desktop module. This narrow IPC endpoint is its only Dock write path.
    IpcHandler {
        target: "dock-settings"

        property real dockHeight: ConfigService.baseHeight
        property string dockTheme: ConfigService.theme

        function snapshot(): string {
            const theme = ConfigService.isValidTheme(ConfigService.theme)
                ? ConfigService.theme : "dark"
            const position = ConfigService.isValidPosition(ConfigService.position)
                ? ConfigService.position : "bottom"
            const iconMode = ConfigService.isValidIconMode(ConfigService.iconMode)
                ? ConfigService.iconMode : "color"
            const visibilityMode = ConfigService.isValidVisibilityMode(ConfigService.visibilityMode)
                ? ConfigService.visibilityMode : "always"
            return JSON.stringify({
                baseHeight: ConfigService.baseHeight,
                theme: theme,
                position: position,
                iconMode: iconMode,
                iconOpacity: ConfigService.iconOpacity,
                iconTintColor: ConfigService.iconTintColor,
                visibilityMode,
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
                dockBlurInherit: AppearanceConfigService.dockBlurInherit,
                dockBlurStrength: AppearanceConfigService.dockBlurStrength,
                dockLiquidStrength: AppearanceConfigService.dockLiquidStrength,
                barBlurInherit: AppearanceConfigService.barBlurInherit,
                barBlurStrength: AppearanceConfigService.barBlurStrength,
                barLiquidStrength: AppearanceConfigService.barLiquidStrength,
                launcherBlurInherit:
                    AppearanceConfigService.launcherBlurInherit,
                launcherBlurStrength:
                    AppearanceConfigService.launcherBlurStrength,
                launcherLiquidStrength:
                    AppearanceConfigService.launcherLiquidStrength,
                effectiveDockBlur: AppearanceConfigService.effectiveDockBlur,
                effectiveDockLiquid: AppearanceConfigService.effectiveDockLiquid,
                effectiveBarBlur: AppearanceConfigService.effectiveBarBlur,
                effectiveBarLiquid: AppearanceConfigService.effectiveBarLiquid,
                effectiveLauncherBlur:
                    AppearanceConfigService.effectiveLauncherBlur,
                effectiveLauncherLiquid:
                    AppearanceConfigService.effectiveLauncherLiquid,
                // Backward compatibility aliases
                barBlurInheritDock: AppearanceConfigService.barBlurInherit,
                launcherBlurInheritDock: AppearanceConfigService.launcherBlurInherit,
                blurStrength: AppearanceConfigService.globalBlurStrength,
                liquidStrength: AppearanceConfigService.globalLiquidStrength,
                shellStyle: AppearanceConfigService.shellStyle,
                barIntegratedWithDock:
                    AppearanceConfigService.barIntegratedWithDock,
                barVisibilityMode: AppearanceConfigService.barVisibilityMode,
                barLayoutMode: AppearanceConfigService.barLayoutMode,
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

        function updateDockBlurInherit(enabled: bool): string {
            AppearanceConfigService.updateDockBlurInherit(enabled)
            return snapshot()
        }

        function updateDockBlurStrength(value: real): string {
            AppearanceConfigService.updateDockBlurStrength(value)
            return snapshot()
        }

        function updateDockLiquidStrength(value: real): string {
            AppearanceConfigService.updateDockLiquidStrength(value)
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

        function updateBarBlurInherit(enabled: bool): string {
            AppearanceConfigService.updateBarBlurInherit(enabled)
            return snapshot()
        }

        function updateBarBlurStrength(value: real): string {
            AppearanceConfigService.updateBarBlurStrength(value)
            return snapshot()
        }

        function updateBarLiquidStrength(value: real): string {
            AppearanceConfigService.updateBarLiquidStrength(value)
            return snapshot()
        }

        function updateLauncherBlurInherit(enabled: bool): string {
            AppearanceConfigService.updateLauncherBlurInherit(enabled)
            return snapshot()
        }

        function updateLauncherBlurStrength(value: real): string {
            AppearanceConfigService.updateLauncherBlurStrength(value)
            return snapshot()
        }

        function updateLauncherLiquidStrength(value: real): string {
            AppearanceConfigService.updateLauncherLiquidStrength(value)
            return snapshot()
        }

        function updateShellStyle(style: string): string {
            AppearanceConfigService.updateShellStyle(style)
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
                iconSize: AppLauncherConfigService.iconSize,
                iconSpacing: AppLauncherConfigService.iconSpacing,
                fontSize: AppLauncherConfigService.fontSize,
                fontWeight: AppLauncherConfigService.fontWeight,
            })
        }

        function updateDisplayMode(mode: string): string {
            AppLauncherConfigService.updateDisplayMode(mode)
            return snapshot()
        }

        function updateIconSize(size: real): string {
            AppLauncherConfigService.updateIconSize(size)
            return snapshot()
        }

        function updateIconSpacing(spacing: real): string {
            AppLauncherConfigService.updateIconSpacing(spacing)
            return snapshot()
        }

        function updateFontSize(size: real): string {
            AppLauncherConfigService.updateFontSize(size)
            return snapshot()
        }

        function updateFontWeight(weight: string): string {
            AppLauncherConfigService.updateFontWeight(weight)
            return snapshot()
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
    Bar { enabled: !shell.barIntegratedWithDock }
    Dock {
        clockInInfoCarousel: shell.barIntegratedWithDock
            && ConfigService.position === "bottom"
        leadingAccessory: shell.barIntegratedWithDock
            && ConfigService.position !== "bottom"
            ? integratedSideClock : null
        trailingAccessory: shell.barIntegratedWithDock
            ? integratedBarStatus : null
    }
}
