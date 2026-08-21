import QtQuick
import QtQuick.Effects

// ────────────────────────────────────────────────────────────────
// DockRevealHandle — pure visual + pointer-input Home Indicator.
//
// Renders an iOS-style white pill on the screen edge and exposes an invisible
// hit target large enough to catch a cursory pointer pass. It never reads any
// service/configuration; the owning DockWindow positions it inside the dock
// surface and feeds it state. See docs/DockSmartHideDesign.md §6.4/§10.2.
// ────────────────────────────────────────────────────────────────

Item {
    id: handle

    // ── Inputs ──
    property string position: "bottom"   // bottom | left | right
    property real windowWidth: 0         // owning surface size (logical px)
    property real windowHeight: 0
    property real screenWidth: 0
    property real screenHeight: 0
    // Cross-fade opacity driven by the controller's reveal progress.
    property real fadeOpacity: 0.0       // 0..1
    // When false the whole handle is inert (zero-size hit target); used by the
    // "always" mode which must never swallow clicks near the edge.
    property bool active: true
    // Glass tint + outline matching the dock's own backdrop, so the hidden bar
    // reads as the same adaptive material. The owning window supplies the
    // theme colours; the backdrop blur (also owned by the window) adapts to
    // whatever is actually behind the bar.
    property color glassColor: "#b8ffffff"
    property color glassBorderColor: "#66ffffff"

    // ── Events ──
    signal entered()
    signal exited()
    signal clicked()

    // Exposed for the owning window's input mask: the (possibly zero-size)
    // hit area in window coordinates. The internal id is not visible outside
    // this component, so it is surfaced as a read-only alias.
    readonly property alias hitTarget: targetArea
    // The visible bar. It is a *direct* child of this handle (which sits at the
    // window origin), so its x/y already are surface coordinates — a blur region
    // can consume it without coordinate-space mapping.
    readonly property alias visualBar: bar
    // The pill filler, exposed only for diagnostics.
    readonly property alias visualPill: pill

    readonly property bool vertical: handle.position !== "bottom"
    readonly property real visualThickness: 8
    readonly property real hitThickness: 14
    readonly property real edgeInset: 6
    // Long edge is 50% of the matching screen dimension.
    readonly property real barLength: vertical
        ? Math.round(handle.screenHeight * 0.50)
        : Math.round(handle.screenWidth * 0.50)

    // ── Hit target geometry (in window/parent coordinates) ──
    // The hit area spans the FULL edge (side: full height, bottom: full width),
    // so moving the pointer anywhere along the screen edge reveals the hidden
    // dock — not just over the (hint-only) visual pill. The pill stays a 50%
    // centred indicator; only the input region is widened.
    readonly property real hitX: vertical
        ? (handle.position === "right" ? handle.windowWidth - handle.hitThickness : 0)
        : 0
    readonly property real hitY: vertical
        ? 0
        : (handle.windowHeight - handle.hitThickness)
    readonly property real hitW: handle.active
        ? (handle.vertical ? handle.hitThickness : handle.windowWidth) : 0
    readonly property real hitH: handle.active
        ? (handle.vertical ? handle.windowHeight : handle.hitThickness) : 0

    // ── Visual bar geometry ──
    readonly property real barX: vertical
        ? (handle.position === "right" ? handle.windowWidth - handle.edgeInset - handle.visualThickness : handle.edgeInset)
        : ((handle.windowWidth - handle.barLength) / 2)
    readonly property real barY: vertical
        ? ((handle.windowHeight - handle.barLength) / 2)
        : (handle.windowHeight - handle.edgeInset - handle.visualThickness)

    // Transparent hit target. opacity:0 items still hit-test, so HoverHandler
    // reacts exactly over the mask region the DockWindow grants it.
    Item {
        id: targetArea
        x: handle.hitX
        y: handle.hitY
        width: handle.hitW
        height: handle.hitH
        enabled: handle.active && handle.hitW > 0 && handle.hitH > 0
        visible: true
        opacity: 0

        HoverHandler {
            id: targetHover
            enabled: parent.enabled
            onHoveredChanged: {
                if (parent.enabled)
                    targetHover.hovered ? handle.entered() : handle.exited()
            }
        }
        TapHandler {
            enabled: parent.enabled
            onTapped: handle.clicked()
        }
    }

    // Visual pill. Scale grows slightly and colour brightens on hover.
    Item {
        id: bar
        x: handle.barX
        y: handle.barY
        // Long axis runs along the screen edge: full barLength wide on a bottom
        // dock, barLength tall on a side dock (visualThickness is the cross-edge
        // thickness in both cases).
        width: handle.vertical ? handle.visualThickness : handle.barLength
        height: handle.vertical ? handle.barLength : handle.visualThickness
        visible: handle.active && handle.visualThickness > 0
        opacity: handle.fadeOpacity

        scale: targetHover.hovered ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Rectangle {
            id: pill
            anchors.fill: parent
            // Explicit half-of-min-dimension so a WIDE bottom bar and a TALL
            // side bar both render a clean capsule. A magic huge radius
            // (999999) clamps to a pill for the wide case but the tall case
            // rounds in the wrong direction and gets clipped back to square.
            radius: Math.min(handle.visualThickness, handle.barLength) / 2
            color: handle.glassColor
            border { width: 1; color: handle.glassBorderColor }
        }
    }
}