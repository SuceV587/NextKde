//@ pragma UseQApplication
import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.bar
import qs.modules.dock
import qs.modules.quicksearch
import qs.modules.notifications
import qs.modules.applauncher
import qs.modules.deskcenter

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
}
