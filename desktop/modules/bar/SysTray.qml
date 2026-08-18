import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick

// StatusNotifierItem host. Referencing SystemTray claims and tracks tray items.
Item {
    id: root

    property int iconSize: 16
    property int iconSpacing: 6
    // Visual-only adjustment; transforms preserve the item's input region
    // and the menu anchor follows the transformed icon position.
    property int visualYOffset: 0
    readonly property int itemSize: iconSize + 4

    implicitWidth: trayRow.width
    implicitHeight: itemSize
    width: implicitWidth
    height: implicitHeight
    transform: Translate { y: root.visualYOffset }

    Row {
        id: trayRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.iconSpacing

        Repeater {
            model: SystemTray.items

            delegate: Item {
                id: trayItem
                required property var modelData
                width: root.itemSize
                height: root.itemSize
                readonly property string tooltip: modelData.tooltipTitle
                    || modelData.title || modelData.id

                function openMenu() {
                    if (modelData.hasMenu)
                        trayMenu.open()
                }

                function activatePrimary() {
                    if (modelData.onlyMenu)
                        openMenu()
                    else
                        modelData.activate()
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.14)
                    visible: trayMouse.containsMouse || trayMenu.visible
                }

                IconImage {
                    width: root.iconSize
                    height: root.iconSize
                    anchors.centerIn: parent
                    source: trayItem.modelData.icon
                    smooth: true
                    asynchronous: true
                }

                MouseArea {
                    id: trayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: function(mouse) {
                        if (mouse.button === Qt.MiddleButton) {
                            trayItem.modelData.secondaryActivate()
                            return
                        }
                        if (mouse.button === Qt.RightButton) {
                            trayItem.openMenu()
                            return
                        }
                        trayItem.activatePrimary()
                    }
                }

                QsMenuAnchor {
                    id: trayMenu
                    menu: trayItem.modelData.menu
                    anchor {
                        item: trayItem
                        edges: Edges.Bottom
                        gravity: Edges.Bottom
                        margins.bottom: -4
                    }
                }

                PopupWindow {
                    id: trayTooltip
                    visible: trayMouse.containsMouse && !trayMenu.visible
                        && trayItem.tooltip.length > 0
                    implicitWidth: tooltipText.implicitWidth + 16
                    implicitHeight: tooltipText.implicitHeight + 10
                    color: "transparent"
                    anchor {
                        item: trayItem
                        edges: Edges.Bottom
                        gravity: Edges.Bottom
                        margins.bottom: -6
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: Qt.rgba(0.18, 0.18, 0.20, 0.95)

                        Text {
                            id: tooltipText
                            anchors.centerIn: parent
                            text: trayItem.tooltip
                            color: "white"
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
