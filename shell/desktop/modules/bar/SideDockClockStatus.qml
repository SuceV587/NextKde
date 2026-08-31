import QtQuick
import Quickshell
import qs.desktop.modules.dock

// Compact upright clock for a fused left/right Dock. DockContainer rotates
// its content Row by +90 degrees; this content counter-rotates by -90 so the
// glyphs remain readable while the root's width becomes vertical Dock length.
Item {
    id: root

    implicitWidth: Math.max(50, Math.round(ConfigService.baseHeight * 0.88))
    implicitHeight: 24

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Column {
        anchors.centerIn: parent
        rotation: -90
        spacing: -1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "hh:mm:ss")
            color: ThemeService.foregroundColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.38)
            font {
                family: "SF Pro Display"
                pixelSize: 11
                weight: Font.Bold
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "M月d日 ddd")
            color: ThemeService.foregroundColor
            opacity: 0.76
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.32)
            font {
                family: "Noto Sans CJK SC"
                pixelSize: 8
                weight: Font.Medium
            }
        }
    }
}
