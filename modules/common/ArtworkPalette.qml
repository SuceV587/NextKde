import QtQuick
import Quickshell

// Selects two distinct colours from Quickshell's asynchronous image
// quantizer. It works for both MPRIS artwork and local wallpaper files.
Item {
    id: root

    property url source: ""
    readonly property color fallbackPrimary: Qt.rgba(0.16, 0.20, 0.28, 1)
    readonly property color fallbackSecondary: Qt.rgba(0.30, 0.16, 0.30, 1)
    property color primary: fallbackPrimary
    property color secondary: fallbackSecondary
    property bool ready: false
    // Consumers that already animate their own material can set this to 0 so
    // there is one deliberate colour transition rather than two retargeting
    // animations chasing one another.
    property int transitionDuration: 760

    Behavior on primary {
        enabled: root.transitionDuration > 0
        ColorAnimation { duration: root.transitionDuration; easing.type: Easing.InOutCubic }
    }
    Behavior on secondary {
        enabled: root.transitionDuration > 0
        ColorAnimation { duration: root.transitionDuration; easing.type: Easing.InOutCubic }
    }

    function _distance(left, right) {
        return Math.abs(left.r - right.r)
            + Math.abs(left.g - right.g)
            + Math.abs(left.b - right.b)
    }

    function _apply(colors) {
        const usable = colors.filter(color => {
            const brightest = Math.max(color.r, color.g, color.b)
            const darkest = Math.min(color.r, color.g, color.b)
            return brightest > 0.16 && darkest < 0.90 && brightest - darkest > 0.10
        })
        if (usable.length === 0) {
            primary = fallbackPrimary
            secondary = fallbackSecondary
            ready = false
            return
        }

        primary = usable[0]
        secondary = usable.find(color => _distance(color, primary) > 0.28)
            || Qt.rgba(
                Math.min(1, primary.r * 0.70 + 0.12),
                Math.min(1, primary.g * 0.70 + 0.07),
                Math.min(1, primary.b * 0.78 + 0.18),
                1
            )
        ready = true
    }

    onSourceChanged: {
        ready = false
        if (!source) {
            primary = fallbackPrimary
            secondary = fallbackSecondary
        }
    }

    ColorQuantizer {
        id: quantizer
        source: root.source
        depth: 8
        rescaleSize: 48
        onColorsChanged: root._apply(colors)
    }
}
