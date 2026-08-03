import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// DockContextMenu — transient context menu for one DockIcon.
// It owns presentation only; actions are emitted to DockIcon, which delegates
// them to DockModelService. No menu state is persisted.

PopupWindow {
    id: menu

    property bool isWindow: false
    property bool isPinned: false
    property string appId: ""
    property string windowId: ""
    property Item anchorItem: null
    property real revealProgress: 0.0
    property bool closing: false
    property string pendingAction: ""

    signal action(string name)

    readonly property var entries: {
        if (isWindow) {
            return [
                { name: "activate", label: "激活窗口", symbol: "\uf2d2" }, // window restore
                { name: "minimize", label: "最小化", symbol: "\uf2d1" }, // window minimize
                { name: "close", label: "关闭窗口", symbol: "\uf00d" }, // xmark
                isPinned
                    ? { name: "unpin", label: "取消固定", symbol: "\uf08d" }
                    : { name: "pin", label: "固定此应用", symbol: "\uf08d" },
            ]
        }
        if (!isPinned) {
            return [
                { name: "open", label: "打开", symbol: "\uf04b" }, // play
                { name: "pin", label: "固定此应用", symbol: "\uf08d" },
            ]
        }
        return [
            { name: "open", label: "打开", symbol: "\uf04b" },
            { name: "unpin", label: "取消固定", symbol: "\uf08d" },
        ]
    }

    // PopupWindow derives its size from implicit dimensions. Using width /
    // height here triggers a deprecation warning in newer Quickshell builds.
    implicitWidth: 170
    implicitHeight: 12 + entries.length * 34
    color: "transparent"
    grabFocus: true

    // PopupWindow itself must remain visible until the card's exit animation
    // completes. Callers use this method through DockModelService instead of
    // writing `visible` directly, so separate Wayland popup surfaces retain a
    // natural close transition without changing their anchor geometry.
    function setDockPopupVisible(shouldOpen) {
        if (shouldOpen) {
            revealOut.stop()
            closing = false
            pendingAction = ""
            menu.visible = true
            revealProgress = 0.0
            // PopupWindow positions its own Wayland surface asynchronously.
            // Delay drawing by one frame so a rapidly replaced menu never
            // exposes its old/default screen-edge geometry.
            revealStart.restart()
            return
        }
        if (!menu.visible || closing)
            return
        closing = true
        revealOut.restart()
    }

    function dismissDockPopupImmediately() {
        revealStart.stop()
        revealIn.stop()
        revealOut.stop()
        closing = false
        pendingAction = ""
        revealProgress = 0.0
        menu.visible = false
    }

    // Dispatch destructive/model-changing actions only after the exit has
    // finished. Otherwise an unpin or window close can destroy the anchor
    // while this independent Wayland popup is still animating.
    function dismissWithAction(name) {
        pendingAction = name
        setDockPopupVisible(false)
    }

    Timer {
        id: revealStart
        interval: 16
        repeat: false
        onTriggered: {
            if (menu.visible && !menu.closing)
                revealIn.restart()
        }
    }

    NumberAnimation {
        id: revealIn
        target: menu
        property: "revealProgress"
        to: 1.0
        duration: 110
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: revealOut
        NumberAnimation {
            target: menu
            property: "revealProgress"
            to: 0.0
            duration: 90
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                menu.closing = false
                menu.visible = false
                const name = menu.pendingAction
                menu.pendingAction = ""
                if (name)
                    menu.action(name)
            }
        }
    }

    // The Dock is at the bottom of the screen, so open upward from the icon.
    // PopupWindow keeps this separate from the Dock's adaptive height.
    anchor {
        item: menu.anchorItem
        // `edges` selects the point on the icon; `gravity` is the direction
        // in which the popup expands. Both must be Top: Top + Bottom expands
        // downward from the icon top, which is why the menu previously sat
        // level with the icon instead of above it.
        edges: Edges.Top
        gravity: Edges.Top
        // A negative top margin moves the anchor point above the icon,
        // creating an 8px visual gap without changing Dock layout geometry.
        margins.top: -8

    }

    LiquidGlassSurface {
        id: background
        anchors.fill: parent
        opacity: menu.revealProgress
        transform: Translate {
            // The Dock sits below the menu: emerge upward from the icon, then
            // return toward it on dismissal. This only moves card contents,
            // never the PopupWindow anchor used for hit testing.
            y: (1.0 - menu.revealProgress) * 6
        }
        radius: 12
        // The base Dock tint is intentionally only 10% opaque. A popup needs
        // a thicker material layer or the compositor blur remains invisible
        // against busy wallpaper. BackgroundEffect below supplies the actual
        // Gaussian backdrop blur; this tint makes that blur legible.
        baseColor: ThemeService.isDark
            ? Qt.rgba(0.04, 0.05, 0.07, 0.72)
            : Qt.rgba(0.94, 0.95, 0.98, 0.68)
        surfaceOpacity: 0.96
        materialDepth: 2.5

        Column {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Repeater {
                model: menu.entries
                delegate: Rectangle {
                    required property var modelData
                    width: menu.width - 12
                    height: 30
                    radius: 7
                    color: menuItemMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : "transparent"

                    Text {
                        width: 16
                        height: 16
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: modelData.symbol ?? ""
                        color: ThemeService.foregroundColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font {
                            family: "Font Awesome 7 Free"
                            pixelSize: 13
                            weight: Font.Black
                        }
                        opacity: 0.84
                    }

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: 36
                        verticalAlignment: Text.AlignVCenter
                        text: modelData.label
                        color: ThemeService.foregroundColor
                        font {
                            family: "SF Pro Display"
                            pixelSize: 13
                            weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: menuItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: function(mouse) {
                            // Dismiss this grab surface before dispatching the
                            // action. That prevents the stale popup from
                            // retaining input while the Dock model reflows.
                            menu.dismissWithAction(modelData.name)
                        }
                    }
                }
            }
        }
    }

    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: background
        radius: background.radius
    }
}
