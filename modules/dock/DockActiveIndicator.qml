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
    // A moving selection behaves like a horizontal droplet: a full leading
    // head flows toward the destination while a short rounded tail follows.
    readonly property real sideInset: height * 0.14 * stretchProgress
    readonly property real leftX: sideInset
    readonly property real rightX: width - sideInset
    readonly property real liquidSpan: rightX - leftX
    readonly property real tailCenterY: height / 2
    readonly property real tailInsetY: height * 0.15 * stretchProgress
    readonly property real tailTopY: tailInsetY
    readonly property real tailBottomY: height - tailInsetY
    readonly property real tailRadius: tailCenterY - tailInsetY
    readonly property real leadingRadius: Math.min(height / 2,
        liquidSpan / 2)
    readonly property real leadingStartX: rightX - leadingRadius
    readonly property real trailingStartX: leftX + tailRadius
    property bool hasPosition: false

    function directionX(rightwardX) {
        return travelDirection > 0 ? rightwardX : width - rightwardX
    }

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
            // The leading head stays full-height. The shorter trailing cap
            // connects with horizontal tangents, so the body flows smoothly
            // instead of pinching at the centre.
            fillColor: "white"
            strokeWidth: -1

            startX: indicator.directionX(indicator.trailingStartX)
            startY: indicator.tailTopY
            PathCubic {
                control1X: indicator.directionX(indicator.trailingStartX
                    + indicator.liquidSpan * 0.24)
                control1Y: indicator.tailTopY
                control2X: indicator.directionX(indicator.leadingStartX
                    - indicator.liquidSpan * 0.16)
                control2Y: 0
                x: indicator.directionX(indicator.leadingStartX)
                y: 0
            }
            PathCubic {
                control1X: indicator.directionX(indicator.leadingStartX
                    + indicator.leadingRadius * 0.55)
                control1Y: 0
                control2X: indicator.directionX(indicator.rightX)
                control2Y: indicator.tailCenterY
                    - indicator.leadingRadius * 0.55
                x: indicator.directionX(indicator.rightX)
                y: indicator.tailCenterY
            }
            PathCubic {
                control1X: indicator.directionX(indicator.rightX)
                control1Y: indicator.tailCenterY
                    + indicator.leadingRadius * 0.55
                control2X: indicator.directionX(indicator.leadingStartX
                    + indicator.leadingRadius * 0.55)
                control2Y: indicator.height
                x: indicator.directionX(indicator.leadingStartX)
                y: indicator.height
            }
            PathCubic {
                control1X: indicator.directionX(indicator.leadingStartX
                    - indicator.liquidSpan * 0.16)
                control1Y: indicator.height
                control2X: indicator.directionX(indicator.trailingStartX
                    + indicator.liquidSpan * 0.24)
                control2Y: indicator.tailBottomY
                x: indicator.directionX(indicator.trailingStartX)
                y: indicator.tailBottomY
            }
            PathCubic {
                control1X: indicator.directionX(indicator.trailingStartX
                    - indicator.tailRadius * 0.55)
                control1Y: indicator.tailBottomY
                control2X: indicator.directionX(indicator.leftX)
                control2Y: indicator.tailCenterY
                    + indicator.tailRadius * 0.55
                x: indicator.directionX(indicator.leftX)
                y: indicator.tailCenterY
            }
            PathCubic {
                control1X: indicator.directionX(indicator.leftX)
                control1Y: indicator.tailCenterY
                    - indicator.tailRadius * 0.55
                control2X: indicator.directionX(indicator.trailingStartX
                    - indicator.tailRadius * 0.55)
                control2Y: indicator.tailTopY
                x: indicator.directionX(indicator.trailingStartX)
                y: indicator.tailTopY
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
