import QtQuick

// DockActiveIndicator — one shared active-window background for the Dock.
//
// This is deliberately presentation-only. DockIcon continues to own the
// business-facing `isActivated` state; the container supplies the currently
// active icon and this component animates its visual position between slots.
Item {
    id: indicator

    property Item target: null
    property color fillColor: Qt.rgba(1, 1, 1, 0.5)
    property int moveDuration: 260
    property bool _hasInitialPosition: false
    property bool _animatePosition: false
    property real _lastX: 0
    property real _lastY: 0
    property real _lastWidth: 0
    property real _lastHeight: 0
    property real _lastRadius: 0

    readonly property real targetRadius: _lastRadius

    x: 0
    y: 0
    width: 0
    height: 0
    // A newly created target has no final geometry until geometrySync runs.
    // Keep it invisible for that one frame instead of flashing at (0, 0).
    opacity: target && _hasInitialPosition ? 1.0 : 0.0
    visible: opacity > 0.01
    z: -0.5

    // Map coordinates only after Row/Repeater has completed its layout pass.
    // Declarative mapToItem bindings do not reliably notify when an ancestor
    // Loader moves, which caused new windows to briefly target (0, 0).
    function requestSync() {
        if (target)
            geometrySync.restart()
    }

    function syncTargetGeometry() {
        if (!target || !parent)
            return
        // The icon itself may hover-scale around Item.Center. Use its mapped
        // visual center, but deliberately keep the backdrop at its unscaled
        // slot size so the Dock retains equal top/bottom breathing room.
        const center = target.mapToItem(parent, target.width / 2, target.height / 2)
        const radius = target.activeBackgroundRadius !== undefined
            ? target.activeBackgroundRadius
            : Math.min(target.width, target.height) * 0.3

        // The first target is placed directly; later changes retain the old
        // geometry and let the Behaviors animate across the Dock.
        _animatePosition = _hasInitialPosition
        width = target.width
        height = target.height
        x = center.x - width / 2
        y = center.y - height / 2
        _lastX = x
        _lastY = y
        _lastWidth = width
        _lastHeight = height
        _lastRadius = radius
        _hasInitialPosition = true
        _animatePosition = true
    }

    onTargetChanged: {
        if (!target) {
            _hasInitialPosition = false
            _animatePosition = false
        } else {
            requestSync()
        }
    }

    Timer {
        id: geometrySync
        // One frame gives newly created Repeater delegates time to receive
        // their final Row geometry before the indicator samples it.
        interval: 16
        repeat: false
        onTriggered: indicator.syncTargetGeometry()
    }

    Behavior on x {
        enabled: indicator._animatePosition
        NumberAnimation {
            duration: indicator.moveDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on y {
        enabled: indicator._animatePosition
        NumberAnimation {
            duration: indicator.moveDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on width {
        enabled: indicator._animatePosition
        NumberAnimation {
            duration: indicator.moveDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on height {
        enabled: indicator._animatePosition
        NumberAnimation {
            duration: indicator.moveDuration
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Rectangle {
        anchors.fill: parent
        radius: indicator.targetRadius
        color: indicator.fillColor
    }
}
