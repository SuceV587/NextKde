import Quickshell
import QtQuick

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
        Rectangle {
            anchors.fill: parent
            radius: dockContainer.pillRadius
            color: ThemeService.backgroundColor
            border {
                width: 0.8
                color: ThemeService.borderColor
            }
        }

        // Adaptive layout engine
        DockContainer {
            id: dockContainer
            anchors.centerIn: parent
        }
    }
}
