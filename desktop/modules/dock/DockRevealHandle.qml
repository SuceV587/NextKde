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

    // ── Events ──
    signal entered()
    signal exited()
    signal clicked()

    // Exposed for the owning window's input mask: the (possibly zero-size)
    // hit area in window coordinates. The internal id is not visible outside
    // this component, so it is surfaced as a read-only alias.
    readonly property alias hitTarget: targetArea

    readonly property bool vertical: handle.position !== "bottom"
    readonly property real visualThickness: 4
    readonly property real hitThickness: 14
    readonly property real edgeInset: 6
    // Long edge is always 80% of the matching screen dimension.
    readonly property real barLength: vertical
        ? Math.round(handle.screenHeight * 0.80)
        : Math.round(handle.screenWidth * 0.80)

    // ── Hit target geometry (in window/parent coordinates) ──
    readonly property real hitX: vertical
        ? (handle.position === "right" ? handle.windowWidth - handle.hitThickness : 0)
        : ((handle.windowWidth - handle.barLength) / 2)
    readonly property real hitY: vertical
        ? ((handle.windowHeight - handle.barLength) / 2)
        : (handle.windowHeight - handle.hitThickness)
    readonly property real hitW: handle.active
        ? (handle.vertical ? handle.hitThickness : handle.barLength) : 0
    readonly property real hitH: handle.active
        ? (handle.vertical ? handle.barLength : handle.hitThickness) : 0

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
        width: handle.visualThickness
        height: handle.visualThickness
        visible: handle.active && handle.visualThickness > 0
        opacity: handle.fadeOpacity
        // Pill is drawn as a rectangle whose *long* axis maps to the edge; for
        // a side handle the hardware rectangle is vertical, so rotate the
        // filler by 90° to keep one reusable rounded rect.
        transform: Rotation {
            angle: handle.vertical ? 90 : 0
            origin.x: handle.visualThickness / 2
            origin.y: handle.visualThickness / 2
        }

        scale: targetHover.hovered ? 1.08 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

        Rectangle {
            id: pill
            anchors.fill: parent
            radius: 2
            color: targetHover.hovered
                ? "rgba(255, 255, 255, 0.94)"
                : "rgba(255, 255, 255, 0.72)"
            Behavior on color { ColorAnimation { duration: 120 } }

            // Thin dark shadow keeps the white bar legible on light wallpapers.
            layer.enabled: true
            layer.effect: MultiEffect {
                visible: true
                shadowEnabled: true
                shadowBlur: 0.5
                shadowVerticalOffset: 1
                shadowHorizontalOffset: 0
                shadowColor: Qt.rgba(0, 0, 0, 0.18)
                shadowScale: 1.0
                anchors.fill: parent
            }
        }
    }
}