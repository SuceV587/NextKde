import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import qs.modules.common
import qs.modules.dock

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

                        // Live thumbnail once the bridge captures it; the app
                        // icon stays as the loading placeholder.
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
                            width: 40
                            height: 40
                            visible: !preview.visible
                            source: modelData.iconSource
                        }

                        Row {
                            anchors {
                                left: parent.left; right: parent.right
                                bottom: parent.bottom
                                leftMargin: 12; rightMargin: 12; bottomMargin: 10
                            }
                            spacing: 8
                            AppIcon {
                                width: 20; height: 20
                                anchors.verticalCenter: parent.verticalCenter
                                source: modelData.iconSource
                            }
                            Text {
                                width: parent.width - 28
                                text: modelData.title
                                color: "white"
                                elide: Text.ElideRight
                                font { pixelSize: 11; weight: Font.DemiBold }
                                style: Text.Outline
                                styleColor: Qt.rgba(0, 0, 0, 0.50)
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.selectedWindowIndex = index
                            // Debounce: the pointer sweeps across cards while
                            // hunting for a window, and each capture is a
                            // synchronous ScreenShot2 on the compositor. Wait
                            // for the pointer to settle before requesting.
                            hoverThumbnailTimer.stop()
                            hoverThumbnailTimer.windowId = modelData.windowId
                            hoverThumbnailTimer.restart()
                        }
                        onExited: {
                            if (hoverThumbnailTimer.windowId === modelData.windowId)
                                hoverThumbnailTimer.stop()
                        }
                        onClicked: {
                            WindowService.activateWindow(modelData.windowId)
                            root.open = false
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

    // Request the hovered window's thumbnail after the pointer has settled
    // (300ms without moving to another card). One capture at a time.
    Timer {
        id: hoverThumbnailTimer
        interval: 300
        repeat: false
        property string windowId: ""
        onTriggered: {
            if (root.open && windowId)
                WindowService.requestThumbnail(windowId)
        }
    }

    onOpenChanged: {
        if (open) {
            // Presentation state only. No D-Bus work here: opening the
            // overview while firing desktop queries or thumbnail captures
            // through the bridge consistently hung/crashed the shell, so the
            // grid renders from the already-live WindowService model and each
            // window card requests its single thumbnail only once hovered.
            selectedDesktopIndex = Math.max(0, root.currentDesktopIndex)
            selectedWindowIndex = -1
        }
    }
}
