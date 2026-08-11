import QtQuick

// iOS-style liquid-glass slider. `value` (0..1) is parent-owned so the
// binding survives drags: the slider only reports normalized drag positions
// via dragPositionChanged/valueCommitted and never mutates `value` itself.
// Visual layers are pure 2D — translucent track, frame-locked fill, glass
// thumb with a balloon-on-press expansion — so it layers on compositor blur.
Item {
    id: root

    implicitWidth: 120
    implicitHeight: Math.max(root.thumbSize + 10, root.trackHeight + 10)

    property real value: 0.0
    property bool enabled: true
    // false = static display (e.g. brightness without a backend): no
    // MouseArea, the thumb still renders at `value`.
    property bool interactive: true
    property color activeColor: "white"
    property color trackColor: Qt.rgba(1, 1, 1, 0.20)
    property real trackHeight: 4
    property real thumbSize: 15

    signal dragPositionChanged(real normalizedX)
    signal valueCommitted(real normalizedX)

    property bool _dragging: false
    readonly property real _fillWidth: width * Math.max(0.0, Math.min(1.0, root.value))

    opacity: root.enabled ? 1.0 : 0.45

    // Inactive track (translucent capsule).
    Rectangle {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        height: root.trackHeight
        radius: height / 2
        color: root.trackColor
    }

    // Active fill: left edge rounded, right edge squared until full value.
    Rectangle {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        width: root._fillWidth
        height: root.trackHeight
        radius: height / 2
        color: root.activeColor
    }

    // Glass thumb: white material, offset contact shadow, top highlight, and
    // a balloon expansion while dragging (iOS 1.0 -> 1.35 at 150ms OutBack).
    Item {
        id: thumb
        anchors.verticalCenter: parent.verticalCenter
        x: root._fillWidth - width / 2
        width: root.thumbSize
        height: root.thumbSize
        scale: root._dragging ? 1.35 : (dragArea.containsMouse ? 1.08 : 1.0)
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }

        // Contact shadow (offset dark pill under the white material).
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 3
            height: parent.height - 3
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.25)
            transform: Translate { y: 1.5 }
        }
        // White material pill.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "white"
        }
        // Glass-shell top highlight.
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.85) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
        // Drag glow ring.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, root._dragging ? 0.45 : 0.0)
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }
        }
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        enabled: root.enabled && root.interactive
        cursorShape: Qt.PointingHandCursor
        onPressed: function(mouse) {
            root._dragging = true
            root.dragPositionChanged(Math.max(0, Math.min(1, mouse.x / root.width)))
        }
        onPositionChanged: function(mouse) {
            if (pressed)
                root.dragPositionChanged(Math.max(0, Math.min(1, mouse.x / root.width)))
        }
        onReleased: {
            root._dragging = false
            root.valueCommitted(root.value)
        }
    }
}
