import QtQuick
import Quickshell

PopupWindow {
    id: menu

    property string folderId: ""
    property string folderName: ""
    property Item anchorItem: null

    implicitWidth: 190
    implicitHeight: 116
    color: "transparent"
    grabFocus: true

    anchor {
        item: menu.anchorItem
        edges: Edges.Top
        gravity: Edges.Top
        margins.top: -8
    }

    function saveName() {
        const value = nameInput.text.trim()
        if (!value.length)
            return
        DockModelService.renameFolder(menu.folderId, value)
        menu.visible = false
    }

    function dissolve() {
        DockModelService.dissolveFolder(menu.folderId)
        menu.visible = false
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(0.08, 0.08, 0.10, 0.96)

        Rectangle {
            id: inputBackground
            x: 8
            y: 8
            width: 174
            height: 30
            radius: 5
            color: Qt.rgba(1, 1, 1, 0.10)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.22)

            TextInput {
            id: nameInput
                anchors.fill: parent
                text: menu.folderName
                color: "white"
                selectionColor: Qt.rgba(0.20, 0.60, 1.0, 0.85)
                selectedTextColor: "white"
                verticalAlignment: TextInput.AlignVCenter
                leftPadding: 8
                rightPadding: 8
                font.pixelSize: 13
                focus: true

                Keys.onReturnPressed: menu.saveName()
                Keys.onEscapePressed: menu.visible = false
            }
        }

        Rectangle {
            x: 8
            y: 46
            width: 174
            height: 28
            radius: 5
            color: saveMouse.containsMouse
                ? Qt.rgba(0.20, 0.60, 1.0, 0.90)
                : Qt.rgba(0.20, 0.60, 1.0, 0.72)

            Text {
                anchors.fill: parent
                text: "保存"
                color: "white"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                id: saveMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: menu.saveName()
            }
        }

        Rectangle {
            x: 8
            y: 80
            width: 174
            height: 28
            radius: 5
            color: dissolveMouse.containsMouse
                ? Qt.rgba(1.0, 0.27, 0.23, 0.90)
                : Qt.rgba(1.0, 0.27, 0.23, 0.72)

            Text {
                anchors.fill: parent
                text: "解散文件夹"
                color: "white"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            MouseArea {
                id: dissolveMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: menu.dissolve()
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            nameInput.text = menu.folderName
            nameInput.forceActiveFocus()
            nameInput.selectAll()
        }
    }
}
