import QtQuick
import Quickshell
import Quickshell.Widgets

// Read-only folder popup. Editing, rename, reorder, and drag-and-drop are
// intentionally separate future steps so this surface remains easy to test.

PopupWindow {
    id: menu

    property string folderName: "新文件夹"
    property string folderId: ""
    property var apps: []
    property Item anchorItem: null

    signal appActivated(string appId)
    signal appRemoved(string appId)

    readonly property int cellSize: 48
    readonly property int columns: Math.min(4, Math.max(1, apps.length))

    implicitWidth: 12 + columns * cellSize
    implicitHeight: 42 + Math.ceil(apps.length / columns) * cellSize
    color: "transparent"
    grabFocus: true

    anchor {
        item: menu.anchorItem
        edges: Edges.Top
        gravity: Edges.Top
        margins.top: -8
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(0.08, 0.08, 0.10, 0.9)

        Text {
            id: title
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 34
            leftPadding: 8
            verticalAlignment: Text.AlignVCenter
            text: menu.folderName
            color: "white"
            font.pixelSize: 13
        }

        Grid {
            anchors.top: title.bottom
            anchors.left: parent.left
            anchors.leftMargin: 6
            columns: menu.columns
            spacing: 0

            Repeater {
                model: menu.apps
                delegate: Item {
                    required property var modelData
                    width: menu.cellSize
                    height: menu.cellSize

                    IconImage {
                        width: 32
                        height: 32
                        anchors.centerIn: parent
                        source: modelData.icon ?? ""
                        smooth: true
                        asynchronous: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: function(mouse) {
                            if (mouse.button === Qt.RightButton) {
                                menu.appRemoved(modelData.appId)
                                return
                            }
                            menu.visible = false
                            menu.appActivated(modelData.appId)
                        }
                    }
                }
            }
        }
    }
}
