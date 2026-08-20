import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.common

// One concrete output-bound Dock layer surface.
PanelWindow {
    id: root

    // Distinguish this surface from other quickshell panels so the glass
    // plugin can give it its own highlight direction.
    WlrLayershell.namespace: "quickshell-dock"

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    // Keep the persistent Dock on the normal layer-shell Top layer.
    WlrLayershell.layer: WlrLayer.Top

    // ── Position-aware anchoring ──
    // The dock clings to the configured screen edge. A bottom dock spans the
    // full screen width and sits on the bottom edge; a side dock sizes itself
    // to the icon column and is centred vertically on the left/right edge (no
    // top/bottom anchors, so it never spans the full screen height).
    //
    // position is a per-edge literal baked into the matching Component in
    // Dock.qml; switching edges recreates this window instead of patching a
    // live one, so the anchors below are final from the first commit.
    property string position: "bottom"
    readonly property bool vertical: root.position === "left"
        || root.position === "right"
    readonly property int edgeMargin: 5

    // Horizontal dock: span the full width and sit on the bottom edge.
    // Side dock: anchored to one edge only. No top/bottom anchors mean the
    // window height comes from implicitHeight instead of the full screen.
    //
    // NOTE: wlr-layer-shell anchor bits are top=1, bottom=2, left=4, right=8;
    // a correct {left, right, bottom} dock submits 14, {left} submits 4.
    anchors: ({
        left: !root.vertical || root.position === "left",
        top: false,
        bottom: !root.vertical,
        right: !root.vertical || root.position === "right"
    })
    margins {
        left: root.vertical && root.position === "left" ? root.edgeMargin : 0
        top: 0
        right: root.vertical && root.position === "right" ? root.edgeMargin : 0
        bottom: root.vertical ? 0 : root.edgeMargin
    }

    // Horizontal mode: the width comes from the left+right anchors (full
    // screen), the height from the content. Vertical mode: only the anchored
    // edge fixes the width, the height is the content height too.
    implicitWidth: root.vertical ? dockWrapper.width : 0
    implicitHeight: dockWrapper.height
    // Reserve the settled (non-animated) content size so the compositor does
    // not re-layout other windows while the dock plays its resize animation.
    exclusiveZone: root.vertical
        ? dockContainer.implicitWidth + root.edgeMargin
        : dockContainer.implicitHeight + root.edgeMargin

    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: dockWrapper
        radius: dockContainer.pillRadius
    }

    Item {
        id: dockWrapper
        // Bottom dock: horizontally centred on the bottom edge. Side dock:
        // vertically centred on the left/right edge (window already sizes
        // itself to the content, so this only positions the wrapper).
        anchors {
            horizontalCenter: root.vertical ? undefined : parent.horizontalCenter
            bottom: root.vertical ? undefined : parent.bottom
            verticalCenter: root.vertical ? parent.verticalCenter : undefined
            left: root.vertical ? parent.left : undefined
            right: root.vertical && root.position === "right"
                ? parent.right : undefined
        }
        // Follow the animated container size: the resize Behavior drives
        // the background (and its blur region) smoothly along with the icons.
        width: dockContainer.width
        height: dockContainer.height

        DockContainer {
            id: dockContainer
            anchors.centerIn: parent
            targetScreen: root.screen
        }
    }
}
