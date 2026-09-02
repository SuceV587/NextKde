import QtQuick

// iOS-style liquid-glass switch: a translucent track that blends to the
// accent colour and a white thumb that slides with easeInOutCubic travel
// (380ms). `checked` is parent-owned; tapping emits toggled() so the parent
// decides what happens. Pure 2D layers, no backdrop access needed.
Item {
    id: root

    implicitWidth: 58
    implicitHeight: 26

    property bool checked: false
    property bool enabled: true
    property color activeColor: Qt.rgba(0.15, 0.52, 1, 0.9)
    property color inactiveColor: Qt.rgba(1, 1, 1, 0.18)

    signal toggled(bool checked)

    readonly property real _thumbSize: root.height - 4
    readonly property real _thumbMargin: 2
    // Bloom drives the track's top specular smoothly with the thumb travel.
    property real _bloom: root.checked ? 1.0 : 0.0
    Behavior on _bloom {
        NumberAnimation { duration: 380; easing.type: Easing.InOutCubic }
    }

    opacity: root.enabled ? 1.0 : 0.45

    // Track capsule.
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.activeColor : root.inactiveColor
        Behavior on color {
            ColorAnimation { duration: 380 }
        }
    }
    // Top specular that grows as the switch turns on (iOS bloom).
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08 + root._bloom * 0.22) }
            GradientStop { position: 0.55; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }

    // White thumb that slides.
    Item {
        id: thumb
        anchors.verticalCenter: parent.verticalCenter
        width: root._thumbSize
        height: root._thumbSize
        x: root.checked
            ? root.width - width - root._thumbMargin
            : root._thumbMargin
        Behavior on x {
            NumberAnimation { duration: 380; easing.type: Easing.InOutCubic }
        }

        // Contact shadow (offset dark pill under the white material).
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 2
            height: parent.height - 2
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.25)
            transform: Translate { y: 1.2 }
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
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
