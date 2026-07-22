import Quickshell
import QtQuick
import qs.modules.dock

// iPadOS-inspired top status bar.
PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    implicitHeight: 28
    exclusiveZone: implicitHeight

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 0
        left: 25
        right: 25
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
                // This font covers both Chinese and Latin glyphs, so the date
                // and English weekday use one consistent set of font metrics.
                family: "Noto Sans CJK SC"
                pixelSize: 14
                weight: Font.Bold
            }
            // Digits and Chinese glyphs can come from different fallback fonts.
            // Aligning their baselines, rather than their bounding-box centers,
            // keeps the visible bottoms of the time and date on one line.
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

        Battery {}
        // The tray tile has 2px of internal padding around its glyph; lifting
        // it by 2px keeps the battery only subtly higher, not misaligned.
        SysTray {
            iconSize: 14
            visualYOffset: -2
        }
    }
}
