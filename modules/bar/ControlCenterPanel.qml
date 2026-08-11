import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.modules.bar
import qs.modules.common
import qs.modules.dock
import qs.modules.notifications

// Compact desktop adaptation of the supplied Control Center reference.
// Its geometry intentionally stays small enough for a top-bar popup while
// preserving the reference's two-column, pill-and-media-card hierarchy.
//
// PER-CARD INDEPENDENT GLASS: instead of one PopupWindow with a single blur
// slab, each card is its own PanelWindow (ControlCenterCard) with its own
// compositor blur region. KWin's blur is per-window, so each card blurs
// exactly what is behind it (wallpaper AND open windows) and the gaps
// between cards show the real desktop - the iOS "hollow" control center.
// ControlCenterCoordinator owns the group so all cards open/close together.
Item {
    id: panel

    property Item anchorItem: null
    property real volumePreview: ControlCenterService.volumePercent
    property bool draggingVolume: false
    property real brightnessPreview: ControlCenterService.brightnessPercent
    property bool draggingBrightness: false
    property bool logoutConfirmationVisible: false
    readonly property var player: DockMprisService.activePlayer
    signal networkRequested()
    signal bluetoothRequested()

    // Bar reads this for sharedPanelOpen / toggle state.
    readonly property bool isOpen: coordinator.open

    // The target screen (the bar's output). Cards live on the same screen.
    readonly property var targetScreen: Quickshell.screens.length > 1
        ? Quickshell.screens[1] : Quickshell.screens[0]

    // Compact counterpart to the Dock player's transport controls. It keeps
    // the same circular glass treatment but is sized for this small panel.
    // When `liquidSource` is set (the media card's artwork backdrop), the
    // button becomes a frosted lens over that layer instead of a flat circle.
    component MediaControlButton: Item {
        id: button
        property string symbol: ""
        property bool primary: false
        property bool controlEnabled: true
        property Item liquidSource: null
        signal triggered()
        width: primary ? 28 : 24
        height: width
        opacity: controlEnabled ? 1.0 : 0.58
        scale: pointer.pressed ? 0.90 : (pointer.containsMouse ? 1.06 : 1.0)
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

        LiquidGlassControl {
            anchors.fill: parent
            sourceItem: button.liquidSource
            blurRadius: button.primary ? 11 : 8
            tintColor: Qt.rgba(1, 1, 1, button.primary ? 0.16 : 0.10)
            highlightStrength: 0.32
            borderColor: Qt.rgba(1, 1, 1, button.primary ? 0.40 : 0.28)
        }
        Text {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: button.symbol === "▶" ? 1 : 0
            text: button.symbol
            color: ThemeService.foregroundColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.50)
            font.pixelSize: button.primary ? 15 : 12
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            enabled: button.controlEnabled
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: button.triggered()
        }
    }

    ControlCenterCoordinator {
        id: coordinator
        // Aligned with the Wi-Fi panel: the panel's top edge sits at the bar
        // bottom (35) and its right edge is flushed to the screen right edge
        // after SlideX clamping. panelRight=0 puts the control center's right
        // edge at screen right - 20 (the rightmost cards use offsetRight=20),
        // and panelTop=35 matches the Wi-Fi panel's top.
        panelTop: 35
        panelRight: 0
    }

    function toggle(item) {
        anchorItem = item
        if (coordinator.open) {
            close()
        } else {
            ControlCenterService.refresh()
            coordinator.openAll()
        }
    }
    function close() {
        logoutConfirmationVisible = false
        coordinator.closeAll()
    }

    // ── Card 1: Wi-Fi ────────────────────────────────────────────────
    // Opens the Wi-Fi picker. Power toggle lives inside that picker.
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 20
        offsetRight: 179
        cardRadius: 29.5
        cardWidth: 137
        cardHeight: 59
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(0.74, 0.95, 1, 0.34)

        Rectangle {
            width: 39; height: 39; radius: width / 2
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            color: NetworkService.wifiEnabled ? "#f7fbff" : Qt.rgba(1, 1, 1, 0.22)
            Canvas {
                id: controlWifiGlyph
                anchors.centerIn: parent
                width: 20; height: 20
                property bool active: NetworkService.wifiEnabled
                property color glyphColor: active ? "#0a84ff" : "white"
                onActiveChanged: requestPaint()
                onGlyphColorChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = glyphColor
                    ctx.fillStyle = glyphColor
                    ctx.lineWidth = 1.55
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.scale(1.08, 1.08)
                    ctx.translate(0, -1.8)
                    const rings = NetworkService.signalStrength < 25 ? 1
                        : (NetworkService.signalStrength < 50 ? 2 : 3)
                    for (let ring = 0; ring < rings; ring++) {
                        const radius = 3.1 + ring * 2.45
                        ctx.beginPath()
                        ctx.arc(8, 14.2, radius, Math.PI * 1.22, Math.PI * 1.78)
                        ctx.stroke()
                    }
                    ctx.beginPath()
                    ctx.arc(8, 13.8, 1.15, 0, Math.PI * 2)
                    ctx.fill()
                }
                Connections {
                    target: NetworkService
                    function onSignalStrengthChanged() { controlWifiGlyph.requestPaint() }
                }
            }
        }
        Column {
            anchors { left: parent.left; right: parent.right; leftMargin: 58; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 1
            Text { width: parent.width; text: "Wi‑Fi"; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); font { pixelSize: 12; weight: Font.Bold } }
            Text { width: parent.width; text: NetworkService.wifiEnabled ? (NetworkService.ssid || "未连接") : "已关闭"; elide: Text.ElideRight; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.72; font.pixelSize: 10 }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: panel.networkRequested() }
    }

    // ── Card 2: Bluetooth ────────────────────────────────────────────
    // Disc toggles power; tapping the pill opens the device list.
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 87
        offsetRight: 179
        cardRadius: 29.5
        cardWidth: 137
        cardHeight: 59
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(0.74, 0.95, 1, 0.34)
        cardOpacity: ControlCenterService.bluetoothAvailable ? 1 : 0.48

        Rectangle {
            width: 39; height: 39; radius: width / 2
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            color: ControlCenterService.bluetoothPowered ? "#f7fbff" : Qt.rgba(1, 1, 1, 0.22)
            Canvas {
                anchors.centerIn: parent
                width: 21; height: 21
                property bool active: ControlCenterService.bluetoothPowered
                onActiveChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.strokeStyle = active ? "#0a84ff" : "white"
                    ctx.lineWidth = 2.0
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.scale(0.78, 0.78)
                    ctx.beginPath()
                    ctx.moveTo(13.5, 2.5)
                    ctx.lineTo(20, 9)
                    ctx.lineTo(13.5, 15)
                    ctx.lineTo(20, 21)
                    ctx.lineTo(13.5, 26.5)
                    ctx.lineTo(13.5, 2.5)
                    ctx.moveTo(7, 8.5)
                    ctx.lineTo(13.5, 15)
                    ctx.lineTo(7, 21.5)
                    ctx.stroke()
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: ControlCenterService.bluetoothAvailable && !ControlCenterService.bluetoothChangeInProgress
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: ControlCenterService.setBluetoothEnabled(!ControlCenterService.bluetoothPowered)
            }
        }
        Column {
            anchors { left: parent.left; right: parent.right; leftMargin: 58; rightMargin: 10; verticalCenter: parent.verticalCenter }
            spacing: 1
            Text { width: parent.width; text: "Bluetooth"; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); font { pixelSize: 12; weight: Font.Bold } }
            Text { width: parent.width; text: ControlCenterService.bluetoothPowered ? "已开启" : "已关闭"; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.72; font.pixelSize: 10 }
        }
        MouseArea {
            anchors.fill: parent
            enabled: ControlCenterService.bluetoothAvailable && !ControlCenterService.bluetoothChangeInProgress
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: panel.bluetoothRequested()
        }
    }

    // ── Card 3: Media player ─────────────────────────────────────────
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 20
        offsetRight: 20
        cardRadius: 25
        cardWidth: 151
        cardHeight: 127
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(0.72, 0.95, 1, 0.32)

        // A faint wallpaper-tone layer is both the card's quiet liquid base
        // and the blur source for the transport buttons. Blurring it makes
        // each button a frosted lens that absorbs the ambient wallpaper tint
        // (iOS-style), instead of a swatch of the album artwork.
        Rectangle {
            id: mediaBackdrop
            anchors.fill: parent
            radius: parent.cardRadius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(WallpaperPaletteService.primary.r, WallpaperPaletteService.primary.g, WallpaperPaletteService.primary.b, 0.16) }
                GradientStop { position: 1.0; color: Qt.rgba(WallpaperPaletteService.secondary.r, WallpaperPaletteService.secondary.g, WallpaperPaletteService.secondary.b, 0.07) }
            }
        }

        Rectangle {
            id: artwork
            width: 43; height: 43; radius: 13
            anchors { left: parent.left; top: parent.top; leftMargin: 13; topMargin: 13 }
            color: Qt.rgba(1, 1, 1, 0.18)
            Text { anchors.centerIn: parent; text: "♫"; color: "white"; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.86; font.pixelSize: 21 }
            Image {
                anchors.fill: parent
                source: panel.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: artworkMask
                }
            }
            Rectangle {
                id: artworkMask
                anchors.fill: parent
                radius: artwork.radius
                visible: false
                layer.enabled: true
            }
        }
        Column {
            anchors { left: artwork.right; right: parent.right; top: artwork.top; leftMargin: 8; rightMargin: 10 }
            spacing: 2
            Text { width: parent.width; text: panel.player?.trackTitle || "未在播放"; elide: Text.ElideRight; color: "white"; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); font { pixelSize: 12; weight: Font.Bold } }
            Text { width: parent.width; text: panel.player?.trackArtist || "媒体控制"; elide: Text.ElideRight; color: "white"; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.70; font.pixelSize: 10 }
        }
        Row {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 26; rightMargin: 26; bottomMargin: 15 }
            height: 28
            spacing: (width - 76) / 2
            Item {
                width: 24
                height: parent.height
                MediaControlButton {
                    anchors.centerIn: parent
                    symbol: "⏮"
                    liquidSource: mediaBackdrop
                    controlEnabled: panel.player?.canGoPrevious ?? false
                    onTriggered: DockMprisService.previous()
                }
            }
            MediaControlButton {
                primary: true
                symbol: panel.player?.isPlaying ? "⏸" : "▶"
                liquidSource: mediaBackdrop
                controlEnabled: panel.player !== null
                onTriggered: DockMprisService.togglePlayPause()
            }
            Item {
                width: 24
                height: parent.height
                MediaControlButton {
                    anchors.centerIn: parent
                    symbol: "⏭"
                    liquidSource: mediaBackdrop
                    controlEnabled: panel.player?.canGoNext ?? false
                    onTriggered: DockMprisService.next()
                }
            }
        }
    }

    // ── Card 4: Screenshot ───────────────────────────────────────────
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 155
        offsetRight: 262
        cardRadius: 27
        cardWidth: 54
        cardHeight: 54
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(1, 1, 1, 0.24)

        cardScale: screenshotPointer.pressed ? 0.91 : (screenshotPointer.containsMouse ? 1.06 : 1.0)
        Behavior on cardScale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Image {
            anchors.centerIn: parent
            width: 25
            height: 25
            source: "../../assets/screenshot.svg"
            sourceSize.width: 46
            sourceSize.height: 46
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        MouseArea { id: screenshotPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ControlCenterService.captureInteractiveScreenshot() }
    }

    // ── Card 5: Logout ───────────────────────────────────────────────
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 155
        offsetRight: 198
        cardRadius: 27
        cardWidth: 54
        cardHeight: 54
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(1, 1, 1, 0.24)

        cardScale: logoutPointer.pressed ? 0.91 : (logoutPointer.containsMouse ? 1.06 : 1.0)
        Behavior on cardScale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Image {
            anchors.centerIn: parent
            width: 24
            height: 24
            source: "../../assets/logout.svg"
            sourceSize.width: 48
            sourceSize.height: 48
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        MouseArea { id: logoutPointer; anchors.fill: parent; hoverEnabled: true; enabled: !ControlCenterService.logoutInProgress; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: panel.logoutConfirmationVisible = true }
    }

    // ── Card 6: Do Not Disturb ───────────────────────────────────────
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 155
        offsetRight: 20
        cardRadius: 27
        cardWidth: 168
        cardHeight: 54
        cardColor: "transparent"
        cardBorderColor: ControlCenterService.doNotDisturbEnabled
            ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.24)

        cardScale: dndPointer.pressed ? 0.97 : (dndPointer.containsMouse ? 1.025 : 1.0)
        Behavior on cardScale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Image {
            anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
            width: 23
            height: 23
            source: "../../assets/do-not-disturb.svg"
            sourceSize.width: 46
            sourceSize.height: 46
            fillMode: Image.PreserveAspectFit
            smooth: true
            layer.enabled: ControlCenterService.doNotDisturbEnabled
            layer.effect: MultiEffect {
                colorization: 1.0
                colorizationColor: "#0a84ff"
            }
        }
        Text {
            anchors { left: parent.left; leftMargin: 51; verticalCenter: parent.verticalCenter }
            text: "勿扰模式"
            color: ThemeService.foregroundColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.50)
            font { pixelSize: 12; weight: Font.Bold }
        }
        MouseArea { id: dndPointer; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ControlCenterService.toggleDoNotDisturb() }
    }

    // ── Card 7: Display brightness ───────────────────────────────────
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 217
        offsetRight: 20
        cardRadius: 19
        cardWidth: 296
        cardHeight: 57
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(1, 1, 1, 0.14)

        Text { anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 8 } text: "显示亮度"; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.56; font { pixelSize: 11; weight: Font.DemiBold } }
        Text { anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 8 } text: ControlCenterService.brightnessAvailable ? Math.round(panel.brightnessPreview) + "%" : "无亮度设备"; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.40; font.pixelSize: 9 }
        Rectangle {
            id: brightnessTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 31; rightMargin: 31; bottomMargin: 12 }
            height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.17)
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, panel.brightnessPreview / 100))
                height: parent.height; radius: parent.radius; color: Qt.rgba(1, 1, 1, 0.42)
            }
            MouseArea {
                enabled: ControlCenterService.brightnessAvailable
                anchors { fill: parent; margins: -10 }
                onPressed: function(mouse) {
                    panel.draggingBrightness = true
                    panel.brightnessPreview = Math.round(Math.max(0, Math.min(1, mouse.x / brightnessTrack.width)) * 100)
                }
                onPositionChanged: function(mouse) {
                    if (pressed)
                        panel.brightnessPreview = Math.round(Math.max(0, Math.min(1, mouse.x / brightnessTrack.width)) * 100)
                }
                onReleased: {
                    panel.draggingBrightness = false
                    ControlCenterService.setBrightness(panel.brightnessPreview)
                }
            }
        }
        Text { anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 5 } text: "☀"; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.55; font.pixelSize: 13 }
    }

    // ── Card 8: Sound / volume ───────────────────────────────────────
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 282
        offsetRight: 20
        cardRadius: 19
        cardWidth: 296
        cardHeight: 57
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(0.72, 0.93, 1, 0.27)

        Text { anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 8 } text: "声音"; color: "white"; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); font { pixelSize: 11; weight: Font.DemiBold } }
        Text { anchors { right: parent.right; top: parent.top; rightMargin: 14; topMargin: 8 } text: Math.round(panel.volumePreview) + "%"; color: "white"; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); opacity: 0.72; font.pixelSize: 10 }
        Canvas {
            id: volumeGlyph
            anchors { left: parent.left; leftMargin: 12; bottom: parent.bottom; bottomMargin: 7 }
            width: 15
            height: 15
            onPaint: {
                const ctx = getContext("2d")
                ctx.reset()
                ctx.strokeStyle = "white"
                ctx.fillStyle = "white"
                ctx.lineWidth = 1.7
                ctx.lineJoin = "round"
                ctx.fillRect(1, 6, 3.5, 4)
                ctx.beginPath(); ctx.moveTo(4.3, 6); ctx.lineTo(8, 3); ctx.lineTo(8, 13); ctx.lineTo(4.3, 10); ctx.closePath(); ctx.fill()
                if (!ControlCenterService.audioMuted) {
                    ctx.lineCap = "round"
                    ctx.beginPath(); ctx.arc(7.2, 8, 4, -0.8, 0.8); ctx.stroke()
                } else {
                    ctx.beginPath(); ctx.moveTo(10.5, 4.5); ctx.lineTo(14, 11.5); ctx.stroke()
                }
            }
            Connections { target: ControlCenterService; function onAudioMutedChanged() { volumeGlyph.requestPaint() } }
        }
        Rectangle {
            id: volumeTrack
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; leftMargin: 34; rightMargin: 17; bottomMargin: 13 }
            height: 5; radius: 2.5; color: Qt.rgba(0, 0, 0, 0.20)
            Rectangle { width: parent.width * Math.max(0, Math.min(1, panel.volumePreview / 100)); height: parent.height; radius: parent.radius; color: "white" }
            MouseArea {
                anchors { fill: parent; margins: -10 }
                onPressed: function(mouse) { panel.draggingVolume = true; panel.volumePreview = Math.round(Math.max(0, Math.min(1, mouse.x / volumeTrack.width)) * 100) }
                onPositionChanged: function(mouse) { if (pressed) panel.volumePreview = Math.round(Math.max(0, Math.min(1, mouse.x / volumeTrack.width)) * 100) }
                onReleased: { panel.draggingVolume = false; ControlCenterService.setVolume(panel.volumePreview) }
            }
        }
    }

    // ── Card 9: Notification history ─────────────────────────────────
    ControlCenterCard {
        coordinator: coordinator
        offsetTop: 347
        offsetRight: 20
        cardRadius: 19
        cardWidth: 296
        cardHeight: 110
        cardColor: "transparent"
        cardBorderColor: Qt.rgba(1, 1, 1, 0.14)

        Item {
            anchors { fill: parent; margins: 10 }

            Text {
                id: historyTitle
                text: "通知历史"
                color: ThemeService.foregroundColor
                font { pixelSize: 12; weight: Font.Bold }
                anchors { left: parent.left; top: parent.top }
            }
            Text {
                text: "清空"
                color: clearMouse.containsMouse ? "#0a84ff" : Qt.rgba(1, 1, 1, 0.50)
                font { pixelSize: 11 }
                anchors { right: parent.right; top: parent.top }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ControlCenterService.notificationHistory.clear()
                }
            }
            ListView {
                id: historyList
                anchors {
                    left: parent.left
                    right: parent.right
                    top: historyTitle.bottom
                    topMargin: 6
                    bottom: parent.bottom
                }
                model: ControlCenterService.notificationHistory
                clip: true
                interactive: true
                spacing: 4

                delegate: Item {
                    width: historyList.width
                    height: histSummary.implicitHeight + (histBody.visible ? histBody.implicitHeight + 2 : 0)

                    Text {
                        id: histSummary
                        width: parent.width
                        text: (appName.length > 0 ? appName + " · " : "") + (summary.length > 0 ? summary : "通知")
                        color: ThemeService.foregroundColor
                        font { pixelSize: 11; weight: Font.Bold }
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        id: histBody
                        anchors.top: histSummary.bottom
                        anchors.topMargin: 1
                        width: parent.width
                        visible: text.length > 0
                        text: body
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: historyList.count === 0
                    text: "暂无历史通知"
                    color: Qt.rgba(1, 1, 1, 0.30)
                    font.pixelSize: 11
                }
            }
        }
    }

    // ── Logout confirmation overlay (independent window on top) ──────
    // A dark sheet over the whole control-center area with the confirm pair.
    // Declared last so it stacks above all cards.
    ControlCenterCard {
        coordinator: coordinator
        managedByCoordinator: false
        offsetTop: 0
        offsetRight: 20
        cardRadius: 0
        cardWidth: 336
        cardHeight: 477
        cardColor: "transparent"
        cardBorderColor: "transparent"
        cardShown: panel.logoutConfirmationVisible
        // cardColor transparent + no blur region on this sheet would show the
        // cards through; give it an opaque dark fill so it reads as a modal.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.52)
            radius: 34
            MouseArea {
                anchors.fill: parent
                onClicked: panel.logoutConfirmationVisible = false
            }
        }
        Rectangle {
            width: 236
            height: 154
            anchors.centerIn: parent
            radius: 23
            color: Qt.rgba(0.07, 0.08, 0.11, 0.62)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.32)

            Image {
                anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 16 }
                width: 28
                height: 28
                source: "../../assets/logout.svg"
                sourceSize.width: 56
                sourceSize.height: 56
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
            Text {
                anchors { top: parent.top; topMargin: 49; horizontalCenter: parent.horizontalCenter }
                text: "要注销吗？"
                color: ThemeService.foregroundColor
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.50)
                font { pixelSize: 15; weight: Font.Bold }
            }
            Text {
                anchors { top: parent.top; topMargin: 72; horizontalCenter: parent.horizontalCenter }
                text: "未保存的内容可能会丢失"
                color: ThemeService.foregroundColor
                opacity: 0.66
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.50)
                font.pixelSize: 10
            }
            Row {
                anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
                spacing: 10
                Rectangle {
                    width: 94
                    height: 34
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.24)
                    Text { anchors.centerIn: parent; text: "取消"; color: ThemeService.foregroundColor; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); font { pixelSize: 12; weight: Font.DemiBold } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: panel.logoutConfirmationVisible = false }
                }
                Rectangle {
                    width: 94
                    height: 34
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.12)
                    border.width: 1
                    border.color: "#ff453a"
                    Text { anchors.centerIn: parent; text: "注销"; color: "#ff6961"; style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.50); font { pixelSize: 12; weight: Font.Bold } }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            panel.logoutConfirmationVisible = false
                            ControlCenterService.logoutCurrentSession()
                        }
                    }
                }
            }
        }
    }

    // ── Volume / brightness sync from the service ────────────────────
    Connections {
        target: ControlCenterService
        function onVolumePercentChanged() {
            if (!panel.draggingVolume)
                panel.volumePreview = ControlCenterService.volumePercent
        }
        function onBrightnessPercentChanged() {
            if (!panel.draggingBrightness)
                panel.brightnessPreview = ControlCenterService.brightnessPercent
        }
    }
}
