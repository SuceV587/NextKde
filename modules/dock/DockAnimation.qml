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
    // ═══════════════════════════════════════════════════════════
    readonly property int dockResizeDuration: 280
    readonly property var dockResizeEasing:   Easing.OutCubic

    // ═══════════════════════════════════════════════════════════
    // Icon bounce-in (new window or pinned app appears)
    // SpringAnimation: overshoots then settles to 1.0
    // ═══════════════════════════════════════════════════════════
    readonly property int   iconBounceDuration:  450
    readonly property real  iconBounceSpring:    0.35    // damping  (lower = more bouncy)
    readonly property real  iconBounceVelocity:  0.40    // initial speed
    readonly property real  iconBounceOvershoot: 1.18    // visual peak scale

    // ═══════════════════════════════════════════════════════════
    // Icon hover magnification
    // ═══════════════════════════════════════════════════════════
    readonly property int   iconHoverDuration:  150
    readonly property real  iconHoverScale:     1.15
    readonly property var   iconHoverEasing:    Easing.OutCubic

    // ═══════════════════════════════════════════════════════════
    // Music player expand / collapse
    // ═══════════════════════════════════════════════════════════
    readonly property int   musicExpandDuration: 320
    readonly property var   musicExpandEasing:   Easing.InOutCubic

    // ═══════════════════════════════════════════════════════════
    // Running indicator pulse (dot under icon when window opens)
    // ═══════════════════════════════════════════════════════════
    readonly property int   indicatorPulseDuration: 500
    readonly property real  indicatorPulseScale:    1.5

    // ═══════════════════════════════════════════════════════════
    // Dock appearance / disappearance
    // ═══════════════════════════════════════════════════════════
    readonly property int   dockFadeDuration:   200
    readonly property var   dockFadeEasing:     Easing.InOutCubic
}
