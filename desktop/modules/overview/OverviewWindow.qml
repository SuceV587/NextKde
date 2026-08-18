import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.desktop.modules.common
import qs.desktop.modules.dock

// Stage-Manager-style workspace overview: a full-screen overlay showing the
// virtual-desktop bar on top and the current desktop's windows as a grid of
// live thumbnails. Clicking a desktop switches to it; clicking a window
// activates it and closes the overview.
//
// KWin owns switching (WindowService.switchDesktop) and desktop membership
// (each record carries desktopIds from the bridge). This surface is
// presentation only.
PanelWindow {
    id: root

    WlrLayershell.namespace: "quickshell-overview"

    property bool open: false
    property int selectedDesktopIndex: 0
    property int selectedWindowIndex: -1

    // The full-screen overlay dims the desktop so the grid reads as an
    // overview rather than floating windows.
    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    focusable: open
    anchors { top: true; left: true; right: true; bottom: true }

    // PanelWindow root keyboard handling (same pattern as AppLauncherWindow):
    // the window itself takes Keys once focusable, no Item focus dance.
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.open = false
            event.accepted = true
        } else if (event.key === Qt.Key_Left) {
            root.selectedDesktopIndex = Math.max(0, root.selectedDesktopIndex - 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Right) {
            root.selectedDesktopIndex = Math.min(root.desktopCount - 1, root.selectedDesktopIndex + 1)
            event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            const desktops = root.desktops
            if (desktops[root.selectedDesktopIndex])
                WindowService.switchDesktop(desktops[root.selectedDesktopIndex].id)
            root.open = false
            event.accepted = true
        }
    }

    readonly property var desktops: WindowService.desktops || []
    readonly property int desktopCount: desktops.length
    readonly property int currentDesktopIndex: {
        for (let i = 0; i < desktops.length; i++) {
            if (desktops[i].id === WindowService.currentDesktopId)
                return i
        }
        return -1
    }

    // Windows on the current desktop (or pinned to all desktops).
    readonly property var currentWindows: {
        WindowService.revision
        const currentId = WindowService.currentDesktopId
        const records = WindowService.records || []
        const result = []
        for (let i = 0; i < records.length; i++) {
            const record = records[i]
            const onDesktop = record.onAllDesktops
                || (Array.isArray(record.desktopIds) && record.desktopIds.indexOf(currentId) >= 0)
            if (onDesktop)
                result.push(record)
        }
        return result
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.03, 0.04, 0.06, 0.55)
    }

    // Dismiss on click outside any desktop/window card.
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.open = false
    }

    Column {
        anchors {
            fill: parent
            margins: 48
            topMargin: 26
        }
        spacing: 26

        // ── Desktop bar ───────────────────────────────────────────────
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            Repeater {
                model: root.desktops
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 96
                    height: 34
                    radius: 10
                    color: index === root.currentDesktopIndex
                        ? Qt.rgba(1, 1, 1, 0.18)
                        : (index === root.selectedDesktopIndex ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
                    border.width: index === root.selectedDesktopIndex ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.35)

                    Text {
                        anchors.centerIn: parent
                        text: modelData.name || ("桌面 " + (index + 1))
                        color: index === root.currentDesktopIndex ? "white" : Qt.rgba(1, 1, 1, 0.72)
                        font { pixelSize: 12; weight: Font.DemiBold }
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.50)
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedDesktopIndex = index
                            WindowService.switchDesktop(modelData.id)
                        }
                    }
                }
            }
        }

        // ── Current-desktop window grid ───────────────────────────────
        Grid {
            id: windowGrid
            anchors.horizontalCenter: parent.horizontalCenter
            columns: Math.max(1, Math.min(4, Math.floor((parent.width - 24) / 250)))
            spacing: 22

            Repeater {
                model: root.currentWindows
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: Math.min(250, (windowGrid.width - windowGrid.spacing * (windowGrid.columns - 1)) / windowGrid.columns)
                    height: width * 0.68 + 44

                    Rectangle {
                        id: windowCard
                        anchors.fill: parent
                        radius: 14
                        color: index === root.selectedWindowIndex
                            ? Qt.rgba(1, 1, 1, 0.14)
                            : (mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.06))
                        border.width: index === root.selectedWindowIndex ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.35)

                        // Live thumbnail once the bridge captured it earlier
                        // (the Dock/QuickSearch also request these); the app
                        // icon stays as the placeholder. Opening the overview
                        // never triggers a capture itself -- ScreenShot2 on a
                        // window hidden behind the full-screen overlay froze
                        // the shell, so captures only happen on card click,
                        // after the overview has closed.
                        Image {
                            id: preview
                            anchors {
                                top: parent.top; left: parent.left; right: parent.right
                                topMargin: 10; leftMargin: 10; rightMargin: 10
                            }
                            height: parent.height - 54
                            visible: !!WindowService.thumbnailUrl(modelData.windowId)
                            source: WindowService.thumbnailUrl(modelData.windowId)
                            sourceSize: Qt.size(500, 340)
                            fillMode: Image.PreserveAspectCrop
                            clip: true
                            smooth: true
                        }
                        AppIcon {
                            anchors.centerIn: parent
                            width: 42
                            height: 42
                            visible: !preview.visible
                            source: modelData.iconSource
                        }
                        Text {
                            anchors {
                                left: parent.left; right: parent.right
                                bottom: parent.bottom
                                leftMargin: 10; rightMargin: 10; bottomMargin: 8
                            }
                            text: modelData.title
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            font { pixelSize: 11; weight: Font.DemiBold }
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.50)
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedWindowIndex = index
                        onClicked: {
                            const windowId = modelData.windowId
                            WindowService.activateWindow(windowId)
                            root.open = false
                            // Captures happen only after the overview closes:
                            // a capture while the window is hidden behind the
                            // full-screen overlay froze the shell. The cached
                            // thumbnail then shows on the next overview open.
                            WindowService.requestThumbnail(windowId)
                        }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.currentWindows.length === 0
            text: "当前桌面没有打开的窗口"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 13
        }
    }

    onOpenChanged: {
        if (open) {
            // Presentation state only. Captures never happen while the
            // overview is open (a ScreenShot2 on a window hidden behind the
            // full-screen overlay froze the shell); thumbnails shown here are
            // ones the Dock/QuickSearch already requested, and new captures
            // are deferred to the card click, after the overlay has closed.
            selectedDesktopIndex = Math.max(0, root.currentDesktopIndex)
            selectedWindowIndex = -1
        }
    }
}
