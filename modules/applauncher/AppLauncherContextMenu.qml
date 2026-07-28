import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// Context menu for one root-grid application. It contains presentation only;
// AppLauncherWindow owns actions and routes Dock requests through the launcher
// service contract instead of importing Dock internals.
PopupWindow {
    id: menu

    property var application: null
    property Item anchorItem: null
    signal action(string name)

    readonly property var entries: [
        { name: "open", label: "打开应用", symbol: "\uf04b" },
        { name: "edit", label: "编辑应用", symbol: "\uf304" },
        { name: "pin", label: "固定到 Dock", symbol: "\uf08d" },
    ]

    visible: false
    implicitWidth: 174
    implicitHeight: 12 + entries.length * 34
    color: "transparent"
    grabFocus: true

    anchor {
        item: menu.anchorItem
        // Launcher icons are in the lower half of the output; opening upward
        // keeps the menu inside the launcher instead of below the surface.
        edges: Edges.Top
        gravity: Edges.Top
        margins.top: -6
    }

    LiquidGlassSurface {
        id: background
        anchors.fill: parent
        radius: 12
        baseColor: Qt.rgba(0.08, 0.09, 0.12, 0.76)
        surfaceOpacity: 0.96
        materialDepth: 2.5

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: menu.entries
                delegate: Rectangle {
                    required property var modelData
                    width: menu.width - 12
                    height: 30
                    radius: 7
                    color: itemMouse.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                    Text {
                        width: 16
                        height: 16
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: modelData.symbol
                        color: AppLauncherService.dockForegroundColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font {
                            family: "Font Awesome 7 Free"
                            pixelSize: 13
                            weight: Font.Black
                        }
                        opacity: 0.84
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 36
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.label
                        color: AppLauncherService.dockForegroundColor
                        font {
                            family: "SF Pro Display"
                            pixelSize: 13
                            weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            menu.visible = false
                            menu.action(modelData.name)
                        }
                    }
                }
            }
        }
    }

    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: background
        radius: background.radius
    }
}
