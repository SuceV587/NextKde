import QtQuick
import Quickshell
import Quickshell.Widgets

// ────────────────────────────────────────────────────────────────
// DockIcon — Single icon in the dock.
// Used for both pinned launcher icons and open window icons.
//
// Bounce-in: one-shot SequentialAnimation on Component.onCompleted.
// Hover: gentle NumberAnimation via Behavior (only after bounce done).
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
    // Shell controls can use the standard left-click activation pipeline while
    // opting out of application-specific right-click context-menu actions.
    property bool   showContextMenu: true
    // The fixed launcher is not a persisted pinned app, so holding it must not
    // enter the pinned-app edit/reorder state.
    property bool   allowEdit: true
    property bool   isRunning:   false
    property bool   isActivated: false
    // Urgency is independent from activation. A window requesting attention
    // paints an orange-red slot until the compositor clears that state.
    property bool   isUrgent:    false
    // The container renders a single animated active background. DockIcon
    // reports its activated state to this visual host without owning motion.
    property Item   activeIndicatorHost: null
    property string bounceKey:   ""     // empty = never bounce
    // Pinned delegates enable this while a sibling is being dragged. Window
    // icons intentionally leave it false.
    property bool   editMode: false
    property bool   isDragging: false
    // This is proportional to iconSize (3px when iconSize is 44px). It is
    // also included in AdaptiveMath, so the active background never overlaps
    // a neighbour or makes the real Row wider than the calculated width.
    property real   activeBackgroundGap: 4.4

    // Active background radius is proportional to the icon height. This is
    // intentionally independent from the icon/background gap.
    readonly property real activeBackgroundRadius: iconSize * 0.3
    readonly property real iconSlotSize: iconSize + activeBackgroundGap * 2
    readonly property bool showActiveBackground: isRunning && isActivated
    readonly property bool showUrgentBackground: isRunning && isUrgent
        && !showActiveBackground

    signal activate()
    signal requestEdit()
    property bool _heldForEdit: false

    // Reserve the background's outer slot for every app icon. Only the active
    // window paints it; reserving the slot prevents focus changes from moving
    // the surrounding icons.
    width:  iconSlotSize
    height: iconSlotSize
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // ═══════════════════════════════════════════════════════════
    // State machine for scale animation
    //   0. starting → bounce-in animation runs once
    //   1. idle      → hover Behavior active
    // ═══════════════════════════════════════════════════════════
    property bool _bounceDone: false

    // Final scale: 1.0 (or slightly larger on hover, applied AFTER bounce)
    property real _targetScale: _hovering ? DockAnimation.iconHoverScale : 1.0
    scale: _bounceDone ? _targetScale : 0.0

    // ── One-shot bounce animation ──
    SequentialAnimation {
        id: bounceIn
        running: false
        NumberAnimation {
            target: icon; property: "scale"
            from: 0.0; to: DockAnimation.iconBounceOvershoot
            duration: DockAnimation.iconBounceDuration * 0.45
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: icon; property: "scale"
            from: DockAnimation.iconBounceOvershoot; to: 1.0
            duration: DockAnimation.iconBounceDuration * 0.55
            easing.type: Easing.InOutCubic
        }
        ScriptAction {
            script: icon._bounceDone = true
        }
    }
    Component.onCompleted: {
        if (icon.bounceKey) {
            const willBounce = DockModelService.shouldBounce(icon.bounceKey)
            if (willBounce) bounceIn.start()
            else icon._bounceDone = true
        } else {
            // pinned item — never bounce
            icon._bounceDone = true
        }
        _reportActiveIndicator()
    }

    function _reportActiveIndicator() {
        if (icon.activeIndicatorHost)
            icon.activeIndicatorHost.reportActiveIcon(icon, icon.isActivated)
    }

    // Direct window delegates move when Row lays out a new task. Report those
    // visual geometry changes so the shared indicator samples the final slot.
    function _syncActiveIndicatorGeometry() {
        if (icon.activeIndicatorHost)
            icon.activeIndicatorHost.syncActiveIcon(icon)
    }

    onIsActivatedChanged: _reportActiveIndicator()
    onXChanged: _syncActiveIndicatorGeometry()
    onYChanged: _syncActiveIndicatorGeometry()
    onWidthChanged: _syncActiveIndicatorGeometry()
    onHeightChanged: _syncActiveIndicatorGeometry()
    onScaleChanged: _syncActiveIndicatorGeometry()

    // ── Hover animation (only active after bounce is done) ──
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
        enabled: icon._bounceDone && !bounceIn.running
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
            if (icon._hovering && icon._previewWindowId) {
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
                preview.visible = false
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
        // The active state is rendered by DockActiveIndicator so it can move
        // between windows. Urgency is per-window and can be simultaneous, so
        // it intentionally remains a local orange-red background.
        color: Qt.rgba(1.0, 0.30, 0.12, 0.50)
        visible: icon.showUrgentBackground
        z: -1
    }

    IconImage {
        id: iconImage
        width: icon.iconSize
        height: icon.iconSize
        anchors.centerIn: parent
        source: icon.iconSource || ""
        visible: !icon.glyph
        smooth: true
        asynchronous: true
    }

    Text {
        anchors.centerIn: parent
        text: icon.glyph
        visible: !!icon.glyph
        color: Qt.rgba(1, 1, 1, 0.92)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font {
            family: "Font Awesome 7 Free"
            pixelSize: Math.round(icon.iconSize * 0.58)
            weight: Font.Black
        }
    }


    // iPadOS-style running marker. It lives in the pre-reserved icon slot, so
    // toggling it never changes Row width, Dock height, or adaptive layout.
    Rectangle {
        id: runningIndicator
        // 42px icon -> 4px dot. Keep a 3px lower bound at compact widths.
        width: Math.max(3, Math.round(icon.iconSize * 0.10))
        height: width
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        color: Qt.rgba(1, 1, 1, 0.88)
        // The active/hover-style background already communicates the focused
        // running app, so showing both markers would be redundant.
        visible: icon.isRunning && !icon.showActiveBackground
    }

    // ═══════════════════════════════════════════════════════════
    // Interaction
    // ═══════════════════════════════════════════════════════════
    MouseArea {
        id: _mouseArea
        anchors.fill: parent
        enabled: icon.interactive
        hoverEnabled: true
        acceptedButtons: icon.showContextMenu
            ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        // Normal clicks stay owned by the icon.  Once a long press enables dock
        // edit mode, let the parent DragHandler take the pointer to reorder
        // pinned apps; otherwise the wiggle animation starts but dragging cannot.
        preventStealing: !icon.editMode
        cursorShape: Qt.PointingHandCursor
        onPressed: icon._heldForEdit = false
        onPressAndHold: {
            if (!icon.allowEdit)
                return
            icon._heldForEdit = true
            icon.requestEdit()
        }
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                if (DockModelService.activeContextMenu
                        && DockModelService.activeContextMenu !== contextMenu) {
                    if (DockModelService.activeContextMenu.visible)
                        DockModelService.activeContextMenu.visible = false
                    else
                        DockModelService.activeContextMenu = null
                }
                // PopupWindow may overwrite a QML binding on `visible` when
                // it closes itself. Open it imperatively on every request so
                // a prior dismissal can never leave the menu disconnected
                // from this icon's state.
                DockModelService.activeContextMenu = contextMenu
                DockModelService.openDockPopup(contextMenu)
            } else if (!icon._heldForEdit)
                icon.activate()
        }
        onEntered: {
            icon._hovering = true
            if (icon._previewWindowId && !icon.editMode)
                previewDelay.restart()
        }
        onExited: {
            icon._hovering = false
            previewDelay.stop()
            previewCloseDelay.restart()
        }
    }

    DockContextMenu {
        id: contextMenu
        property bool hasBeenVisible: false
        isWindow: icon.isWindowItem
        // Window tasks need the persisted top-level pin state too.
        isPinned: icon.isPinnedItem || DockModelService.isAppPinned(icon.appId)
        appId: icon.appId
        windowId: icon.windowId
        anchorItem: icon
        onVisibleChanged: {
            if (visible) {
                hasBeenVisible = true
            } else if (hasBeenVisible) {
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
                DockModelService.unpinApp(icon.appId)
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
                DockModelService.pinApp(icon.appId)
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
            preview.visible = false
        }
        onVisibleChanged: {
            if (!visible)
                DockModelService.releaseDockPopup(preview)
        }
    }

}
