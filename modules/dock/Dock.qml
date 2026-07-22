import Quickshell
import Quickshell.Wayland
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

    // Glass only sees a Wayland surface, not the rounded QML Rectangle below.
    // Describe the pill explicitly: two crossing rectangles plus four circles
    // form the same rounded rectangle as dockContainer.pillRadius.
    readonly property int glassRadius: Math.max(0, Math.min(dockContainer.pillRadius, Math.floor(dockWrapper.height / 2)))
    BackgroundEffect.blurRegion: Region {
        // Vertical center of the pill.
        x: Math.round(dockWrapper.x + root.glassRadius)
        y: Math.round(dockWrapper.y)
        width: Math.max(0, Math.round(dockWrapper.width - root.glassRadius * 2))
        height: Math.round(dockWrapper.height)

        // Horizontal center.
        Region {
            x: Math.round(dockWrapper.x)
            y: Math.round(dockWrapper.y + root.glassRadius)
            width: Math.round(dockWrapper.width)
            height: Math.max(0, Math.round(dockWrapper.height - root.glassRadius * 2))
        }

        // The four corners complete the exact rounded outline.
        Region {
            x: Math.round(dockWrapper.x)
            y: Math.round(dockWrapper.y)
            width: root.glassRadius * 2
            height: root.glassRadius * 2
            shape: RegionShape.Ellipse
        }
        Region {
            x: Math.round(dockWrapper.x + dockWrapper.width - root.glassRadius * 2)
            y: Math.round(dockWrapper.y)
            width: root.glassRadius * 2
            height: root.glassRadius * 2
            shape: RegionShape.Ellipse
        }
        Region {
            x: Math.round(dockWrapper.x)
            y: Math.round(dockWrapper.y + dockWrapper.height - root.glassRadius * 2)
            width: root.glassRadius * 2
            height: root.glassRadius * 2
            shape: RegionShape.Ellipse
        }
        Region {
            x: Math.round(dockWrapper.x + dockWrapper.width - root.glassRadius * 2)
            y: Math.round(dockWrapper.y + dockWrapper.height - root.glassRadius * 2)
            width: root.glassRadius * 2
            height: root.glassRadius * 2
            shape: RegionShape.Ellipse
        }
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
        Rectangle {
            anchors.fill: parent
            radius: dockContainer.pillRadius
            color: ThemeService.backgroundColor
            border {
                width: 2
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
