import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.desktop.modules.common

// Shared liquid-glass context menu, used by the Dock, the app launcher and the
// desktop file grid so every right-click menu looks and behaves uniformly.
//
// A PopupWindow anchored to an Item (compositor window-anchor geometry), so it
// tracks the icon/entry it opened from even inside sliding layer surfaces where
// Item.mapToGlobal is unreliable. grabFocus -> Qt::Popup (popupwindow.cpp)
// grabs pointer+keyboard and auto-dismisses on any outside click, exactly like
// a native menu.
//
// Theme colours are inputs (baseColor / foregroundColor) so this stays
// Service-free: callers pass their own theme colours. Ambient pigment defaults
// off; callers may wire a wallpaper palette. The API is model-driven so menus
// built dynamically (e.g. desktop "open with" lists) rebuild from clear()+
// addItem().
PopupWindow {
    id: root

    // ── Caller inputs ──
    property Item anchorItem: null
    property string position: "bottom"   // bottom | left | right
    property color baseColor: Qt.rgba(0, 0, 0, 0.55)
    property color foregroundColor: "#ffffff"
    // Declarative items: { icon, label, id, enabled }
    property ListModel items: ListModel {}

    signal action(string id)
    // Popup coordinator contract (DockModelService / generic popup host) so a
    // ContextMenu can drop into any existing open/close coordination.
    signal aboutToShow()
    signal aboutToHide()
    function setDockPopupVisible(shouldOpen) { root.visible = shouldOpen }
    function dismissDockPopupImmediately() { root.visible = false }

    implicitWidth: 240
    implicitHeight: list.implicitHeight + 12
    color: "transparent"
    grabFocus: true

    anchor {
        item: root.anchorItem
        edges: root.position === "bottom" ? Edges.Top : Edges.Right
        gravity: root.position === "bottom" ? Edges.Top : Edges.Right
        margins.top: root.position === "bottom" ? -8 : 0
        margins.right: root.position === "right" ? -8 : 8
        margins.left: root.position === "left" ? 8 : 0
    }

    // ── Item model helpers ──
    function clear() { root.items.clear() }
    function addItem(icon, label, cmd, enabled) {
        root.items.append({ icon: icon || "", label: label, cmd: cmd, enabled: enabled !== false })
    }
    function show() { root.visible = true }
    function hide() { root.visible = false }

    // Quick entrance: a short fade of the glass, not a long slide. Also drives
    // the popup-coordinator show/hide signals.
    NumberAnimation {
        id: enterOpacity
        target: glass; property: "opacity"; from: 0; to: 1
        duration: 120; easing.type: Easing.OutCubic
    }
    onVisibleChanged: {
        if (root.visible) {
            glass.opacity = 0
            enterOpacity.restart()
            root.aboutToShow()
        } else {
            root.aboutToHide()
        }
    }

    // Frost what is behind so the liquid glass reads real.
    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: glass
        radius: 16
    }

    LiquidGlassSurface {
        id: glass
        anchors.fill: parent
        radius: 16
        baseColor: root.baseColor
        ambientPrimary: root.ambientPrimary
        ambientSecondary: root.ambientSecondary
        ambientStrength: root.ambientStrength // 0 = off
        materialDepth: 0.6

        Column {
            id: list
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: root.items
                delegate: MenuItemRow {
                    required property string icon
                    required property string label
                    required property string cmd
                    required property bool enabled
                    width: parent.width
                    foregroundColor: root.foregroundColor
                    visible: label.length > 0 && enabled
                    itemEnabled: enabled
                    onClicked: root.action(model.cmd)
                }
            }
        }
    }

    // ── Optional ambient pigment (defaults off; callers may wire a palette) ──
    property color ambientPrimary: "transparent"
    property color ambientSecondary: "transparent"
    property real ambientStrength: 0.0
}