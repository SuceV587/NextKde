pragma Singleton
import QtQuick

// ────────────────────────────────────────────────────────────────
// DockAnimation — Central animation configuration.
// Every timing constant, easing curve, and spring parameter lives
// here. Components reference these values; nothing is hardcoded.
//
// Design philosophy: natural, physics-informed motion.
// No gratuitous flourishes — every animation has a purpose.
// ────────────────────────────────────────────────────────────────

QtObject {
    id: svc

    // ═══════════════════════════════════════════════════════════
    // Dock resize (triggered by window open/close, music appear)
    // OutCubic: fast start, soft stop. InCubic's slow start was rejected by
    // A/B test — it reads as "creeping" even at 100ms.
    // ═══════════════════════════════════════════════════════════
    readonly property int   dockResizeDuration: 100
    readonly property var   dockResizeEasing:   Easing.OutCubic

    // ═══════════════════════════════════════════════════════════
    // Icon hover magnification
    // ═══════════════════════════════════════════════════════════
    // Hover is an explicit pointer affordance: the icon lifts and grows while
    // its layout slot remains unchanged, so adaptive Dock geometry is stable.
    readonly property int   iconHoverDuration:  135
    readonly property real  iconHoverScale:     1.20
    readonly property var   iconHoverEasing:    Easing.OutCubic

    // ═══════════════════════════════════════════════════════════
    // Music player expand / collapse
    // ═══════════════════════════════════════════════════════════
    readonly property int   musicExpandDuration: 320
    readonly property var   musicExpandEasing:   Easing.InOutCubic

    // ═══════════════════════════════════════════════════════════
    // Dock appearance / disappearance
    // ═══════════════════════════════════════════════════════════
    readonly property int   dockFadeDuration:   200
    readonly property var   dockFadeEasing:     Easing.InOutCubic

    // ═══════════════════════════════════════════════════════════
    // Directional motion semantics (Material-inspired, same idea as
    // end-4/dots-hyprland): entering elements decelerate into place
    // (fast start, soft settle), exiting elements accelerate away
    // (slow start, quick departure). Use these in explicit animations
    // that have a direction — not on two-way Behaviors.
    // ═══════════════════════════════════════════════════════════
    readonly property var elementEnterEasing: Easing.OutCubic
    readonly property var elementExitEasing:  Easing.InCubic

    // ═══════════════════════════════════════════════════════════
    // Dock show-mode (smart auto-hide / persistent) timings.
    // Times and curves are tuned constants consumed by the auto-hide
    // controller; nothing is scattered into UI components. See
    // docs/DockSmartHideDesign.md §6.2.
    // ═══════════════════════════════════════════════════════════
    readonly property int   smartHideConflictDelay:   320   // first window-overlap debounce
    readonly property int   smartHideModeSwitchGrace: 700   // persistent switch confirmation period
    readonly property int   smartHideLeaveDelay:      520   // pointer/inhibitor-all-cleared leave
    readonly property int   smartHideHoverShowDelay:   90   // handle hover reveal threshold
    readonly property int   smartHideHideDuration:    220
    readonly property int   smartHideRevealDuration:  260
    readonly property var   smartHideHideEasing:      Easing.InCubic
    readonly property var   smartHideRevealEasing:    Easing.OutCubic
    readonly property int   smartHideBootWaitLimit:    450   // max wait for config+KWin snapshot
    readonly property int   smartHideMinRemaining:      70   // floor for reversible animation
    // A transparent 1px layer-shell margins reparenting of the dock content to
    // the true screen edge: the white reveal handle sits this far (dp) from the
    // physical edge whereas the dock glass keeps edgeMargin-1 breathing room.
    readonly property real  smartHideHandleEdgeInset:  6
}
