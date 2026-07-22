import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.common

// ────────────────────────────────────────────────────────────────
// Dock.qml — macOS-style dock entry point.
//
// PanelWindow spans the full screen width (transparent) with a
// centered pill-shaped container hosting the adaptive layout.
// PanelWindow.x/y are NOT available — positioning is via anchors.
// ────────────────────────────────────────────────────────────────

PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Normal

    // Full-width bottom panel — content is centered internally
    anchors {
        left: true
        bottom: true
        right: true
    }
    margins {
        bottom: 5
    }

    // Height follows the adaptive container (implicitHeight preferred over height)
    implicitHeight: dockWrapper.height
    exclusiveZone: implicitHeight + 5

    // Glass only sees a Wayland surface, not the rounded QML Rectangle below.
    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: dockWrapper
        radius: dockContainer.pillRadius
    }

    // ═══════════════════════════════════════════════════════════
    // Centered wrapper (constrained to computed dock dimensions)
    // ═══════════════════════════════════════════════════════════
    Item {
        id: dockWrapper
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
        }
        width: dockContainer.computedDockWidth
        height: dockContainer.computedDockHeight

        // Pill-shaped glass background
        LiquidGlassSurface {
            anchors.fill: parent
            radius: dockContainer.pillRadius
            baseColor: ThemeService.backgroundColor
        }

        // Adaptive layout engine
        DockContainer {
            id: dockContainer
            anchors.centerIn: parent
        }
    }
}
