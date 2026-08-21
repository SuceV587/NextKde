import QtQuick
import Quickshell
import qs.desktop.modules.common

// In-scene context menu anchored to a dock icon.
//
// The native Platform.Menu cannot be positioned under Wayland with this Qt
// (no popup(x,y) exposed) and Item.mapToGlobal is unreliable inside a sliding
// layer-surface dock, so a bare open() lands at the dock window's real edge
// (the retracted offset) below the revealed glass. This QML PopupWindow is
// instead anchored to the icon via the compositor window-anchor geometry
// (DockTrashConfirmPopup's pattern), so it always appears exactly beside the
// icon you right-clicked, regardless of dock reveal state.
//
// It keeps the same coordinator contract (setDockPopupVisible / dismiss /
// aboutToShow / aboutToHide / action) as the old DockContextMenu so DockIcon's
// wiring is unchanged.
PopupWindow {
    id: root

    property Item anchorItem: null
    property string position: "bottom"   // bottom | left | right
    // Anchors flip so the menu opens away from the screen edge on side docks.
    readonly property bool vertical: root.position === "left" || root.position === "right"

    property bool isWindow: false
    property bool isPinned: false
    property string appId: ""
    property string windowId: ""

    signal action(string name)
    signal aboutToShow()
    signal aboutToHide()

    implicitWidth: 220
    color: "transparent"
    grabFocus: true

    // Open above a bottom-dock icon; to the screen-outward side on a side dock.
    anchor.item: root.anchorItem
    anchor.edges: root.vertical
        ? (root.position === "right" ? Edges.Left : Edges.Right)
        : Edges.Top
    anchor.gravity: root.vertical
        ? (root.position === "right" ? Edges.Left : Edges.Right)
        : Edges.Top
    anchor.margins.top: root.vertical ? 0 : -6
    anchor.margins.left: root.vertical ? (root.position === "right" ? -8 : 8) : 0
    anchor.margins.right: root.vertical ? (root.position === "right" ? -8 : 8) : 0

    function setDockPopupVisible(shouldOpen) { root.visible = shouldOpen }
    function dismissDockPopupImmediately() { root.visible = false }
    // Emit an owning-item-friendly signal just for this item's action.
    function choose(name) {
        root.action(name)
        root.visible = false
    }

    onVisibleChanged: {
        if (root.visible)
            root.aboutToShow()
        else
            root.aboutToHide()
    }

    LiquidGlassSurface {
        anchors.fill: parent
        radius: 16
        baseColor: ThemeService.backgroundColor
        ambientPrimary: WallpaperPaletteService.primary
        ambientSecondary: WallpaperPaletteService.secondary
        ambientStrength: 0.28
        materialDepth: 0.6

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            // ── Window items ──
            DockMenuItem { label: "激活窗口"; icon: "";  visible: root.isWindow; onClicked: root.choose("activate") }
            DockMenuItem { label: "最小化";     icon: ""; visible: root.isWindow; onClicked: root.choose("minimize") }
            DockMenuItem { label: "关闭窗口";   icon: ""; visible: root.isWindow; onClicked: root.choose("close") }
            DockMenuItem { label: root.isPinned ? "取消固定" : "固定此应用"
                icon: root.isPinned ? "" : ""
                visible: root.isWindow
                onClicked: root.choose(root.isPinned ? "unpin" : "pin") }

            // ── App (launcher) items ──
            DockMenuItem { label: "打开"; icon: ""; visible: !root.isWindow; onClicked: root.choose("open") }
            DockMenuItem { label: "固定此应用"; icon: ""
                visible: !root.isWindow && !root.isPinned
                onClicked: root.choose("pin") }
            DockMenuItem { label: "取消固定"; icon: ""
                visible: !root.isWindow && root.isPinned
                onClicked: root.choose("unpin") }
        }
    }
}