import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.dock

// iPadOS-inspired top status bar for one concrete output.
PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    // Keep persistent chrome on the normal layer-shell Top layer.
    WlrLayershell.layer: WlrLayer.Top
    implicitHeight: 35
    exclusiveZone: implicitHeight

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 0
        left: 15
        right: 15
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: dateStatus
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        spacing: 7

        Text {
            id: timeText
            text: Qt.formatDateTime(clock.date, "h:mm")
            color: ThemeService.foregroundColor
            font {
                family: "SF Pro Display"
                pixelSize: 14
                weight: Font.Bold
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: dateText
            text: Qt.formatDateTime(clock.date, "M月d日 dddd")
            color: ThemeService.foregroundColor
            font {
                family: "Noto Sans CJK SC"
                pixelSize: 14
                weight: Font.Bold
            }
            anchors.baseline: timeText.baseline
        }
    }

    Row {
        id: statusArea
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 10

        CpuTemperature {}
        Battery {}
        SysTray {
            iconSize: 16
            visualYOffset: -2
        }
    }
}
