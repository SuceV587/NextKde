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
            return JSON.stringify({
                baseHeight: ConfigService.baseHeight,
                theme: theme,
                position: position,
                autoHide: ConfigService.autoHide,
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

        function updateAutoHide(value: bool): string {
            ConfigService.updateAutoHide(value)
            return snapshot()
        }

        function updateTheme(theme: string): string {
            ConfigService.updateTheme(theme)
            return snapshot()
        }
    }

    QuickSearch {
        id: quickSearch
    }
    AppLauncher {}
    NotificationCenter {}
    DeskCenter {}
    Bar {}
    Dock {}
}
