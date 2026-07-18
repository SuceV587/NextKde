import QtQuick
import Quickshell.Widgets

// DockFolderIcon — compact folder tile for the first folder vertical slice.
// It intentionally owns no editing or drag state yet; those arrive in the
// Dock edit-mode step after the read-only folder popup is validated.

Item {
    id: folderIcon

    property int iconSize: 44
    property real activeBackgroundGap: 4.4
    property string folderId: ""
    property string folderName: "新文件夹"
    property var apps: []

    readonly property real iconSlotSize: iconSize + activeBackgroundGap * 2
    readonly property real activeBackgroundRadius: iconSize * 0.3

    width: iconSlotSize
    height: iconSlotSize
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Rectangle {
        anchors.fill: parent
        radius: folderIcon.activeBackgroundRadius
        color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
    }

    // Compact 3x3 preview of the first nine members. The tighter inset keeps
    // each mini icon legible while making the folder's capacity visible.
    Grid {
        id: previewGrid
        columns: 3
        rows: 3
        spacing: Math.max(1, Math.round(folderIcon.iconSize * 0.04))
        width: folderIcon.iconSize * 0.82
        height: width
        anchors.centerIn: parent

        Repeater {
            model: folderIcon.apps.slice(0, 9)
            delegate: IconImage {
                required property var modelData
                width: (previewGrid.width - previewGrid.spacing * 2) / 3
                height: width
                source: modelData.icon ?? ""
                smooth: true
                asynchronous: true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                folderContextMenu.visible = true
                return
            }
            folderMenu.visible = true
        }
    }

    DockFolderMenu {
        id: folderMenu
        folderId: folderIcon.folderId
        folderName: folderIcon.folderName
        apps: folderIcon.apps
        anchorItem: folderIcon
        onAppActivated: DockModelService.activateApp(appId)
        onAppRemoved: DockModelService.removeAppFromFolder(folderId, appId)
    }

    DockFolderContextMenu {
        id: folderContextMenu
        folderId: folderIcon.folderId
        folderName: folderIcon.folderName
        anchorItem: folderIcon
    }
}
