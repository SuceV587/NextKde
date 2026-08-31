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
                blurStrength: AppearanceConfigService.blurStrength,
                liquidStrength: AppearanceConfigService.liquidStrength,
                shellStyle: AppearanceConfigService.shellStyle,
                barIntegratedWithDock:
                    AppearanceConfigService.barIntegratedWithDock,
                dockWindowAnimationStyle:
                    AppearanceConfigService.dockWindowAnimationStyle,
                tokenVersion: AppearanceTokens.version,
            })
        }

        function updateBlurStrength(value: real): string {
            AppearanceConfigService.updateBlurStrength(value)
            return snapshot()
        }

        function updateLiquidStrength(value: real): string {
            AppearanceConfigService.updateLiquidStrength(value)
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

        function updateDockWindowAnimationStyle(style: string): string {
            AppearanceConfigService.updateDockWindowAnimationStyle(style)
            return snapshot()
        }

        function resetStrengths(): string {
            AppearanceConfigService.resetStrengths()
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
    NotificationCenter {}
    DeskCenter {}
    Bar { enabled: !shell.barIntegratedWithDock }
    Dock {
        clockInInfoCarousel: shell.barIntegratedWithDock
            && ConfigService.position === "bottom"
        trailingAccessory: shell.barIntegratedWithDock
            ? integratedBarStatus : null
    }
}
