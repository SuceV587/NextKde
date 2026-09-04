import QtQuick
import qs.desktop.modules.common

// Shared owner for the per-card control-center windows.
//
// The control center is nine independent popup surfaces (one per card) so each
// card gets its own compositor-level blur (see ControlCenterCard.qml). Without
// one shared owner those windows fight over placement and focus - the same
// problem the dock solved with DockModelService.activeDockPopup. This object
// is the single place that knows:
//   - the shared popup-anchor coordinate space,
//   - which cards exist and their grid offsets,
//   - whether the whole control center is open.
//
// Cards anchor to one transparent positioning popup, so Quickshell resolves
// the output and edge placement once for the whole group.
QtObject {
    id: coordinator

    property Item cardAnchor: null
    property int gridWidth: 336
    // Shift the card grid away from the Dock edge while preserving the
    // original anchor's output selection and compositor clamping.
    property int cardOffsetX: 0
    property int cardOffsetY: 0

    // ── Registered cards ──
    property var cards: []

    function register(card) {
        if (cards.indexOf(card) === -1) {
            cards.push(card)
            // If the group is already open (cards registered after openAll,
            // e.g. during startup), join the shared animation state.
            if (open && !card.cardShown)
                card.cardShown = true
        }
    }

    // ── Open / close ──
    property bool open: false
    property bool modalActive: false
    readonly property real motionProgress: _motion.progress
    readonly property bool motionMapped: _motion.mapped
    readonly property bool motionInteractive: _motion.interactive

    function openAll() {
        open = true
        for (const card of cards)
            card.cardShown = true
        _motion.open()
    }

    function closeAll() {
        open = false
        modalActive = false
        _motion.close()
    }

    property PopupMotion _motion: PopupMotion {
        onClosed: {
            if (!coordinator.open) {
                for (const card of coordinator.cards)
                    card.cardShown = false
            }
        }
    }
}
