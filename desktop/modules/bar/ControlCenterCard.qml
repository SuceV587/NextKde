import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.common

// A single control-center card as an independent PopupWindow.
//
// Each card owns a full-window RoundedBlurRegion, so KWin's per-window blur
// applies to this card alone (the compositor samples whatever is actually
// behind the window - wallpaper AND open windows). The plugin's
// smoothQuickshellCard path rounds the whole window with an SDF mask (no
// scanline aliasing), and the gaps between card windows show the real
// desktop underneath - the iOS "hollow" control center look.
//
// Positioning: every card anchors to the same transparent positioning popup.
// Quickshell therefore chooses the correct output from the original clicked
// item, while the card offsets remain in one stable local grid.
PopupWindow {
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
    // Window opacity would also fade compositor effects; fade the body only.
    property real cardOpacity: 1.0
    // Keep window geometry stable while scaling only the card content.
    property real cardScale: 1.0

    // ── Wire-up (set by the bar) ──
    required property QtObject coordinator
    // Cards managed by the coordinator open/close together. Set false for
    // overlays that manage their own visibility (e.g. logout confirmation).
    property bool managedByCoordinator: true
    property bool cardShown: false

    color: "transparent"
    grabFocus: false
    visible: root.cardShown && root.coordinator.cardAnchor !== null

    anchor {
        item: root.coordinator.cardAnchor
        // Treat the card's top-left as a point inside the positioning popup.
        rect.x: root.coordinator.gridWidth - root.offsetRight
            - root.cardWidth + root.coordinator.cardOffsetX
        rect.y: root.offsetTop + root.coordinator.cardOffsetY
        rect.width: 0
        rect.height: 0
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
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
        if (root.managedByCoordinator) {
            if (root.coordinator)
                root.coordinator.register(root)
        }
    }
}
