import QtQuick
import qs.desktop.modules.dock

// One tappable row in a liquid-glass context menu (see DockContextPopup).
Item {
    id: row

    property string label: ""
    property string icon: ""
    signal clicked()

    visible: label.length > 0
    height: 38
    width: parent ? parent.width : 0

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 10
        color: hoverMouse.hovered
            ? Qt.rgba(ThemeService.foregroundColor.r, ThemeService.foregroundColor.g,
                ThemeService.foregroundColor.b, 0.16)
            : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Text {
            width: 18
            text: row.icon
            font.family: "Font Awesome 7 Free"
            font.pixelSize: 13
            color: ThemeService.foregroundColor
            opacity: 0.85
        }
        Text {
            text: row.label
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: ThemeService.foregroundColor
        }
    }

    MouseArea {
        id: hoverMouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: row.clicked()
    }
}