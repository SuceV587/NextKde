import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.desktop.modules.common

// Shared liquid-glass context menu, used by the Dock, the app launcher and the
// desktop file grid so every right-click menu looks and behaves uniformly.
//
// A PopupWindow anchored to an Item (compositor window-anchor geometry) so it
// tracks the icon/entry it opened from even inside sliding layer surfaces where
// mapToGlobal is unreliable. grabFocus -> Qt::Popup (popupwindow.cpp) grabs
// pointer+keyboard and auto-dismisses on any outside click, like a native menu.
//
// Supports nested submenus with back navigation and checkable (radio) rows, so
// it can host the desktop file-grid's "customise appearance" colour/emoji pickers.
// Item shape (a JS object):
//   { icon, label, cmd, enabled, checkable, checked, separator, children: [Item] }
// setItems(arr) builds the root; clicking a row with `children` pushes it and
// shows a back row; checkable rows toggle `checked` (radio within the same
// `group`) and emit action(cmd); plain rows emit action(cmd) and close.
//
// Theme colours are inputs (baseColor / foregroundColor). The Dock's popup
// coordinator contract (setDockPopupVisible/aboutToShow/aboutToHide) is kept so
// it drops into existing open/close coordination.
PopupWindow {
    id: root

    // ── Caller inputs ──
    property Item anchorItem: null
    property string position: "bottom"   // bottom | left | right
    property color baseColor: Qt.rgba(0, 0, 0, 0.55)
    property color foregroundColor: "#ffffff"
    property color ambientPrimary: "transparent"
    property color ambientSecondary: "transparent"
    property real ambientStrength: 0.0

    signal action(string cmd, var item)

    // ── Item tree + navigation ──
    property var _root: []
    property var _path: []
    readonly property var _view: root._path.length > 0
        ? root._path[root._path.length - 1] : root._root

    function setItems(arr) {
        root._root = arr || []
        root._path = []
    }
    // NOTE: arrays are never mutated in place. The Repeater's `model` binding
    // only re-renders when the bound value (root._view) is *re-assigned*, so
    // every mutation reassigns a fresh array via concat/slice.
    function clear() { root._root = [] }
    function addItem(icon, label, cmd, enabled) {
        root._root = root._root.concat([{
            icon: icon || "", label: label, cmd: cmd, enabled: enabled !== false
        }])
    }
    function _push(arr) { root._path = root._path.concat([arr]) }
    function _back() {
        if (root._path.length > 0)
            root._path = root._path.slice(0, -1)
    }
    function show() { root.visible = true }
    function hide() { root.visible = false }

    // Popup coordinator contract.
    signal aboutToShow()
    signal aboutToHide()
    function setDockPopupVisible(shouldOpen) { root.visible = shouldOpen }
    function dismissDockPopupImmediately() { root.visible = false }

    // Opens above the anchor point by default (bottom-dock icon → menu above);
    // placeBelow flips it to open below (desktop right-click → menu under the
    // cursor). Adjustment Flip|Slide then auto-turns it inside-out at the screen
    // edges like a native menu (below→above or right→left when out of room).
    property bool placeBelow: false

    implicitWidth: 240
    implicitHeight: list.implicitHeight + 12 + (root._path.length > 0 ? 40 : 0)
    color: "transparent"
    grabFocus: true

    anchor {
        item: root.anchorItem
        edges: root.position === "bottom"
            ? (root.placeBelow ? (Edges.Top | Edges.Left) : Edges.Top)
            : Edges.Right
        gravity: root.position === "bottom"
            ? (root.placeBelow ? (Edges.Bottom | Edges.Right) : Edges.Top)
            : Edges.Right
        adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide
        margins.top: root.position === "bottom" ? -8 : 0
        margins.right: root.position === "right" ? -8 : 8
        margins.left: root.position === "left" ? 8 : 0
    }

    // Quick entrance fade of the glass, plus reset submenu nav on open.
    NumberAnimation {
        id: enterOpacity
        target: glass; property: "opacity"; from: 0; to: 1
        duration: 120; easing.type: Easing.OutCubic
    }
    onVisibleChanged: {
        if (root.visible) {
            root._path = []
            glass.opacity = 0
            enterOpacity.restart()
            root.aboutToShow()
        } else {
            root.aboutToHide()
        }
    }

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
        ambientStrength: root.ambientStrength
        materialDepth: 0.6

        Column {
            id: list
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            // Back row when inside a submenu.
            MenuItemRow {
                width: parent.width
                foregroundColor: root.foregroundColor
                visible: root._path.length > 0
                icon: ""
                label: "返回"
                onClicked: root._back()
            }

            Repeater {
                model: root._view
                delegate: MenuItemRow {
                    required property var modelData
                    // Inline submenu detection: every binding re-evaluation
                    // (including Repeater rebuild on submenu navigation)
                    // computes fresh. Avoids the QML gotcha where `readonly
                    // property` computes only once at delegate instantiation.
                    width: parent.width
                    foregroundColor: root.foregroundColor
                    icon: modelData.icon || ""
                    label: modelData.label || ""
                    separator: !!modelData.separator
                    hasSubmenu: Array.isArray(modelData.children)
                        ? modelData.children.length > 0
                        : !!modelData.children
                    checkable: !!modelData.checkable
                    checked: !!modelData.checked
                    itemEnabled: modelData.enabled !== false
                    onClicked: {
                        // TEMP: log click event
                        console.log('[ctx click] label="' + (modelData.label || '') + '" cmd="' + (modelData.cmd || '') + '" hasChildren=' + !!modelData.children)
                        // modelData wraps a submenu array as a QJSValue, so
                        // Array.isArray fails even though it is array-like:
                        // detect via length and normalise with slice.call.
                        const c = modelData.children
                        if (Array.isArray(c) ? c.length > 0 : !!c) {
                            console.log('[ctx push] len=' + (Array.isArray(c) ? c.length : (c ? c.length : 0)))
                            root._push(Array.isArray(c) ? c : Array.prototype.slice.call(c))
                        } else {
                            console.log('[ctx action] cmd=' + modelData.cmd)
                            root.action(modelData.cmd, modelData)
                            root.hide()
                        }
                    }
                }
            }
        }
    }
}