import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.common

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

    screen: root.targetScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; right: true }
    margins {
        top: root.coordinator ? root.coordinator.panelTop + root.offsetTop : 60 + root.offsetTop
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

    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: cardBody
        radius: root.cardRadius
    }

    // Card surface: transparent (blur shows through) + subtle tint/border.
    Rectangle {
        id: cardBody
        anchors.fill: parent
        radius: root.cardRadius
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
            // Start hidden; the coordinator opens the group.
            root.visible = false
        }
    }
}
