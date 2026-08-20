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
}
