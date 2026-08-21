import QtQuick

// One row of a ContextMenu. Hover is driven by the MouseArea onEntered/onExited
// (the codebase's proven pattern, see DockIcon) and uses a darker theme-foreground
// tint so the pointer row reads clearly over the liquid glass.
Item {
    id: row

    property string label: ""
    property string icon: ""
    property color foregroundColor: "#ffffff"
    property bool itemEnabled: true
    signal clicked()

    property bool _hover: false
    readonly property color _hi: Qt.rgba(
        row.foregroundColor.r, row.foregroundColor.g, row.foregroundColor.b,
        itemEnabled ? 0.24 : 0.20)

    visible: label.length > 0
    height: 38
    width: parent ? parent.width : 0
    opacity: itemEnabled ? 1.0 : 0.45

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 10
        color: (row._hover && row.itemEnabled) ? row._hi : "transparent"
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
            color: row.foregroundColor
            opacity: 0.85
        }
        Text {
            text: row.label
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: row.foregroundColor
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.itemEnabled
        onClicked: row.clicked()
        onEntered: row._hover = true
        onExited: row._hover = false
    }
}