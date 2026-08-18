//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.bar
import qs.desktop.modules.dock
import qs.desktop.modules.quicksearch
import qs.desktop.modules.notifications
import qs.desktop.modules.applauncher
import qs.desktop.modules.deskcenter
import qs.desktop.modules.overview

ShellRoot {
    id: shell

    // ── Shared screen reference (readonly, for initial sizing) ──
    property var primaryScreen: Quickshell.screens[1] ?? Quickshell.screens[0] ?? null
    property size primaryScreenSize: primaryScreen ? Qt.size(primaryScreen.width, primaryScreen.height) : Qt.size(1920, 1080)

    QuickSearch {
        id: quickSearch
    }
    AppLauncher {}
    NotificationCenter {}
    DeskCenter {}
    Bar {}
    Dock {}
    Overview {}
}
