import QtQuick
import Quickshell
import qs.modules.bar
import qs.modules.dock

// Passive first-stage network indicator. Connection controls will later use
// NetworkService too, while this component remains only a visual consumer.
Item {
    id: root

    signal panelToggleRequested()
    property bool sharedPanelOpen: false

    // Reserve the same visual footprint as the adjacent status glyphs. Wi-Fi
    // arcs occupy only part of a nominal canvas, so a 16px canvas looked both
    // smaller and lower than Battery/CPU despite Row centering correctly.
    implicitWidth: 21
    implicitHeight: 18
    width: implicitWidth
    height: implicitHeight
    visible: NetworkService.available

    readonly property bool hasIssue: NetworkService.connectivity === "portal"
        || NetworkService.connectivity === "limited"
        || (NetworkService.deviceState === "connected"
            && NetworkService.connectivity === "none")
    readonly property bool connected: NetworkService.deviceState === "connected"
    // Do not use themed symbolic colours here: KDE themes can render them
    // black, which disappears on a transparent status bar. A tiny Canvas
    // keeps the same crisp white foreground across every wallpaper/theme.
    Canvas {
        id: networkGlyph
        anchors.centerIn: parent
        width: 20
        height: 20
        opacity: root.connected ? 0.96 : 0.68
        onPaint: {
            const ctx = getContext("2d")
            ctx.reset()
            ctx.strokeStyle = "white"
            ctx.fillStyle = "white"
            ctx.lineWidth = 1.55
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            // Give the stroke the same visual weight as the 17px CPU glyph.
            // Wi-Fi's fan is optically low within its bounding box; raise
            // only that variant instead of offsetting Ethernet as well.
            ctx.scale(1.08, 1.08)
            if (NetworkService.connectionType === "wifi")
                ctx.translate(0, -1.8)
            if (NetworkService.connectionType === "ethernet") {
                ctx.strokeRect(2.5, 2.2, 11, 8.2)
                ctx.beginPath()
                ctx.moveTo(5, 13.3); ctx.lineTo(11, 13.3)
                ctx.moveTo(6, 10.4); ctx.lineTo(6, 13.3)
                ctx.moveTo(10, 10.4); ctx.lineTo(10, 13.3)
                ctx.stroke()
            } else if (NetworkService.connectionType === "wifi") {
                const rings = NetworkService.signalStrength < 25 ? 1
                    : (NetworkService.signalStrength < 50 ? 2 : 3)
                for (let ring = 0; ring < rings; ring++) {
                    const radius = 3.1 + ring * 2.45
                    ctx.beginPath()
                    ctx.arc(8, 14.2, radius, Math.PI * 1.25, Math.PI * 1.75)
                    ctx.stroke()
                }
                ctx.beginPath()
                ctx.arc(8, 13.8, 1.15, 0, Math.PI * 2)
                ctx.fill()
            } else {
                ctx.beginPath()
                ctx.arc(8, 8, 5.4, 0, Math.PI * 2)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(4.2, 4.2); ctx.lineTo(11.8, 11.8)
                ctx.stroke()
            }
        }
        Connections {
            target: NetworkService
            function onConnectionTypeChanged() { networkGlyph.requestPaint() }
            function onSignalStrengthChanged() { networkGlyph.requestPaint() }
            function onDeviceStateChanged() { networkGlyph.requestPaint() }
        }
    }

    Rectangle {
        // Preserve the connection medium icon and add only a tiny warning
        // badge; replacing it with a generic offline mark hides useful info.
        visible: root.hasIssue
        width: 6
        height: 6
        radius: width / 2
        anchors { right: parent.right; bottom: parent.bottom }
        color: NetworkService.connectivity === "none" ? "#ff9f0a" : "#ffb340"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.35)
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        onClicked: root.panelToggleRequested()
    }

    PopupWindow {
        id: tooltip
        visible: hoverArea.containsMouse && !root.sharedPanelOpen
        implicitWidth: Math.max(150, tooltipColumn.implicitWidth + 18)
        implicitHeight: tooltipColumn.implicitHeight + 14
        color: "transparent"
        anchor {
            item: root
            edges: Edges.Bottom
            gravity: Edges.Bottom
            margins.bottom: -6
        }

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: ThemeService.tooltipBackground
            Column {
                id: tooltipColumn
                anchors.centerIn: parent
                spacing: 3
                Text {
                    text: root.connected
                        ? (NetworkService.connectionType === "ethernet"
                            ? "有线网络" : (NetworkService.ssid || "Wi‑Fi"))
                        : (NetworkService.deviceState === "connecting"
                            ? "正在连接网络…" : "未连接网络")
                    color: ThemeService.foregroundColor
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.38)
                    font { pixelSize: 12; weight: Font.DemiBold }
                }
                Text {
                    visible: root.connected
                    text: root.hasIssue
                        ? (NetworkService.connectivity === "portal"
                            ? "需要网页登录认证" : "网络受限，无法访问互联网")
                        : (NetworkService.ipv4.length > 0
                            ? "已连接 · " + NetworkService.ipv4 : "已连接互联网")
                    color: ThemeService.foregroundColor
                    opacity: 0.66
                    font.pixelSize: 10
                }
            }
        }
    }

}
