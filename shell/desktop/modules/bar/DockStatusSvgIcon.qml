import QtQuick
import QtQuick.Effects
import qs.desktop.modules.common
import qs.desktop.modules.dock

// Project-owned status SVG renderer. The source artwork is white and acts as
// an alpha mask: colour/grayscale modes stay white; tint mode projects a
// mid-high luminance through the same tonal transform as application icons.
// A restrained dark shadow gives flat SVGs the depth already present in most
// application and StatusNotifier artwork.
Item {
    id: root

    property url source
    readonly property color iconColor: IconAppearanceService.mode === "tint"
        ? IconAppearanceService.styledSymbolicColor()
        : (ThemeService.isDark ? ThemeService.foregroundColor : "#000000")
    readonly property real appearanceOpacity: IconAppearanceService.mode !== "color"
        ? IconAppearanceService.opacity : 1.0

    implicitWidth: 16
    implicitHeight: 16

    Image {
        anchors.fill: parent
        source: root.source
        sourceSize.width: Math.max(1, Math.ceil(width * 2))
        sourceSize.height: Math.max(1, Math.ceil(height * 2))
        fillMode: Image.PreserveAspectFit
        smooth: true
        asynchronous: true
        opacity: root.appearanceOpacity
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: root.iconColor
            shadowEnabled: IconAppearanceService.mode !== "color" || ThemeService.isDark
            shadowColor: Qt.rgba(0, 0, 0, 0.82)
            shadowOpacity: 0.62
            shadowBlur: 0.32
            shadowVerticalOffset: 0.7
            shadowScale: 1.04
        }
    }
}
