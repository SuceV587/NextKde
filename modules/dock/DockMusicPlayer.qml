import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import qs.modules.common

// ────────────────────────────────────────────────────────────────
// DockMusicPlayer — Music player widget sized in icon-width units.
//
// Binds to DockMprisService.activePlayer reactively.  Two modes:
//   - Compact (iconSize < 36):  album art only with a tiny play/pause overlay
//   - Full (iconSize ≥ 36):     art + track title/artist + prev/play/next buttons
//
// Expand/collapse animation when hasPlayer toggles.
// ────────────────────────────────────────────────────────────────

Item {
    id: widget

    // ── Inputs ──
    property int iconSize: 44
    property int dockHeight: 60
    property int widthUnits: 4

    // ── Derived ──
    readonly property real artSize: Math.min(iconSize, dockHeight - widget.vPadding * 2)
    readonly property int vPadding: Math.round(iconSize * 0.20)
    readonly property bool isCompact: iconSize < 36
    readonly property real backgroundGap: iconSize * 0.1
    readonly property real contentWidth: iconSize * widthUnits

    // ── Player reference ──
    readonly property var player: DockMprisService.activePlayer

    function artworkTint(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }

    // The content itself is exactly iconSize high. The outer slot includes
    // the same 0.1*iconSize margin used by active app backgrounds, and this
    // extra width is included by AdaptiveMath during width fitting.
    width: contentWidth + backgroundGap * 2
    height: iconSize

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    // ── Expand / collapse animation ──
    clip: false
    Behavior on width {
        NumberAnimation {
            duration: DockAnimation.musicExpandDuration
            easing.type: DockAnimation.musicExpandEasing
        }
    }

    // ═══════════════════════════════════════════════════════════
    // Content
    // ═══════════════════════════════════════════════════════════
    Rectangle {
        id: playerBackground
        anchors.horizontalCenter: parent.horizontalCenter
        y: -widget.backgroundGap
        width: widget.width
        height: widget.iconSize + widget.backgroundGap * 2
        radius: widget.iconSize * 0.3
        color: "transparent"
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0.0
                color: widget.artworkTint(artworkPalette.primary, 0.82)
            }
            GradientStop {
                position: 0.52
                color: widget.artworkTint(artworkPalette.secondary, 0.64)
            }
            GradientStop {
                position: 1.0
                color: widget.artworkTint(artworkPalette.primary, 0.38)
            }
        }
        z: -1
    }

    ArtworkPalette {
        id: artworkPalette
        source: widget.player?.trackArtUrl ?? ""
    }

    Row {
        id: musicRow
        anchors.centerIn: parent
        spacing: Math.round(widget.iconSize * 0.09)
        height: widget.artSize

        // ── Album art ──
        Rectangle {
            width: widget.artSize
            height: widget.artSize
            radius: 6
            color: ThemeService.dividerColor
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: albumArtMask
                anchors.fill: parent
                radius: 6
                visible: false
                layer.enabled: true
            }

            Image {
                id: albumArt
                anchors.fill: parent
                source: widget.player?.trackArtUrl ?? ""
                asynchronous: true
                cache: true
                fillMode: Image.PreserveAspectCrop
                smooth: true
                layer.enabled: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: albumArtMask
                }
            }

            // Play/pause overlay on art (compact mode mostly)
            Rectangle {
                anchors.centerIn: parent
                width: 18
                height: 18
                radius: 9
                color: Qt.rgba(0, 0, 0, 0.55)
                visible: widget.isCompact
                Text {
                    anchors.centerIn: parent
                    text: widget.player?.isPlaying ? "⏸" : "▶"
                    color: "white"
                    font.pixelSize: 10
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: DockMprisService.togglePlayPause()
                }
            }
        }

        // ── Track info + controls (full mode) ──
        Column {
            anchors.verticalCenter: parent.verticalCenter
            visible: !widget.isCompact
            width: Math.max(0, widget.contentWidth - widget.artSize - musicRow.spacing - widget.vPadding * 2)
            spacing: 1

            // Track title + artist marquee
            Item {
                id: trackViewport
                width: parent.width
                height: Math.max(trackTitle.implicitHeight, trackArtist.implicitHeight)
                clip: true

                Row {
                    id: trackMarquee
                    property real scrollOffset: 0

                    x: width <= trackViewport.width
                        ? (trackViewport.width - width) / 2
                        : scrollOffset
                    height: parent.height
                    spacing: 6

                    Text {
                        id: trackTitle
                        anchors.verticalCenter: parent.verticalCenter
                        text: widget.player?.trackTitle ?? "No Track"
                        color: ThemeService.foregroundColor
                        font.pixelSize: Math.max(12, widget.iconSize * 0.28)
                        font.weight: Font.Bold
                    }

                    Text {
                        id: trackArtist
                        anchors.verticalCenter: parent.verticalCenter
                        text: widget.player?.trackArtist
                            ? "·  " + widget.player.trackArtist
                            : ""
                        color: "#fff"
                        font.pixelSize: Math.max(8, widget.iconSize * 0.19)
                    }

                    SequentialAnimation on scrollOffset {
                        id: trackScroll
                        running: trackMarquee.width > trackViewport.width
                        loops: Animation.Infinite

                        PauseAnimation { duration: 1200 }
                        NumberAnimation {
                            from: 0
                            to: -(trackMarquee.width - trackViewport.width)
                            duration: Math.max(900,
                                (trackMarquee.width - trackViewport.width) * 35)
                            easing.type: Easing.Linear
                        }
                        PauseAnimation { duration: 800 }
                        PropertyAction { value: 0 }

                        onRunningChanged: {
                            if (!running)
                                trackMarquee.scrollOffset = 0;
                        }
                    }
                }
            }

            // Playback controls
            Row {
                spacing: Math.round(widget.iconSize * 0.07)
                anchors.horizontalCenter: parent.horizontalCenter

                DockPrevBtn {
                    enabled: widget.player?.canGoPrevious ?? false
                }

                DockPlayBtn {
                    enabled: widget.player !== null
                    isPlaying: widget.player?.isPlaying ?? false
                }

                DockNextBtn {
                    enabled: widget.player?.canGoNext ?? false
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // Mini playback buttons
    // ═══════════════════════════════════════════════════════════

    // Previous button
    component DockPrevBtn: Text {
        property bool enabled: true
        text: "⏮"  // ⏮
        font.pixelSize: Math.max(14, widget.iconSize * 0.35)
        color: enabled ? ThemeService.foregroundColor : ThemeService.dividerColor
        opacity: enabled ? 1.0 : 0.3
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        MouseArea {
            anchors.fill: parent
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            onClicked: DockMprisService.previous()
        }
    }

    // Play/Pause button
    component DockPlayBtn: Text {
        property bool enabled: true
        property bool isPlaying: false
        text: isPlaying ? "⏸" : "▶"  // ⏸ or ▶
        font.pixelSize: Math.max(16, widget.iconSize * 0.40)
        color: enabled ? ThemeService.foregroundColor : ThemeService.dividerColor
        opacity: enabled ? 1.0 : 0.3
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        MouseArea {
            anchors.fill: parent
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            onClicked: DockMprisService.togglePlayPause()
        }
    }

    // Next button
    component DockNextBtn: Text {
        property bool enabled: true
        text: "⏭"  // ⏭
        font.pixelSize: Math.max(14, widget.iconSize * 0.35)
        color: enabled ? ThemeService.foregroundColor : ThemeService.dividerColor
        opacity: enabled ? 1.0 : 0.3
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        MouseArea {
            anchors.fill: parent
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            enabled: parent.enabled
            onClicked: DockMprisService.next()
        }
    }
}
