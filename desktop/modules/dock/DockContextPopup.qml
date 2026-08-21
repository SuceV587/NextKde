import QtQuick
import Quickshell
import qs.desktop.modules.dock
import qs.desktop.modules.common

// In-scene context menu anchored to a dock icon.
//
// The native Platform.Menu cannot be positioned under Wayland with this Qt
// (no popup(x,y)) and Item.mapToGlobal is unreliable inside a layer-surface
// dock, so a bare open() lands at the pointer/reveal-strip instead of the
// icon. This PopupWindow reuses DockTrashConfirmPopup's proven geometry:
//   - placement comes from the compositor window-anchor (anchor.item), never
//     a manual coordinate, so it tracks the icon even when the dock slides;
//   - grabFocus -> Qt::Popup flag (popupwindow.cpp) grabs pointer+keyboard and
//     auto-dismisses on any click outside, exactly like a native context menu;
//   - WindowService focus change is a belt-and-braces dismissal for right
//     clicks onto another app that Qt::Popup might not surface on Wayland.
// It keeps the same coordinator contract (setDockPopupVisible / dismiss /
// aboutToShow / aboutToHide / action) as the old DockContextMenu.
PopupWindow {
    id: root

    property Item anchorItem: null
    property string position: "bottom"   // bottom | left | right

    property bool isWindow: false
    property bool isPinned: false
    property string appId: ""
    property string windowId: ""

    signal action(string name)
    signal aboutToShow()
    signal aboutToHide()

    implicitWidth: 230
    color: "transparent"
    grabFocus: true

    // Same anchor as DockTrashConfirmPopup (verified in this dock): the menu's
    // top edge meets the icon's top edge and pulls up a little, so it always
    // opens just above the icon you right-clicked.
    anchor {
        item: root.anchorItem
        edges: root.position === "bottom" ? Edges.Top : Edges.Right
        gravity: root.position === "bottom" ? Edges.Top : Edges.Right
        margins.top: root.position === "bottom" ? -8 : 0
        margins.right: root.position === "right" ? -8 : 8
        margins.left: root.position === "left" ? 8 : 0
    }

    function setDockPopupVisible(shouldOpen) { root.visible = shouldOpen }
    function dismissDockPopupImmediately() { root.visible = false }
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

    // Belt-and-braces: if another app takes focus (clicked another window),
    // close the menu even if Qt::Popup didn't auto-dismiss on this Wayland.
    Connections {
        target: WindowService
        function onActiveWindowIdChanged() {
            if (root.visible)
                root.visible = false
        }
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