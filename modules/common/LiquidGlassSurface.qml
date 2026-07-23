import QtQuick

// A QML-only liquid finish for surfaces that already use compositor blur.
// Keeping the material in Qt Quick preserves anti-aliased rounded corners.
Rectangle {
    id: root

    property color baseColor: Qt.rgba(0, 0, 0, 0.1)
    property real surfaceOpacity: 1.0
    property color ambientPrimary: "transparent"
    property color ambientSecondary: "transparent"
    property real ambientStrength: 0.0
    // 0 = dock/base surface, 1 = popup, 2 = contextual foreground menu.
    property real materialDepth: 0.0
    readonly property real baseLuminance: baseColor.r * 0.2126
        + baseColor.g * 0.7152 + baseColor.b * 0.0722
    // Bright surfaces need less white overlay to remain translucent; darker
    // ones retain the stronger reflection that makes the material readable.
    readonly property real highlightFactor: baseLuminance > 0.6 ? 0.70 : 1.0
    readonly property real materialHighlightFactor: highlightFactor
        * (1.0 + Math.max(0.0, materialDepth) * 0.10)

    // Wallpaper palette updates arrive asynchronously. Animate at the
    // surface boundary as well, so every consumer gets the same calm crossfade
    // even when its palette source changes colours in one assignment.
    Behavior on ambientPrimary {
        ColorAnimation { duration: 760; easing.type: Easing.InOutCubic }
    }
    Behavior on ambientSecondary {
        ColorAnimation { duration: 760; easing.type: Easing.InOutCubic }
    }
    Behavior on ambientStrength {
        NumberAnimation { duration: 420; easing.type: Easing.InOutCubic }
    }

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
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.28 * root.materialHighlightFactor) }
            GradientStop { position: 0.10; color: Qt.rgba(0.88, 0.94, 1, 0.15 * root.materialHighlightFactor) }
            GradientStop { position: 0.28; color: Qt.rgba(1, 1, 1, 0.07 * root.materialHighlightFactor) }
            GradientStop { position: 0.58; color: Qt.rgba(0.86, 0.93, 1, 0.025 * root.materialHighlightFactor) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.11 + Math.max(0.0, root.materialDepth) * 0.025) }
        }
    }

    // Wallpaper-derived tint: it stays deliberately below the specular layer
    // so the material adapts to its environment without becoming a colour card.
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: Qt.rgba(
                    root.ambientPrimary.r, root.ambientPrimary.g, root.ambientPrimary.b,
                    root.ambientStrength * 0.22
                )
            }
            GradientStop {
                position: 0.55
                color: Qt.rgba(
                    root.ambientSecondary.r, root.ambientSecondary.g, root.ambientSecondary.b,
                    root.ambientStrength * 0.12
                )
            }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
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
            GradientStop { position: 0.0; color: Qt.rgba(0.72, 0.88, 1, 0.045 * root.materialHighlightFactor) }
            GradientStop { position: 0.46; color: Qt.rgba(1, 1, 1, 0.0) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 0.84, 0.92, 0.035 * root.materialHighlightFactor) }
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
            GradientStop { position: 0.18; color: Qt.rgba(1, 1, 1, 0.14 * root.materialHighlightFactor) }
            GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, 0.26 * root.materialHighlightFactor) }
            GradientStop { position: 0.82; color: Qt.rgba(1, 1, 1, 0.14 * root.materialHighlightFactor) }
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
