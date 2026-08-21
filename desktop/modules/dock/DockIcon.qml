import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.desktop.modules.common
import qs.desktop.modules.applauncher

// ────────────────────────────────────────────────────────────────
// DockIcon — Single icon in the dock.
// Used for both pinned launcher icons and open window icons.
//
// Hover: gentle NumberAnimation via Behavior.
// ────────────────────────────────────────────────────────────────

Item {
    id: icon

    // ═══════════════════════════════════════════════════════════
    // Inputs
    // ═══════════════════════════════════════════════════════════
    property int    iconSize:    44
    property string iconSource:  ""
    // Optional bundled-font glyph for shell controls. Unlike a themed icon
    // name it is guaranteed to render even when the active KDE theme lacks it.
    property string glyph:       ""
    property string displayName: ""
    property string appId:       ""
    property string windowId:    ""
    // `isRunning` is visual runtime state. `isWindowItem` identifies which
    // context-menu actions are valid, because a pinned running app has no
    // single windowId even though it displays a running indicator.
    property bool   isWindowItem: false
    // A non-window item can be either a fixed launcher or an unpinned running
    // app aggregate. The context menu needs this distinction for pin/unpin.
    property bool   isPinnedItem: false
    // A visual-only DockIcon (the fixed application launcher) deliberately
    // shares sizing and rendering with tasks without exposing task actions.
    property bool   interactive: true
    // Any normal Dock task is an interaction outside the launcher sheet and
    // should dismiss it first. The fixed launcher icon opts out so it can
    // keep its expected toggle behavior.
    property bool   dismissAppLauncherOnInteraction: true
    // Shell controls can use the standard left-click activation pipeline while
    // opting out of application-specific right-click context-menu actions.
    property bool   showContextMenu: true
    // Fixed shell controls can keep DockIcon's complete visual/hover behavior
    // while routing their right click to a dedicated native menu.
    property bool   customContextMenu: false
    // The fixed launcher is not a persisted pinned app, so holding it must not
    // enter the pinned-app edit/reorder state.
    property bool   allowEdit: true
    property bool   isRunning:   false
    property bool   isActivated: false
    // Urgency is independent from activation. A window requesting attention
    // paints an orange-red slot until the compositor clears that state.
    property bool   isUrgent:    false
    // Pinned delegates enable this while a sibling is being dragged. Window
    // icons intentionally leave it false.
    property bool   editMode: false
    property bool   isDragging: false
    // A small neutral marker for persistent shell-control state, currently
    // used by the Trash icon while it contains recoverable items.
    property bool   statusBadge: false
    // This is proportional to iconSize (3px when iconSize is 44px). It is
    // also included in AdaptiveMath, so the active background never overlaps
    // a neighbour or makes the real Row wider than the calculated width.
    property real   activeBackgroundGap: 4.4
    // Side-dock layout: the whole row is rotated 90 degrees; the icon image
    // counter-rotates so the artwork stays upright.
    property bool   vertical: false
    // Which screen edge the dock is attached to: "bottom", "left" or
    // "right". The running dot sits on the icon edge facing that edge —
    // below the icon on a bottom dock, on the screen-edge side of side docks.
    property string dockEdge: "bottom"
    // Active task backgrounds are painted locally for reliability.
    // The shared indicator approach caused coordinate bugs during layout changes.
    property bool   useSharedActiveBackground: false

    // Active background radius is proportional to the icon height. This is
    // intentionally independent from the icon/background gap.
    readonly property real activeBackgroundRadius: iconSize * 0.3
    readonly property real iconSlotSize: iconSize + activeBackgroundGap * 2
    // macOS running indicator geometry. The dot floats centred between the
    // icon edge and the dock panel edge: 0.20 is the vertical panel padding
    // ratio (vpad), so the dot occupies the midpoint of that gap.
    readonly property real runningDotSize: Math.max(4,
        Math.round(iconSize * 0.13))
    readonly property real runningDotGap: Math.max(1,
        (iconSize * 0.20 - runningDotSize) / 2)
    readonly property real activeBackgroundAlpha: ConfigService.iconMode === "color" ? 0.5 : Math.max(0.1, ConfigService.iconOpacity)
    readonly property bool showActiveBackground: isRunning && isActivated
    readonly property bool showUrgentBackground: isRunning && isUrgent
        && !showActiveBackground

    signal activate()
    signal requestEdit()
    signal contextRequested()
    property bool _heldForEdit: false

    // Reserve the background's outer slot for every app icon. Only the active
    // window paints it; reserving the slot prevents focus changes from moving
    // the surrounding icons.
    width:  iconSlotSize
    height: iconSlotSize
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // ═══════════════════════════════════════════════════════════
    // Scale model
    // ═══════════════════════════════════════════════════════════
    // Final scale: 1.0 (or larger on hover).
    property real _targetScale: _hovering ? DockAnimation.iconHoverScale : 1.0
    // Lift non-focused tasks to make pointer feedback unmistakable. The active
    // task keeps its shared background vertically stable, while scale alone
    // still makes its hover state clear.
    readonly property real _hoverLift: _hovering && !showActiveBackground
        ? -Math.max(2, Math.round(iconSize * 0.08)) : 0
    property real _attentionScale: 1.0
    property real _attentionLift: 0
    property real _attentionGlow: 0
    scale: _targetScale * _attentionScale
    // The icon artwork is cached in `iconImage`/`GlassText` below instead of
    // on this whole item: an offscreen texture is sized to the item's bounds
    // and clips overflow, which would hide the running/status indicators
    // that deliberately extend past the icon edge.
    transform: Translate {
        y: icon._hoverLift + icon._attentionLift
        Behavior on y {
            NumberAnimation {
                duration: DockAnimation.iconHoverDuration
                easing.type: DockAnimation.iconHoverEasing
            }
        }
    }

    function acknowledgeAttention() {
        _attentionScale = 1.0
        _attentionLift = 0
        _attentionGlow = 0
        attentionPulse.restart()
    }
    SequentialAnimation {
        id: attentionPulse
        ParallelAnimation {
            NumberAnimation { target: icon; property: "_attentionScale"; to: 1.18; duration: 115; easing.type: Easing.OutCubic }
            NumberAnimation { target: icon; property: "_attentionLift"; to: -6; duration: 115; easing.type: Easing.OutCubic }
            NumberAnimation { target: icon; property: "_attentionGlow"; to: 1.0; duration: 115; easing.type: Easing.OutCubic }
        }
        ParallelAnimation {
            NumberAnimation { target: icon; property: "_attentionScale"; to: 1.0; duration: 210; easing.type: Easing.OutBack }
            NumberAnimation { target: icon; property: "_attentionLift"; to: 0; duration: 210; easing.type: Easing.OutBounce }
            NumberAnimation { target: icon; property: "_attentionGlow"; to: 0; duration: 210; easing.type: Easing.OutCubic }
        }
    }

    // ── Hover animation ──
    property bool _hovering: false
    readonly property string _previewWindowId: {
        // Pinned items may represent several windows. Start with the first;
        // standalone window items already carry the exact ID.
        WindowService.revision
        if (icon.windowId)
            return icon.windowId
        const windows = WindowService.windowsForApp(icon.appId)
        return windows.length > 0 ? windows[0].windowId : ""
    }
    Behavior on scale {
        NumberAnimation {
            duration: DockAnimation.iconHoverDuration
            easing.type: DockAnimation.iconHoverEasing
        }
    }

    Timer {
        id: previewDelay
        // Previews are intentionally deliberate: only a 1s dwell opens
        // one, so ordinary pointer travel across the Dock remains quiet.
        interval: 1000
        repeat: false
        onTriggered: {
            // A context menu owns the interaction for its icon. Do not let a
            // hover timer replace it with a preview while the pointer moves
            // between Dock icons to open another menu.
            if (icon._hovering && icon._previewWindowId && !icon.editMode
                    && !DockModelService.activeContextMenu) {
                console.log("[DockIcon] preview request app=" + icon.appId
                    + " window=" + icon._previewWindowId);
                preview.windowId = icon._previewWindowId
                preview.title = WindowService.windowById(icon._previewWindowId)?.title
                    ?? icon.displayName
                // A thumbnail takes precedence over the context menu. Keeping
                // both surfaces open would make their pointer/focus behavior
                // ambiguous, especially when moving upward from the Dock.
                DockModelService.openDockPopup(preview)
            } else if (icon._hovering && icon.isRunning) {
                console.log("[DockIcon] preview skipped app=" + icon.appId
                    + " no window record")
            }
        }
    }

    // The preview is a separate Wayland surface. Leave a small hand-off window
    // after the pointer exits the icon so it can cross the anchor gap and enter
    // the preview instead of the preview vanishing mid-move.
    Timer {
        id: previewCloseDelay
        interval: 240
        repeat: false
        onTriggered: {
            if (!icon._hovering && !preview.pointerInside)
                DockModelService.setDockPopupVisible(preview, false)
        }
    }

    // iPadOS-style edit-state wiggle. The held icon stays steady so it reads
    // as the object under direct manipulation rather than a background item.
    SequentialAnimation {
        id: editWiggle
        running: icon.editMode && !icon.isDragging
        loops: Animation.Infinite
        NumberAnimation {
            target: icon; property: "rotation"
            from: -3.4; to: 3.4; duration: 105
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: icon; property: "rotation"
            from: 3.4; to: -3.4; duration: 115
            easing.type: Easing.InOutSine
        }
        onRunningChanged: {
            if (!running)
                icon.rotation = 0
        }
    }

    // ═══════════════════════════════════════════════════════════
    // Icon image
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: activeBackground
        width: icon.iconSlotSize
        height: icon.iconSlotSize
        anchors.centerIn: parent
        radius: icon.activeBackgroundRadius
        // The active window paints a white slot; urgency paints orange-red.
        // Both are local to the icon, so the highlight always tracks its task
        // without any shared indicator or geometry tracking.
        color: icon.showActiveBackground
            ? Qt.rgba(1, 1, 1, icon.activeBackgroundAlpha)
            : Qt.rgba(1.0, 0.30, 0.12, icon.activeBackgroundAlpha)
        visible: (icon.showActiveBackground && !icon.useSharedActiveBackground)
            || icon.showUrgentBackground
        z: -1
        Behavior on color {
            ColorAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
    }

    // External shell actions need feedback that stays visible even when the
    // Dock's internal scale transform is constrained by its layout. This ring
    // is a separate painted layer behind the icon.
    Rectangle {
        width: icon.iconSlotSize * 1.28
        height: width
        anchors.centerIn: parent
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.72)
        opacity: icon._attentionGlow * 0.48
        scale: 0.80 + icon._attentionGlow * 0.35
        visible: opacity > 0
        z: -2
    }

    // A faint white slot gives hover a little contrast on liquid glass without
    // changing the icon's reserved geometry. Focused and urgent tasks already
    // have stronger state backgrounds, so they intentionally do not stack it.
    Rectangle {
        id: hoverHighlight
        width: icon.iconSize
        height: icon.iconSize
        anchors.centerIn: parent
        radius: icon.iconSize * 0.30
        color: Qt.rgba(1, 1, 1, 0.12)
        opacity: icon._hovering && !icon.showActiveBackground
            && !icon.showUrgentBackground ? 1.0 : 0.0
        visible: opacity > 0.0
        z: -1

        Behavior on opacity {
            NumberAnimation {
                duration: DockAnimation.iconHoverDuration
                easing.type: DockAnimation.iconHoverEasing
            }
        }
    }

    // A brief brightening on press gives tactile feedback without any
    // geometry work: pure opacity on the already-cached icon layer. The
    // fade uses directional semantics — decelerate on press, accelerate on
    // release — so the feedback reads as push in / relax out.
    Rectangle {
        id: pressHighlight
        width: icon.iconSize
        height: icon.iconSize
        anchors.centerIn: parent
        radius: icon.iconSize * 0.30
        color: Qt.rgba(1, 1, 1, 0.12)
        opacity: 0.0
        visible: opacity > 0.0
        z: -1
    }
    NumberAnimation {
        id: pressFadeIn
        target: pressHighlight
        property: "opacity"
        to: 1.0
        duration: 150
        easing.type: DockAnimation.elementEnterEasing
    }
    NumberAnimation {
        id: pressFadeOut
        target: pressHighlight
        property: "opacity"
        to: 0.0
        duration: 150
        easing.type: DockAnimation.elementExitEasing
    }

    AppIcon {
        id: iconImage
        width: icon.iconSize
        height: icon.iconSize
        anchors.centerIn: parent
        source: icon.iconSource || ""
        visible: !icon.glyph
        rotation: icon.vertical ? -90 : 0
        transformOrigin: Item.Center
        // Cache the icon bitmap so scale animations (hover, attention pulse)
        // transform a cached texture instead of re-rasterizing the image on
        // the main thread (measured 100% CPU under the heaviest scale
        // animation; 4.8% with the layer enabled). Only the artwork itself
        // is layered: the texture is sized to this item's bounds, so caching
        // the whole DockIcon would clip the indicators past its edges.
        layer.enabled: true
        layer.smooth: true
        
        // Icon appearance style from ConfigService
        opacityMultiplier: ConfigService.iconMode === "color" ? 1.0 : ConfigService.iconOpacity
        saturation: ConfigService.iconSaturation
        tintEnabled: ConfigService.iconTintEnabled
        tintColor: ConfigService.iconTintColor
    }

    Rectangle {
        width: Math.max(5, Math.round(icon.iconSize * 0.15))
        height: width
        anchors { right: parent.right; top: parent.top; rightMargin: 2; topMargin: 2 }
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.88)
        border { width: 1; color: Qt.rgba(0, 0, 0, 0.48) }
        opacity: icon.statusBadge ? 1 : 0
        visible: opacity > 0.01
        z: 2
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    // macOS-style running indicator: a small dot on the icon edge facing the
    // docked screen edge (below on a bottom dock, on the screen-edge side of
    // side docks). The content row rotates 90° clockwise on side docks, which
    // maps the unrotated *bottom* edge to the screen-left side of the
    // counter-rotated icon and the *top* edge to its screen-right side.
    // The dot sits *outside* the icon edge with a breathing gap: anchor its
    // far side to the icon edge so the margin pushes it away, never inside.
    Rectangle {
        id: runningIndicator
        width: icon.runningDotSize
        height: icon.runningDotSize
        radius: width / 2
        color: Qt.rgba(1, 1, 1, 0.95)
        border { width: 1; color: Qt.rgba(0, 0, 0, 0.40) }
        opacity: icon.isRunning ? 1 : 0
        visible: opacity > 0.01
        z: 2
        anchors.horizontalCenter: iconImage.horizontalCenter
        // Right dock: the dot's far (bottom) edge touches the icon's top
        // edge, placing the dot above it — rendered on the screen-right
        // side of the icon. All other docks: the dot's near (top) edge
        // touches the icon's bottom edge, placing the dot below it.
        anchors.top: icon.vertical && icon.dockEdge === "right"
            ? undefined : iconImage.bottom
        anchors.bottom: icon.vertical && icon.dockEdge === "right"
            ? iconImage.top : undefined
        anchors.topMargin: icon.runningDotGap
        anchors.bottomMargin: icon.runningDotGap
        Behavior on opacity {
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
        }
    }

    GlassText {
        anchors.centerIn: parent
        text: icon.glyph
        visible: !!icon.glyph
        rotation: icon.vertical ? -90 : 0
        transformOrigin: Item.Center
        color: Qt.rgba(1, 1, 1, 0.92)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font {
            family: "Font Awesome 7 Free"
            pixelSize: Math.round(icon.iconSize * 0.58)
            weight: Font.Black
        }
        // Same cached-texture rationale as iconImage: glyph text is expensive
        // to re-rasterize under scale animation.
        layer.enabled: true
        layer.smooth: true
    }
    // The active/hover-style background already communicates the focused
    // running app, so no separate running marker is painted.

    // ═══════════════════════════════════════════════════════════
    // Interaction
    // ═══════════════════════════════════════════════════════════
    MouseArea {
        id: _mouseArea
        anchors.fill: parent
        enabled: icon.interactive
        hoverEnabled: true
        acceptedButtons: (icon.showContextMenu || icon.customContextMenu)
            ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        // Normal clicks stay owned by the icon.  Once a long press enables dock
        // edit mode, let the parent DragHandler take the pointer to reorder
        // pinned apps; otherwise the wiggle animation starts but dragging cannot.
        preventStealing: !icon.editMode
        cursorShape: Qt.PointingHandCursor
        onPressed: {
            icon._heldForEdit = false
            if (icon.dismissAppLauncherOnInteraction && AppLauncherService.open)
                AppLauncherService.hide()
            pressFadeIn.start()
        }
        onReleased: pressFadeOut.start()
        onCanceled: pressFadeOut.start()
        onPressAndHold: {
            if (!icon.allowEdit)
                return
            // Entering edit mode steals the pointer for reordering; the press
            // feedback should not linger while the icon wiggles.
            pressFadeOut.start()
            icon._heldForEdit = true
            icon.requestEdit()
        }
        onClicked: function(mouse) {
            // Persistent Dock editing is spatial manipulation, not app
            // activation. A tap on a pinned icon during this mode must remain
            // harmless so users can place several icons before tapping away.
            if (icon.editMode)
                return
            if (mouse.button === Qt.RightButton) {
                if (icon.customContextMenu) {
                    icon.contextRequested()
                    return
                }
                // A delayed preview may already be armed from pointer entry.
                // Right-click is a distinct interaction and must own the
                // shared popup coordinator until the menu is dismissed.
                previewDelay.stop()
                if (DockModelService.activeContextMenu
                        && DockModelService.activeContextMenu !== contextMenu) {
                    if (DockModelService.activeContextMenu.visible)
                        DockModelService.dismissDockPopupImmediately(
                            DockModelService.activeContextMenu)
                    else
                        DockModelService.activeContextMenu = null
                }
                // Rebuild items from the icon's current state (window task vs
                // pinned launcher, persisted pin state), then open.
                const pinned = icon.isPinnedItem || DockModelService.isAppPinned(icon.appId)
                contextMenu.clear()
                if (icon.isWindowItem) {
                    contextMenu.addItem("", "激活窗口", "activate")
                    contextMenu.addItem("", "最小化", "minimize")
                    contextMenu.addItem("", "关闭窗口", "close")
                    contextMenu.addItem(pinned ? "" : "",
                        pinned ? "取消固定" : "固定此应用", pinned ? "unpin" : "pin")
                } else {
                    contextMenu.addItem("", "打开", "open")
                    contextMenu.addItem(pinned ? "" : "",
                        pinned ? "取消固定" : "固定此应用", pinned ? "unpin" : "pin")
                }
                DockModelService.activeContextMenu = contextMenu
                DockModelService.openDockPopup(contextMenu)
            } else if (!icon._heldForEdit)
                icon.activate()
        }
        onEntered: {
            icon._hovering = true
            if (icon._previewWindowId && !icon.editMode
                    && !DockModelService.activeContextMenu)
                previewDelay.restart()
        }
        onExited: {
            icon._hovering = false
            previewDelay.stop()
            previewCloseDelay.restart()
        }
    }

    ContextMenu {
        id: contextMenu
        property bool hasBeenVisible: false
        anchorItem: icon
        position: ConfigService.position
        baseColor: ThemeService.backgroundColor
        foregroundColor: ThemeService.foregroundColor
        onAboutToShow: hasBeenVisible = true
        onAboutToHide: {
            if (hasBeenVisible) {
                hasBeenVisible = false
                if (DockModelService.activeContextMenu === contextMenu)
                    DockModelService.activeContextMenu = null
                DockModelService.releaseDockPopup(contextMenu)
            }
        }
        onAction: function(name) {
            switch (name) {
            case "open":
                DockModelService.activateApp(icon.appId)
                break
            case "unpin":
                AppActionService.unpin(icon.appId)
                break
            case "activate":
                DockModelService.activateWindow(icon.windowId)
                break
            case "minimize":
                DockModelService.minimizeWindow(icon.windowId)
                break
            case "close":
                DockModelService.closeWindow(icon.windowId)
                break
            case "pin":
                AppActionService.pin(icon.appId)
                break
            }
        }
    }

    DockWindowPreview {
        id: preview
        anchorItem: icon
        onPointerInsideChanged: {
            if (pointerInside)
                previewCloseDelay.stop()
            else if (!icon._hovering)
                previewCloseDelay.restart()
        }
        onActivateRequested: {
            DockModelService.activateWindow(preview.windowId)
            DockModelService.setDockPopupVisible(preview, false)
        }
        onVisibleChanged: {
            if (!visible)
                DockModelService.releaseDockPopup(preview)
        }
    }

}
