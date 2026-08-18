import QtQuick
import qs.desktop
import qs.desktop.modules.dock

Item {
    id: root

    implicitWidth: 24
    implicitHeight: 24

    Rectangle {
        anchors.centerIn: parent
        width: 24
        height: 24
        radius: width / 2
        color: pointer.containsMouse ? Qt.rgba(1, 1, 1, 0.20) : "transparent"
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -0.5
        text: "⚙"
        color: ThemeService.foregroundColor
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.36)
        font.pixelSize: 16
    }

    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: DesktopAppLauncher.openSettings()
    }
}
