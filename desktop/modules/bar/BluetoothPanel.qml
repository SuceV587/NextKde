import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.desktop.modules.bar
import qs.desktop.modules.common
import qs.desktop.modules.dock

// First Bluetooth picker stage: known/paired devices can be connected or
// disconnected here. Pairing discovery and PIN workflows stay out of this
// compact popup until their full interaction can be implemented safely.
PopupWindow {
    id: panel

    property Item anchorItem: null
    implicitWidth: 300
    implicitHeight: 340
    color: "transparent"
    grabFocus: true
    anchor { item: panel.anchorItem; edges: Edges.Bottom; gravity: Edges.Bottom; margins.bottom: -6 }

    // Real liquid glass: compositor blur region so windows behind the device
    // list are visible through the glass. Stepped region encodes the radius
    // (top scanline at x=blurRadius) so the plugin rounds corners exactly.
    readonly property int blurRadius: Math.max(1, Math.min(20, Math.floor(300 / 2)))
    BackgroundEffect.blurRegion: Region {
        x: panel.blurRadius
        y: 0
        width: 300 - panel.blurRadius
        height: 1
        Region {
            x: 0
            y: 1
            width: 300
            height: 340 - 1
        }
    }

    function open(item) {
        anchorItem = item
        visible = true
        ControlCenterService.refresh()
        ControlCenterService.refreshBluetoothDevices()
    }

    function close() {
        visible = false
    }

    function openBluetoothSettings() {
        close()
        bluetoothSettingsProcess.running = true
    }

    Process {
        id: bluetoothSettingsProcess
        command: ["systemsettings", "kcm_bluetooth"]
        stderr: StdioCollector {}
    }

    Connections {
        target: ControlCenterService
        function onBluetoothPoweredChanged() {
            if (panel.visible && ControlCenterService.bluetoothPowered)
                ControlCenterService.refreshBluetoothDevices()
        }
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        radius: 20
        // Transparent so the compositor blur region shows through - real
        // liquid glass with windows visible behind the device list.
        color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        border.color: Qt.rgba(0.74, 0.95, 1, 0.30)

        ListView {
            id: deviceList
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: settingsFooter.top; leftMargin: 8; rightMargin: 8; topMargin: 8; bottomMargin: 0 }
            clip: true
            spacing: 2
            model: ControlCenterService.bluetoothPowered ? ControlCenterService.bluetoothDevices : []
            delegate: Rectangle {
                required property var modelData
                width: deviceList.width
                height: 46
                radius: 11
                color: devicePointer.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                Behavior on color { ColorAnimation { duration: 110 } }
                Canvas {
                    width: 18; height: 18
                    anchors { left: parent.left; leftMargin: 31; verticalCenter: parent.verticalCenter }
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.reset(); ctx.strokeStyle = ThemeService.foregroundColor; ctx.lineWidth = 1.8
                        ctx.lineCap = "round"; ctx.lineJoin = "round"; ctx.scale(0.67, 0.67)
                        ctx.beginPath(); ctx.moveTo(13.5, 2.5); ctx.lineTo(20, 9); ctx.lineTo(13.5, 15); ctx.lineTo(20, 21); ctx.lineTo(13.5, 26.5); ctx.lineTo(13.5, 2.5); ctx.moveTo(7, 8.5); ctx.lineTo(13.5, 15); ctx.lineTo(7, 21.5); ctx.stroke()
                    }
                }
                Text {
                    visible: modelData.connected
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: "✓"
                    color: ThemeService.foregroundColor
                    style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50)
                    font { pixelSize: 18; weight: Font.DemiBold }
                }
                Text {
                    anchors { left: parent.left; right: parent.right; leftMargin: 58; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: modelData.name
                    elide: Text.ElideRight
                    color: ThemeService.foregroundColor
                    style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50)
                    font { pixelSize: 12; weight: Font.DemiBold }
                }
                MouseArea {
                    id: devicePointer
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !ControlCenterService.bluetoothDeviceChangeInProgress
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: ControlCenterService.setBluetoothDeviceConnected(modelData, !modelData.connected)
                }
            }
            GlassText {
                anchors.centerIn: parent
                visible: ControlCenterService.bluetoothPowered
                    && !ControlCenterService.bluetoothDevicesRefreshInProgress
                    && ControlCenterService.bluetoothDevices.length === 0
                text: "未发现已配对设备"
                color: ThemeService.foregroundColor
                opacity: 0.52
                font.pixelSize: 12
            }
            GlassText {
                anchors.centerIn: parent
                visible: ControlCenterService.bluetoothDevicesRefreshInProgress
                text: "正在刷新…"
                color: ThemeService.foregroundColor
                opacity: 0.52
                font.pixelSize: 12
            }
            GlassText {
                anchors.centerIn: parent
                visible: !ControlCenterService.bluetoothPowered
                text: "蓝牙已关闭"
                color: ThemeService.foregroundColor
                opacity: 0.52
                font.pixelSize: 12
            }
        }

        Item {
            id: settingsFooter
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 50
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: Qt.rgba(1, 1, 1, 0.16)
            }
            Text {
                anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                text: "蓝牙设置…"
                color: ThemeService.foregroundColor
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.50)
                font { pixelSize: 14; weight: Font.DemiBold }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.openBluetoothSettings()
            }
        }
    }
}
