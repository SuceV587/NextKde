import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import qs.modules.common

// One shared active-window background. Geometry is sampled only when the
// active target changes; the animation system interpolates the result.
Item {
    id: indicator

    property Item target: null
    property color fillColor: Qt.rgba(1, 1, 1, 0.5)
    property real baseSize: 0
    property real baseRadius: 0
    property real targetCenterX: 0
    property real targetCenterY: 0
    property real stretchAmount: 0
    property real stretchProgress: 0
    property real travelDirection: 1
    readonly property real leadingRadius: Math.min(height / 2,
        baseRadius + height * 0.52 * stretchProgress)
    // Keep the tail rounded and let it become softer while stretching. The
    // pinch belongs in the bridge/neck, not in a squared-off trailing corner.
    readonly property real trailingRadius: Math.min(height / 2,
        baseRadius + height * 0.20 * stretchProgress)
    readonly property real leftRadius: travelDirection > 0
        ? trailingRadius : leadingRadius
    readonly property real rightRadius: travelDirection > 0
        ? leadingRadius : trailingRadius
    readonly property real sideInset: height * 0.22 * stretchProgress
    readonly property real leftX: travelDirection > 0 ? sideInset : 0
    readonly property real rightX: travelDirection > 0 ? width : width - sideInset
    readonly property real liquidSpan: rightX - leftX
    // Pull the upper and lower edges inward around the trailing third. This
    // creates a visible neck behind the leading bulb instead of a uniformly
    // stretched capsule.
    readonly property real neckDepth: height * 0.28 * stretchProgress
    readonly property real rightwardNeckX: leftX + liquidSpan * 0.38
    readonly property real leftwardNeckX: rightX - liquidSpan * 0.38
    property bool hasPosition: false

    width: baseSize + stretchAmount * stretchProgress
    // The body swells slightly upward/downward while being pulled sideways,
    // rather than reading as a flat, horizontally scaled strip.
    height: baseSize * (1 + 0.16 * stretchProgress)
    x: targetCenterX - width / 2
    y: targetCenterY - height / 2
    opacity: hasPosition && target ? 1.0 : 0.0
    visible: opacity > 0.01
    z: -1

    Behavior on targetCenterX {
        NumberAnimation {
            duration: DockAnimation.activeIndicatorMoveDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on targetCenterY {
        NumberAnimation {
            duration: DockAnimation.activeIndicatorMoveDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    // Resting state intentionally uses a real rounded rectangle, not the
    // liquid path. The selected icon must land on the exact same square
    // highlight as before, including at the Row's final/rightmost slot.
    LiquidGlassSurface {
        anchors.fill: parent
        visible: indicator.stretchProgress <= 0.001
        radius: indicator.baseRadius
        baseColor: Qt.rgba(1, 1, 1, 0.60)
        ambientPrimary: WallpaperPaletteService.primary
        ambientSecondary: WallpaperPaletteService.secondary
        ambientStrength: 0.52
        materialDepth: 0.75
        surfaceOpacity: 1.0
        bottomEdgeVisible: true
        bottomShadeVisible: true
    }

    // Reuse the launcher's liquid-glass material rather than a single white
    // alpha fill. The material is rendered once into a small layer and masked
    // by the dynamic Shape below, so all reflections and ambient pigment obey
    // the same liquid silhouette during the transition.
    Item {
        id: glassMaterial
        anchors.fill: parent
        visible: indicator.stretchProgress > 0.001
        layer.enabled: true
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: liquidMask
        }

        LiquidGlassSurface {
            anchors.fill: parent
            // The mask supplies the true asymmetric corners. This radius only
            // controls the material's inset specular lines.
            radius: Math.min(width, height) * 0.30
            baseColor: Qt.rgba(1, 1, 1, 0.60)
            ambientPrimary: WallpaperPaletteService.primary
            ambientSecondary: WallpaperPaletteService.secondary
            ambientStrength: 0.52 + indicator.stretchProgress * 0.18
            materialDepth: 0.75 + indicator.stretchProgress * 0.35
            surfaceOpacity: 1.0
            bottomEdgeVisible: true
            bottomShadeVisible: true
        }
    }

    // This is deliberately invisible: it provides alpha to the material mask.
    // Keeping the morphology in one Shape prevents the glass layers from
    // drifting apart as the indicator stretches.
    Shape {
        id: liquidMask
        anchors.fill: parent
        visible: false
        layer.enabled: true

        ShapePath {
            // Rightward travel: small tail on the left, full bulb on the right.
            fillColor: indicator.travelDirection > 0 ? "white" : "transparent"
            strokeWidth: -1

            startX: indicator.leftX + indicator.leftRadius
            startY: 0
            PathCubic {
                // The curve sinks into a narrow neck, then rises into the
                // large leading bulb. At rest neckDepth is zero, so this is
                // the original straight top edge.
                control1X: indicator.rightwardNeckX - indicator.liquidSpan * 0.15
                control1Y: indicator.neckDepth
                control2X: indicator.rightwardNeckX + indicator.liquidSpan * 0.12
                control2Y: indicator.neckDepth
                x: indicator.rightX - indicator.rightRadius
                y: 0
            }
            PathCubic {
                control1X: indicator.rightX - indicator.rightRadius * 0.45
                control1Y: 0
                control2X: indicator.rightX
                control2Y: indicator.rightRadius * 0.45
                x: indicator.rightX
                y: indicator.rightRadius
            }
            PathLine { x: indicator.rightX; y: indicator.height - indicator.rightRadius }
            PathCubic {
                control1X: indicator.rightX
                control1Y: indicator.height - indicator.rightRadius * 0.45
                control2X: indicator.rightX - indicator.rightRadius * 0.45
                control2Y: indicator.height
                x: indicator.rightX - indicator.rightRadius
                y: indicator.height
            }
            PathCubic {
                control1X: indicator.rightwardNeckX + indicator.liquidSpan * 0.12
                control1Y: indicator.height - indicator.neckDepth
                control2X: indicator.rightwardNeckX - indicator.liquidSpan * 0.15
                control2Y: indicator.height - indicator.neckDepth
                x: indicator.leftX + indicator.leftRadius
                y: indicator.height
            }
            PathLine {
                x: indicator.leftX
                y: indicator.height - indicator.leftRadius
            }
            PathLine { x: indicator.leftX; y: indicator.leftRadius }
            PathCubic {
                control1X: indicator.leftX
                control1Y: indicator.leftRadius * 0.45
                control2X: indicator.leftX + indicator.leftRadius * 0.45
                control2Y: 0
                x: indicator.leftX + indicator.leftRadius
                y: 0
            }
            PathLine {
                x: indicator.leftX + indicator.leftRadius
                y: 0
            }
        }

        ShapePath {
            // Mirrored contour for leftward travel.
            fillColor: indicator.travelDirection < 0 ? "white" : "transparent"
            strokeWidth: -1

            startX: indicator.leftX + indicator.leftRadius
            startY: 0
            PathCubic {
                control1X: indicator.leftwardNeckX - indicator.liquidSpan * 0.12
                control1Y: indicator.neckDepth
                control2X: indicator.leftwardNeckX + indicator.liquidSpan * 0.15
                control2Y: indicator.neckDepth
                x: indicator.rightX - indicator.rightRadius
                y: 0
            }
            PathCubic {
                control1X: indicator.rightX - indicator.rightRadius * 0.45
                control1Y: 0
                control2X: indicator.rightX
                control2Y: indicator.rightRadius * 0.45
                x: indicator.rightX
                y: indicator.rightRadius
            }
            PathLine { x: indicator.rightX; y: indicator.height - indicator.rightRadius }
            PathCubic {
                control1X: indicator.rightX
                control1Y: indicator.height - indicator.rightRadius * 0.45
                control2X: indicator.rightX - indicator.rightRadius * 0.45
                control2Y: indicator.height
                x: indicator.rightX - indicator.rightRadius
                y: indicator.height
            }
            PathCubic {
                control1X: indicator.leftwardNeckX + indicator.liquidSpan * 0.15
                control1Y: indicator.height - indicator.neckDepth
                control2X: indicator.leftwardNeckX - indicator.liquidSpan * 0.12
                control2Y: indicator.height - indicator.neckDepth
                x: indicator.leftX + indicator.leftRadius
                y: indicator.height
            }
            PathCubic {
                control1X: indicator.leftX + indicator.leftRadius * 0.45
                control1Y: indicator.height
                control2X: indicator.leftX
                control2Y: indicator.height - indicator.leftRadius * 0.45
                x: indicator.leftX
                y: indicator.height - indicator.leftRadius
            }
            PathLine { x: indicator.leftX; y: indicator.leftRadius }
            PathCubic {
                control1X: indicator.leftX
                control1Y: indicator.leftRadius * 0.45
                control2X: indicator.leftX + indicator.leftRadius * 0.45
                control2Y: 0
                x: indicator.leftX + indicator.leftRadius
                y: 0
            }
        }
    }

    SequentialAnimation {
        id: liquidTransition
        NumberAnimation {
            target: indicator
            property: "stretchProgress"
            to: 1.0
            duration: DockAnimation.activeIndicatorStretchInDuration
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: indicator
            property: "stretchProgress"
            to: 0.0
            duration: DockAnimation.activeIndicatorSettleDuration
            easing.type: Easing.OutBack
        }
    }

    function setTarget(nextTarget) {
        if (!nextTarget || !parent) {
            target = null
            hasPosition = false
            stretchAmount = 0
            stretchProgress = 0
            return
        }

        const center = nextTarget.mapToItem(
            parent, nextTarget.width / 2, nextTarget.height / 2)
        const nextSize = Math.min(nextTarget.width, nextTarget.height)
        const nextRadius = typeof nextTarget.activeBackgroundRadius !== "undefined"
            ? nextTarget.activeBackgroundRadius : nextSize * 0.3

        target = nextTarget
        if (!hasPosition) {
            baseSize = nextSize
            baseRadius = nextRadius
            stretchAmount = 0
            targetCenterX = center.x
            targetCenterY = center.y
            hasPosition = true
            return
        }

        const dx = center.x - targetCenterX
        const dy = center.y - targetCenterY
        const distance = Math.sqrt(dx * dx + dy * dy)
        baseSize = nextSize
        if (Math.abs(dx) > 0.5)
            travelDirection = dx > 0 ? 1 : -1
        stretchAmount = Math.min(distance * 1.8, nextSize * 2.15)
        baseRadius = nextRadius
        stretchProgress = 0
        liquidTransition.restart()
        targetCenterX = center.x
        targetCenterY = center.y
    }
}
