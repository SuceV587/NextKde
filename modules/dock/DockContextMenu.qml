import QtQuick
import Quickshell

// DockContextMenu — transient context menu for one DockIcon.
// It owns presentation only; actions are emitted to DockIcon, which delegates
// them to DockModelService. No menu state is persisted.

PopupWindow {
    id: menu

    property bool isWindow: false
    property string appId: ""
    property string windowId: ""
    property Item anchorItem: null

    signal action(string name)

    readonly property var folderEntries: {
        const entries = []
        const items = ConfigService.dockItems || []
        for (let i = 0; i < items.length; i++) {
            const item = items[i]
            if (item.type === "folder") {
                entries.push({
                    name: "moveToFolder:" + item.id,
                    label: "移入「" + item.name + "」",
                })
            }
        }
        return entries
    }

    readonly property var entries: {
        if (isWindow) {
            return [
                { name: "activate", label: "激活窗口" },
                { name: "minimize", label: "最小化" },
                { name: "close", label: "关闭窗口" },
                { name: "pin", label: "固定此应用" },
            ]
        }
        return [
            { name: "open", label: "打开" },
            { name: "createFolder", label: "新建文件夹并移入" },
        ].concat(folderEntries).concat([
            { name: "unpin", label: "取消固定" },
        ])
    }

    // PopupWindow derives its size from implicit dimensions. Using width /
    // height here triggers a deprecation warning in newer Quickshell builds.
    implicitWidth: 156
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

        onAnchoring: console.log("[DockMenu] anchoring app=" + menu.appId + " item=(" + (menu.anchorItem?.x ?? -1) + "," + (menu.anchorItem?.y ?? -1) + " " + (menu.anchorItem?.width ?? -1) + "x" + (menu.anchorItem?.height ?? -1) + ") rect=(" + menu.anchor.rect.x + "," + menu.anchor.rect.y + " " + menu.anchor.rect.width + "x" + menu.anchor.rect.height + ") edges=Top gravity=Top")
    }

    onVisibleChanged: {
        if (visible)
            console.log("[DockMenu] show app=" + appId + " window=" + windowId + " size=" + width + "x" + height);
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Qt.rgba(0.08, 0.08, 0.10, 0.9)
        // border.width: 1
        // border.color: Qt.rgba(1, 1, 1, 0.12)

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
                    radius: 5
                    color: menuItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.label
                        color: "white"
                        font.pixelSize: 13
                    }

                    MouseArea {
                        id: menuItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: menu.action(modelData.name)
                    }
                }
            }
        }
    }
}
