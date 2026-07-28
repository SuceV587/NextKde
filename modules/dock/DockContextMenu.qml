import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// DockContextMenu — transient context menu for one DockIcon.
// It owns presentation only; actions are emitted to DockIcon, which delegates
// them to DockModelService. No menu state is persisted.

PopupWindow {
    id: menu

    property bool isWindow: false
    property bool isPinned: false
    property string appId: ""
    property string windowId: ""
    property Item anchorItem: null

    signal action(string name)

    readonly property var entries: {
        if (isWindow) {
            return [
                { name: "activate", label: "激活窗口", symbol: "\uf2d2" }, // window restore
                { name: "minimize", label: "最小化", symbol: "\uf2d1" }, // window minimize
                { name: "close", label: "关闭窗口", symbol: "\uf00d" }, // xmark
                isPinned
                    ? { name: "unpin", label: "取消固定", symbol: "\uf08d" }
                    : { name: "pin", label: "固定此应用", symbol: "\uf08d" },
            ]
        }
        if (!isPinned) {
            return [
                { name: "open", label: "打开", symbol: "\uf04b" }, // play
                { name: "pin", label: "固定此应用", symbol: "\uf08d" },
            ]
        }
        return [
            { name: "open", label: "打开", symbol: "\uf04b" },
            { name: "unpin", label: "取消固定", symbol: "\uf08d" },
        ]
    }

    // PopupWindow derives its size from implicit dimensions. Using width /
    // height here triggers a deprecation warning in newer Quickshell builds.
    implicitWidth: 170
    implicitHeight: 12 + entries.length * 34
    color: "transparent"
    grabFocus: true

    // The Dock is at the bottom of the screen, so open upward from the icon.
    // PopupWindow keeps this separate from the Dock's adaptive height.
    anchor {
        item: menu.anchorItem
        // `edges` selects the point on the icon; `gravity` is the direction
        // in which the popup expands. Both must be Top: Top + Bottom expands
        // downward from the icon top, which is why the menu previously sat
        // level with the icon instead of above it.
        edges: Edges.Top
        gravity: Edges.Top
        // A negative top margin moves the anchor point above the icon,
        // creating an 8px visual gap without changing Dock layout geometry.
        margins.top: -8

    }

    LiquidGlassSurface {
        id: background
        anchors.fill: parent
        radius: 12
        // The base Dock tint is intentionally only 10% opaque. A popup needs
        // a thicker material layer or the compositor blur remains invisible
        // against busy wallpaper. BackgroundEffect below supplies the actual
        // Gaussian backdrop blur; this tint makes that blur legible.
        baseColor: ThemeService.isDark
            ? Qt.rgba(0.04, 0.05, 0.07, 0.72)
            : Qt.rgba(0.94, 0.95, 0.98, 0.68)
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
                    color: menuItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                    Text {
                        width: 16
                        height: 16
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: modelData.symbol ?? ""
                        color: ThemeService.foregroundColor
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
                        color: ThemeService.foregroundColor
                        font {
                            family: "SF Pro Display"
                            pixelSize: 13
                            weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: menuItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: function(mouse) {
                            // Dismiss this grab surface before dispatching the
                            // action. That prevents the stale popup from
                            // retaining input while the Dock model reflows.
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
