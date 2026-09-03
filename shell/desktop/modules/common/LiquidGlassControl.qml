import QtQuick
import Qt5Compat.GraphicalEffects

// A control-level liquid glass treatment for small controls such as media
// transport buttons.
//
// Compositor blur is window-level: it blurs whatever is behind the window
// (wallpaper, other windows), and QML cannot read those pixels. To make a
// single control read as liquid glass, this component captures a *window-local*
// background layer (the `sourceItem`, typically a media artwork backdrop) with
// ShaderEffectSource, blurs that region with FastBlur, and clips it to the
// control's rounded shape - the iOS "button is a frosted lens over its card"
// effect. When `sourceItem` is null (e.g. nothing is playing) it degrades to a
// plain glass circle so the control never disappears.
Item {
    id: root

    // The window-local layer whose pixels this control blurs. Must not contain
    // this control (no recursion). When null, only the glass tint/highlight
    // are drawn.
    property Item sourceItem: null
    // When true, capture the whole sourceItem (stretched to this control)
    // instead of the exact region under the control. Use this when the source
    // is a small artwork thumbnail that does not geometrically contain the
    // control: the button then reads as a frosted swatch of that artwork.
    property bool stretchSource: false
    // Frosted blur strength in pixels.
    property real blurRadius: AppearanceConfigService.blurStrength * 24
    // Rounded shape; defaults to a circle.
    property real cornerRadius: width / 2
    // Translucent body tint layered over the blur.
    property color tintColor: Qt.rgba(1, 1, 1, 0.10)
    // Top reflection strength, like the larger liquid surfaces.
    property real highlightStrength: 0.30 * AppearanceConfigService.liquidStrength
    property color borderColor: Qt.rgba(
        1, 1, 1, 0.30 * AppearanceConfigService.liquidStrength)
    property real borderWidth: 1

    // The captured region in the source item's coordinate space. Recalculated
    // on geometry changes so the blur always tracks the control.
    readonly property rect _sourceRect: {
        if (!sourceItem)
            return Qt.rect(0, 0, 0, 0)
        if (stretchSource)
            return Qt.rect(0, 0, sourceItem.width, sourceItem.height)
        const p = root.mapToItem(sourceItem, 0, 0)
        return Qt.rect(p.x, p.y, root.width, root.height)
    }

    ShaderEffectSource {
        id: glassSource
        // The effect chain reads this item directly; hiding it prevents a
        // stray artifact from the unclipped rectangle from painting.
        visible: false
        sourceItem: root.sourceItem
        sourceRect: root._sourceRect
        live: true
        hideSource: false
        smooth: true
    }

    FastBlur {
        id: glassBlur
        anchors.fill: parent
        source: glassSource
        radius: Math.max(1, Math.round(root.blurRadius))
        // Keep the soft alpha fringe at the rectangle edges instead of
        // clipping it to a hard square.
        transparentBorder: true
        cached: true
        visible: root.sourceItem !== null && root.blurRadius > 0.01
    }

    // Clip the blurred rectangle to the control's rounded shape.
    OpacityMask {
        anchors.fill: parent
        source: glassBlur
        maskSource: glassMask
        visible: root.sourceItem !== null && root.blurRadius > 0.01
    }
    Rectangle {
        id: glassMask
        anchors.fill: parent
        radius: root.cornerRadius
        visible: false
        layer.enabled: true
    }

    // Glass body over the blur: a soft top reflection and a faint tint give
    // the control depth even when the backdrop is nearly uniform. This layer
    // is always visible, so a null sourceItem still yields a glass circle.
    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.tintColor
        border.width: root.borderWidth
        border.color: root.borderColor

        // Specular top sheen, mirroring the material of the larger surfaces.
        Rectangle {
            anchors.fill: parent
            radius: root.cornerRadius
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.55 * root.highlightStrength) }
                GradientStop { position: 0.35; color: Qt.rgba(1, 1, 1, 0.22 * root.highlightStrength) }
                GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }
}
