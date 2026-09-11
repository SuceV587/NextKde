import QtQuick

// Stable, local contrast for interactive content on liquid glass. It never
// paints a large theme-coloured panel: hover/selection is a 5.5% neutral veil
// and press adds only a restrained inner contact shadow.
Rectangle {
    id: root

    property bool active: false
    property bool pressed: false
    property real emphasis: 1.0
    property real cornerRadius: 0

    radius: cornerRadius
    color: Qt.rgba(0.012, 0.020, 0.042,
                   active ? (pressed ? 0.080 : 0.055) * emphasis : 0.0)
    Behavior on color { ColorAnimation { duration: root.pressed ? 45 : 110 } }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 0.6
        radius: Math.max(0, root.cornerRadius - 0.6)
        color: "transparent"
        border.width: root.pressed ? 1 : 0
        border.color: Qt.rgba(0.0, 0.0, 0.0, 0.16 * root.emphasis)
        Behavior on border.width { NumberAnimation { duration: 45 } }
    }
}
