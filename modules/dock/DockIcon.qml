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
    property string displayName: ""
    property string appId:       ""
    property string windowId:    ""
    // `isRunning` is visual runtime state. `isWindowItem` identifies which
    // context-menu actions are valid, because a pinned running app has no
    // single windowId even though it displays a running indicator.
    property bool   isWindowItem: false
    property bool   isRunning:   false
    property bool   isActivated: false
    property string bounceKey:   ""     // empty = never bounce
    // This is proportional to iconSize (3px when iconSize is 44px). It is
    // also included in AdaptiveMath, so the active background never overlaps
    // a neighbour or makes the real Row wider than the calculated width.
    property real   activeBackgroundGap: 4.4

    // Active background radius is proportional to the icon height. This is
    // intentionally independent from the icon/background gap.
    readonly property real activeBackgroundRadius: iconSize * 0.3
    readonly property real iconSlotSize: iconSize + activeBackgroundGap * 2
    readonly property bool showActiveBackground: isRunning && isActivated

    signal activate()
    property bool _menuOpen: false

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
            console.log("[DockIcon] created key=" + icon.bounceKey + " bounce=" + willBounce + " name=" + icon.displayName)
            if (willBounce) bounceIn.start()
            else icon._bounceDone = true
        } else {
            // pinned item — never bounce
            icon._bounceDone = true
        }
    }

    // ── Hover animation (only active after bounce is done) ──
    property bool _hovering: false
    Behavior on scale {
        enabled: icon._bounceDone && !bounceIn.running
        NumberAnimation {
            duration: DockAnimation.iconHoverDuration
            easing.type: DockAnimation.iconHoverEasing
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
        color: Qt.rgba(1, 1, 1, 0.5)
        visible: icon.showActiveBackground
        z: -1
    }

    IconImage {
        id: iconImage
        width: icon.iconSize
        height: icon.iconSize
        anchors.centerIn: parent
        source: icon.iconSource || ""
        smooth: true
        asynchronous: true
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
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton)
                icon._menuOpen = true
            else
                icon.activate()
        }
        onEntered: icon._hovering = true
        onExited:  icon._hovering = false
    }

    DockContextMenu {
        id: contextMenu
        isWindow: icon.isWindowItem
        appId: icon.appId
        windowId: icon.windowId
        anchorItem: icon
        onVisibleChanged: {
            if (!visible)
                icon._menuOpen = false
        }
        onAction: function(name) {
            icon._menuOpen = false
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
        visible: icon._menuOpen
    }

}
