import QtQuick

// A QML-only liquid finish for surfaces that already use compositor blur.
// Keeping the material in Qt Quick preserves anti-aliased rounded corners.
Rectangle {
    id: root

    property color baseColor: Qt.rgba(0, 0, 0, 0.1)
    property real surfaceOpacity: 1.0

    color: Qt.rgba(
        baseColor.r,
        baseColor.g,
        baseColor.b,
        baseColor.a * surfaceOpacity
    )

    // A soft top reflection gives the surface depth without a hard border.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.28) }
            GradientStop { position: 0.10; color: Qt.rgba(0.88, 0.94, 1, 0.15) }
            GradientStop { position: 0.28; color: Qt.rgba(1, 1, 1, 0.07) }
            GradientStop { position: 0.58; color: Qt.rgba(0.86, 0.93, 1, 0.025) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.11) }
        }
    }

    // A faint lateral tint makes the material feel thicker than a flat
    // vertical gradient, while remaining subtle over both light and dark
    // wallpapers.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0.72, 0.88, 1, 0.045) }
            GradientStop { position: 0.46; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 0.84, 0.92, 0.035) }
        }
    }

    // Inset specular lines imply a glass edge without reintroducing a visible
    // outline. Their endpoints begin after the curved corners.
    Rectangle {
        x: Math.min(parent.width / 2, root.radius + 3)
        y: 0.8
        width: Math.max(0, parent.width - x * 2)
        height: 0.6
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0.14) }
            GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.26) }
            GradientStop { position: 0.82; color: Qt.rgba(1, 1, 1, 0.14) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
        }
    }

    Rectangle {
        x: Math.min(parent.width / 2, root.radius + 3)
        y: parent.height - 2
        width: Math.max(0, parent.width - x * 2)
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.20; color: Qt.rgba(0, 0, 0, 0.09) }
            GradientStop { position: 0.50; color: Qt.rgba(0, 0, 0, 0.16) }
            GradientStop { position: 0.80; color: Qt.rgba(0, 0, 0, 0.09) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.0) }
        }
    }

}
