import Quickshell
import QtQuick

// Shared owner for the per-card control-center windows.
//
// The control center is nine independent PanelWindows (one per card) so each
// card gets its own compositor-level blur (see ControlCenterCard.qml). Without
// one shared owner those windows fight over placement and focus - the same
// problem the dock solved with DockModelService.activeDockPopup. This object
// is the single place that knows:
//   - where the control center sits on screen (derived from the bar toggle),
//   - which cards exist and their grid offsets,
//   - whether the whole control center is open.
//
// Cards bind their window margins to panelTop/panelRight so the whole group
// moves together when the bar layout changes.
QtObject {
    id: coordinator

    // ── Screen geometry (updated by the bar) ──
    // Top of the control center, relative to the top edge of the target
    // screen (logical pixels). Derived from the bar toggle's position.
    property int panelTop: 60
    // Distance from the control center's RIGHT edge to the screen's right
    // edge (logical pixels). Positive = inset from the right edge.
    property int panelRight: 20
    // Side-Dock fusion mirrors the card grid from the screen's left edge.
    // Bottom/right hosts keep the established top-right placement.
    property bool anchorLeft: false

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
