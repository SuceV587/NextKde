import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    id: shell

    property var primaryScreen: Quickshell.screens[1] ?? null

    PanelWindow {
        id: panel
        anchors {
            left: true
            bottom: true
            right: true
        }
        implicitHeight: 70
        height: implicitHeight
        color: "transparent"
        screen: shell.primaryScreen

        // ── Pure shader glass (no screencopy needed) ──
        Rectangle {
            width: 1500
            height: 60
            anchors.centerIn: parent
            opacity: 0.3
            color: "#000000"
            radius: 25
            border.color: "#fff"
            border.width: 0
        }
    }
}
