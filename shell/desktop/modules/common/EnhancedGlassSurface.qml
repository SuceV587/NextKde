import QtQuick
import qs.desktop.modules.common

// Enhanced glass surface for panels without KWin compositor blur.
// Dark base layer for text readability + LiquidGlassSurface material finish.
// Dock uses KWin Glass plugin and doesn't need this.

Rectangle {
    id: root
    color: "transparent"

    property color baseColor: Qt.rgba(0, 0, 0, 0.1)
    property real surfaceOpacity: 1.0
    property color ambientPrimary: "transparent"
    property color ambientSecondary: "transparent"
    property real ambientStrength: 0.0
    property real materialDepth: 0.0
    property bool bottomEdgeVisible: true
    property bool bottomShadeVisible: true

    // Light base for text readability
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.rgba(0.03, 0.03, 0.05, 0.30)
    }

    // Liquid-glass material layer (reflection, tint, specular edges)
    LiquidGlassSurface {
        anchors.fill: parent
        radius: root.radius
        border.width: root.border.width
        border.color: root.border.color
        baseColor: root.baseColor
        ambientPrimary: root.ambientPrimary
        ambientSecondary: root.ambientSecondary
        ambientStrength: root.ambientStrength
        surfaceOpacity: root.surfaceOpacity
        materialDepth: root.materialDepth
        bottomEdgeVisible: root.bottomEdgeVisible
        bottomShadeVisible: root.bottomShadeVisible
    }
}
