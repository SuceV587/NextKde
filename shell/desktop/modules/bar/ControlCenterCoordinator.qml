import Quickshell
import QtQuick

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
            // e.g. during startup), pick up the cascade so this card appears.
            if (open && !card.cardShown)
                card.cardShown = true
        }
    }

    // ── Open / close ──
    // Opening cascades the card windows onto the screen one after another so
    // the compositor doesn't have to map nine surfaces in one frame (which
    // causes churn/flicker) and the entrance reads as a subtle cascade.
    property bool open: false
    property bool suspended: false
    property int _openingIndex: -1

    function openAll() {
        open = true
        // Sort by vertical position so the cascade always runs top-to-bottom
        // (iOS control center), regardless of QML declaration order. The
        // notification history card (bottom) must appear last.
        cards.sort((a, b) => a.offsetTop - b.offsetTop)
        _openingIndex = 0
        _cascadeCard()
    }

    function closeAll() {
        open = false
        suspended = false
        _openingIndex = -1
        for (const card of cards)
            card.cardShown = false
    }

    function _cascadeCard() {
        if (!open || _openingIndex >= cards.length) {
            _openingIndex = -1
            return
        }
        const card = cards[_openingIndex]
        if (card)
            card.cardShown = true
        _openingIndex++
        _cascadeTimer.start()
    }

    property Timer _cascadeTimer: Timer {
        interval: 12
        repeat: false
        onTriggered: coordinator._cascadeCard()
    }
}
