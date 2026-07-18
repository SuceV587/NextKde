pragma Singleton
import QtQuick
import Quickshell.Services.Mpris

// ────────────────────────────────────────────────────────────────
// DockMprisService — Wraps MPRIS2 players.
//
// Uses a hidden Repeater to capture MprisPlayer references since
// Quickshell's UntypedObjectModel doesn't support .get(index).
// The Repeater delegate stores each player in a JS array.
// ────────────────────────────────────────────────────────────────

QtObject {
    id: svc

    // ── Active player ──
    property MprisPlayer activePlayer: null
    property bool hasPlayer: activePlayer !== null

    // ── Player tracking via Repeater ──
    property var _playerRefs: []

    // Hidden Repeater — one delegate per MPRIS player, captures the
    // actual MprisPlayer QObject via modelData into _playerRefs.
    property Repeater _playerRepeater: Repeater {
        model: Mpris.players
        delegate: Item {
            id: delegate
            readonly property MprisPlayer player: modelData
            Component.onCompleted: {
                const refs = svc._playerRefs
                refs.push(player)
                svc._playerRefs = refs  // trigger change notification
                svc._updateActivePlayer()
            }
            Component.onDestruction: {
                const refs = svc._playerRefs.filter(p => p !== player)
                svc._playerRefs = refs
                svc._updateActivePlayer()
            }
        }
    }

    // ── Select the best active player ──
    // Priority: playing > paused > any > none
    function _updateActivePlayer() {
        const refs = svc._playerRefs
        if (!refs || refs.length === 0) {
            activePlayer = null
            return
        }

        // 1. Prefer a playing player
        for (let i = 0; i < refs.length; i++) {
            const p = refs[i]
            if (p && p.isPlaying) {
                activePlayer = p
                return
            }
        }

        // 2. Fall back to a paused player
        for (let i = 0; i < refs.length; i++) {
            const p = refs[i]
            if (p && p.playbackState === MprisPlaybackState.Paused) {
                activePlayer = p
                return
            }
        }

        // 3. Any player
        activePlayer = refs[0] || null
    }

    // ── Playback helpers ──
    function togglePlayPause() {
        if (!activePlayer) return
        if (activePlayer.isPlaying) {
            activePlayer.pause()
        } else {
            activePlayer.play()
        }
    }

    function next() {
        activePlayer?.next()
    }

    function previous() {
        activePlayer?.previous()
    }

    // ── React to the active player's state changes ──
    property Connections _playerStateConn: Connections {
        target: svc.activePlayer
        enabled: svc.activePlayer !== null
        function onPlaybackStateChanged() { svc._updateActivePlayer() }
        function onReadyChanged()         { svc._updateActivePlayer() }
    }
}
