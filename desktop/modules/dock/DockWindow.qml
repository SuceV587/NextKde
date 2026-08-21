import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.applauncher
import qs.desktop.modules.dock
import qs.desktop.modules.common

// One concrete output-bound Dock layer surface.
//
// Hosts the DockAutoHideController (show-mode state machine) and slides the
// dock glass around within this single, permanently-mapped surface. Hiding
// never destroys the window, toggles visible, or changes anchors — it only
// moves dockWrapper via the controller's single reveal-progress-derived offset,
// and shapes the input region with a mask so transparent areas pass clicks
// through (docs/DockSmartHideDesign.md §9).
PanelWindow {
    id: root

    // Distinguish this surface from other quickshell panels so the glass
    // plugin can give it its own highlight direction.
    WlrLayershell.namespace: "quickshell-dock"
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top

    // ── Position-aware anchoring ──
    // The surface clings directly to the configured screen edge (margins = 0);
    // the 5px float moves inside as an inset on dockWrapper, and the reveal
    // handle tucks 6px inside the true edge, so the Home Indicator can sit
    // right at the physical edge while the glass keeps breathing room (§9.2).
    //
    // A bottom dock spans the full screen width; a side dock now spans the full
    // screen height (anchored top+bottom) so it can host the full-height reveal
    // handle, with the glass column vertically centred inside.
    //
    // position is a per-edge literal baked into the matching Component in
    // Dock.qml; switching edges recreates this window instead of patching a
    // live one, so the anchors below are final from the first commit.
    //
    // A bottom dock spans the full screen width (left+right) and hangs from the
    // bottom edge; a side dock spans the full screen height (top+bottom) on its
    // edge. Anchoring only top (without bottom) would let a side surface
    // collapse to the implicit thickness and become 0-height.
    property string position: "bottom"
    readonly property bool vertical: root.position === "left"
        || root.position === "right"
    readonly property int edgeMargin: 5

    anchors: ({
        top: root.vertical,
        bottom: true,
        left: root.position === "bottom" || root.position === "left",
        right: root.position === "bottom" || root.position === "right"
    })
    margins { left: 0; top: 0; right: 0; bottom: 0 }

    // Cross-edge thickness = glass + float. Length is forced by the anchors
    // (full screen along the anchored edge); these set the other dimension.
    implicitHeight: root.vertical ? 0 : dockContainer.height + root.edgeMargin
    implicitWidth: root.vertical ? dockContainer.width + root.edgeMargin : 0

    // ── Auto-hide controller ──
    // One controller per surface; inputs come from the singleton services and
    // the container's interaction state. It owns revealProgress, timers and
    // the reveal animation.
    DockAutoHideController {
        id: hide
        mode: ConfigService.visibilityMode
        configReady: ConfigService.ready
        windowDataReady: WindowService.providerReady
        position: root.position
        targetScreen: root.screen
        dockWidth: dockContainer.width
        dockHeight: dockContainer.height
        edgeMargin: root.edgeMargin
        pointerInsideDock: dockContainer.pointerInside
        editing: dockContainer.editMode
        dragging: dockContainer.draggedPinnedLoader !== null
        popupOpen: DockModelService.activeDockPopup !== null
        launcherOpen: AppLauncherService.open
    }

    // §9.3 Only "always" reserves a workspace strip. Hide modes keep the zone
    // at 0 so maximised windows do not reflow on every show/hide.
    exclusiveZone: ConfigService.visibilityMode === "always"
        ? (root.vertical
            ? dockContainer.width + root.edgeMargin
            : dockContainer.height + root.edgeMargin)
        : 0

    BackgroundEffect.blurRegion: Region {
        RoundedBlurRegion {
            id: glassRegion
            item: dockWrapper
            radius: dockContainer.pillRadius
        }
        RoundedBlurRegion {
            id: barRegion
            // visualBar is a direct child of the handle at the window origin, so
            // its x/y are already surface coords (no mapToItem, which evaluates
            // stale before layout and parked the region at the corner).
            item: revealHandle.visualBar
            // Explicit half-minimum so the frosted halo matches the pill's own
            // capsule (a magic 999999 rounds wide bars but squars tall side
            // bars before clipping).
            radius: Math.min(revealHandle.visualThickness,
                revealHandle.barLength) / 2
        }
    }

    // Stable, full-reveal position of the glass inside the surface. Always
    // derived from surface/container size — never the animated transform.
    readonly property real restX: root.vertical
        ? (root.position === "right"
            ? root.width - root.edgeMargin - dockContainer.width
            : root.edgeMargin)
        : (root.width - dockContainer.width) / 2
    readonly property real restY: root.vertical
        ? (root.height - dockContainer.height) / 2
        : root.height - root.edgeMargin - dockContainer.height

    Item {
        id: dockWrapper
        // Slide along toward the edge as revealProgress reaches 0. The mask
        // region (dockHitRegion) shares these exact coordinates so input tracks
        // the moving glass.
        x: hide.offsetX + root.restX
        y: hide.offsetY + root.restY
        width: dockContainer.width
        height: dockContainer.height
        opacity: hide.dockOpacity
        scale: hide.dockScale
        transformOrigin: root.vertical
            ? (root.position === "right" ? Item.Right : Item.Left)
            : Item.Bottom

        DockContainer {
            id: dockContainer
            targetScreen: root.screen
        }
    }

    // Input mask mirror for the dock glass. Invisible; its geometry equals
    // dockWrapper's (including the hide offset). Keeping it a sibling (rather
    // than using dockWrapper directly) lets the mask region move independently
    // of the visual wrapper (opacity/scale) while still matching its area.
    Item {
        id: dockHitRegion
        x: hide.offsetX + root.restX
        y: hide.offsetY + root.restY
        width: dockContainer.width
        height: dockContainer.height
        visible: false
    }

    // White Home Indicator + pointer hit target, parked at the true screen edge.
    DockRevealHandle {
        id: revealHandle
        position: root.position
        windowWidth: root.width
        windowHeight: root.height
        screenWidth: root.screen?.width ?? 0
        screenHeight: root.screen?.height ?? 0
        fadeOpacity: hide.handleOpacity
        // Same adaptive material as the dock glass: the theme-driven tint plus
        // the backdrop blur (below) frost whatever is actually behind the bar,
        // so it stays visible on both light and dark backgrounds.
        glassColor: ThemeService.backgroundColor
        glassBorderColor: ThemeService.borderColor
        active: hide.handleActive
        onEntered: hide.handleEntered()
        onExited: hide.handleExited()
        onClicked: hide.handleClicked()
    }

    // §5.8: a window becoming urgent (non-fullscreen) temporarily reveals the
    // dock for 2200ms; the temp-clear handler then re-evaluates per show mode.
    Connections {
        target: DockModelService
        function onUrgentWindowAppeared() {
            hide.requestReveal("urgent", DockAnimation.smartHideUrgentRevealMs)
        }
    }

    // Shape the input region to the moving dock glass + the reveal handle hit
    // target (union). Everything else in this transparent surface passes clicks
    // through. In "always" mode the handle target collapses to zero.
    mask: Region {
        Region { item: dockHitRegion }
        Region { item: revealHandle.hitTarget }
    }
}