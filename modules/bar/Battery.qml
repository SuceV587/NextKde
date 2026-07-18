import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.modules.dock

// Compact battery indicator with charging-state colours and hover details.
Item {
    id: root

    implicitWidth: 25
    implicitHeight: 14
    width: implicitWidth
    height: implicitHeight

    Rectangle {
        id: outline
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        width: 21
        height: 12
        radius: 3.5
        color: "transparent"
        border {
            width: 1.5
            color: ThemeService.foregroundColor
        }
    }

    Rectangle {
        anchors {
            left: outline.right
            verticalCenter: outline.verticalCenter
        }
        width: 2
        height: 5
        radius: 1
        color: ThemeService.foregroundColor
    }

    Rectangle {
        anchors {
            left: outline.left
            verticalCenter: outline.verticalCenter
            leftMargin: 2
        }
        width: batteryDevice.ready && root.percent > 0
            ? Math.max(2, (outline.width - 4) * root.level)
            : 0
        height: outline.height - 4
        radius: 2
        color: root.fillColor
    }

    Text {
        anchors.centerIn: outline
        visible: root.isCharging
        text: "⚡"
        color: root.boltColor
        font.pixelSize: 9
        font.bold: true
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
    }

    PopupWindow {
        id: tooltip
        visible: hoverArea.containsMouse && batteryDevice.ready
        implicitWidth: tooltipText.implicitWidth + 16
        implicitHeight: tooltipText.implicitHeight + 10
        color: "transparent"
        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.bottom: -6
        }

        Rectangle {
            anchors.fill: parent
            radius: 6
            color: ThemeService.tooltipBackground

            Text {
                id: tooltipText
                anchors.centerIn: parent
                text: root.isCharging
                    ? "充电中 · " + root.percent + "%"
                    : "电池 · " + root.percent + "%"
                color: ThemeService.foregroundColor
                font {
                    family: "Noto Sans CJK SC"
                    pixelSize: 12
                    weight: Font.DemiBold
                }
            }
        }
    }

    readonly property var batteryDevice: UPower.displayDevice
    readonly property real level: batteryDevice.ready
        ? Math.max(0, Math.min(1, batteryDevice.percentage))
        : 0
    readonly property int percent: Math.round(level * 100)
    readonly property bool isCharging: batteryDevice.ready
        && (batteryDevice.state === UPowerDeviceState.Charging
            || batteryDevice.state === UPowerDeviceState.PendingCharge)
    readonly property color fillColor: percent > 95
        ? "#30d158"
        : percent >= 50
            ? "#ffffff"
            : percent >= 15
                ? "#ff9f0a"
                : "#ff453a"
    readonly property color boltColor: percent >= 50 && percent <= 95
        ? "#ff9f0a" : "#ffffff"
}
