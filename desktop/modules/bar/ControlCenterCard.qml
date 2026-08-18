import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.common

// A single control-center card as an independent PanelWindow.
//
// Each card owns a full-window RoundedBlurRegion, so KWin's per-window blur
// applies to this card alone (the compositor samples whatever is actually
// behind the window - wallpaper AND open windows). The plugin's
// smoothQuickshellCard path rounds the whole window with an SDF mask (no
// scanline aliasing), and the gaps between card windows show the real
// desktop underneath - the iOS "hollow" control center look.
//
// Positioning: the card anchors to the top-right of the target screen and
// derives its exact position from the ControlCenterCoordinator's panel
// origin plus its own grid offset. This keeps all nine cards locked together
// when the bar moves.
PanelWindow {
    id: root

    // ── Grid position (relative to coordinator.panelTop / panelRight) ──
    // Vertical offset from the control center's top edge (logical px).
    property int offsetTop: 0
    // Horizontal offset from the control center's right edge (logical px,
    // negative = further left).
    property int offsetRight: 0
    // Corner radius for the blur region and the visual border.
    property real cardRadius: 19
    // Visual card fill (above the blur).
    property color cardColor: Qt.rgba(1, 1, 1, 0.10)
    property color cardBorderColor: Qt.rgba(1, 1, 1, 0.20)
    // PanelWindow has no opacity; this applies to the card body instead.
    property real cardOpacity: 1.0
    // PanelWindow has no scale; this applies to the card content.
    property real cardScale: 1.0

    // ── Wire-up (set by the bar) ──
    required property QtObject coordinator
    // Cards managed by the coordinator open/close together. Set false for
    // overlays that manage their own visibility (e.g. logout confirmation).
    property bool managedByCoordinator: true
    // Which output this card lives on (the same screen as the bar).
    property var targetScreen: Quickshell.screens.length > 1 ? Quickshell.screens[1] : Quickshell.screens[0]

    // Control-center cards get the same highlight family as the bar (cards
    // float over the bar's screen area).
    WlrLayershell.namespace: "quickshell-controlcenter"

    // Visible-state via position, NOT the window's `visible` flag.
    //
    // Quickshell submits the blur region when the window surface is created.
    // Toggling `visible` destroys/recreates the surface, so the first frame
    // after showing a card has NO region yet - KWin falls back to a full-window
    // rectangle, topInset=0 disables the smooth card path, and the card draws
    // a square slab for one frame before the region arrives. The dock avoids
    // this because it is always visible.
    //
    // Keeping the window always mapped and hiding/showing it by sliding its
    // top margin off/onto the screen keeps the blur region continuously
    // submitted, so every frame - including the first - rounds the corners.
    property bool cardShown: false

    screen: root.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; right: true }
    margins {
        // Off-screen (well above the display) while hidden; the real position
        // (panel origin + this card's grid offset) when shown.
        top: root.cardShown
            ? (root.coordinator ? root.coordinator.panelTop + root.offsetTop : 60 + root.offsetTop)
            : -2000
        // panelRight is the distance from the control center's right edge to
        // the screen's right edge (positive px). offsetRight is this card's
        // right edge to the control center's right edge. Sum = screen inset.
        right: Math.max(0, (root.coordinator ? root.coordinator.panelRight : 20) + root.offsetRight)
    }

    implicitWidth: root.cardWidth
    implicitHeight: root.cardHeight

    // Set by each concrete card.
    property int cardWidth: 296
    property int cardHeight: 59

    // The blur radius as an integer, shared by the region encoding AND the
    // cardBody radius so the plugin's SDF mask and the QML drawn shape always
    // coincide (a mismatch is what produced the visible double-edge aliasing).
    readonly property int blurRadius: Math.max(1, Math.min(
        Math.round(root.cardRadius),
        Math.floor(Math.min(root.cardWidth, root.cardHeight) / 2)))

    // Blur region with the radius encoded explicitly, instead of
    // RoundedBlurRegion's ellipse scanlines (whose top-row inset is corrupted
    // by DPR scaling, making the plugin recover a smaller radius than QML
    // draws). The top scanline starts at x=blurRadius - the plugin's
    // smoothQuickshellCard reads exactly this inset as the corner radius.
    // Everything below it is full-width so the card blurs completely and the
    // SDF mask rounds the corners to blurRadius.
    BackgroundEffect.blurRegion: Region {
        x: root.blurRadius
        y: 0
        width: root.cardWidth - root.blurRadius
        height: 1
        Region {
            x: 0
            y: 1
            width: root.cardWidth
            height: root.cardHeight - 1
        }
    }

    // Card surface: transparent (blur shows through) + subtle tint/border.
    // The radius MUST match blurRadius (the plugin's SDF mask), not the
    // original float cardRadius, or the two edges separate into a visible
    // aliased ring on small cards.
    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.blurRadius
        color: root.cardColor
        opacity: root.cardOpacity
        border.width: 1
        border.color: root.cardBorderColor

        // Concrete card content (declared by the card instance).
        default property alias content: contentHost.data
        Item {
            id: contentHost
            anchors.fill: parent
            scale: root.cardScale
        }
    }

    Component.onCompleted: {
        // Window stays mapped (visible: true) so the blur region is always
        // submitted; the coordinator shows/hides it via cardShown position.
        root.visible = true
        if (root.managedByCoordinator) {
            if (root.coordinator)
                root.coordinator.register(root)
        }
    }
}
