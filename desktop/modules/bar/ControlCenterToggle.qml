import QtQuick
import Quickshell
import qs.desktop.modules.dock

// Fixed transparent SVG keeps this dual-toggle mark independent from icon
// themes while giving it enough visual weight in the status area.
Item {
    id: root
    signal panelToggleRequested()
    property bool panelOpen: false
    implicitWidth: 24
    implicitHeight: 24
    width: implicitWidth
    height: implicitHeight

    Image {
        anchors.centerIn: parent
        width: 16
        height: 16
        source: "../../assets/control-center.svg"
        sourceSize.width: 46
        sourceSize.height: 46
        fillMode: Image.PreserveAspectFit
        smooth: true
        opacity: root.panelOpen ? 1.0 : 0.88
    }
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.panelToggleRequested()
    }
    PopupWindow {
        visible: hoverArea.containsMouse && !root.panelOpen
        implicitWidth: 92; implicitHeight: 26; color: "transparent"
        anchor { item: root; edges: Edges.Bottom; gravity: Edges.Bottom; margins.bottom: -5 }
        Rectangle { anchors.fill: parent; radius: 7; color: ThemeService.tooltipBackground
            Text { anchors.centerIn: parent; text: "控制中心"; color: ThemeService.foregroundColor; font.pixelSize: 10 }
        }
    }
}
