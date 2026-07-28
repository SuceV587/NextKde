import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Wayland
import qs.modules.common

// Pixel capture stays in KWin. This popup displays the high-DPI runtime PNG
// returned through WindowService.
PopupWindow {
    id: preview

    property Item anchorItem: null
    property string windowId: ""
    property string title: ""
    // Exposed to the owning DockIcon so it can bridge pointer movement across
    // the gap between two separate Wayland popup surfaces.
    property bool pointerInside: previewMouse.containsMouse

    signal activateRequested()

    implicitWidth: 332
    implicitHeight: 232
    color: "transparent"
    grabFocus: false

    anchor {
        item: preview.anchorItem
        edges: Edges.Top
        gravity: Edges.Top
        margins.top: -10
    }

    readonly property string thumbnailSource: {
        WindowService.thumbnailRevision
        return WindowService.thumbnailUrl(preview.windowId)
    }

    onVisibleChanged: {
        if (visible)
            WindowService.requestThumbnail(windowId)
    }

    LiquidGlassSurface {
        id: background
        anchors.fill: parent
        radius: 14
        baseColor: ThemeService.backgroundColor
        surfaceOpacity: 0.88
        materialDepth: 2

        Rectangle {
            id: thumbnailFrame
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 8
            height: 184
            // A deliberately visible image radius. Keep this item transparent
            // so the masked corners reveal the glass card beneath instead of
            // an indistinguishable dark backing rectangle.
            radius: 5
            color: "transparent"
            clip: false

            // This invisible image owns the exact PreserveAspectFit geometry.
            // `paintedWidth` and `paintedHeight` exclude any letterbox space.
            Image {
                id: thumbnailMetrics
                anchors.fill: parent
                source: preview.thumbnailSource
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                opacity: 0
            }

            Rectangle {
                id: thumbnailCrop
                width: Math.round(thumbnailMetrics.paintedWidth)
                height: Math.round(thumbnailMetrics.paintedHeight)
                anchors.centerIn: parent
                radius: thumbnailFrame.radius
                color: "transparent"
                // `clip` only clips to a rectangular item bound; it does not
                // respect Rectangle.radius. Mask this exact painted-image
                // container instead, so the 5px curve is real.
                clip: false
                visible: thumbnailMetrics.status === Image.Ready
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: thumbnailCrop.width
                        height: thumbnailCrop.height
                        radius: thumbnailCrop.radius
                        color: "black"
                        visible: false
                    }
                }

                Image {
                    id: thumbnail
                    anchors.fill: parent
                    source: preview.thumbnailSource
                    // The crop container is already the exact painted size,
                    // so Stretch preserves the source aspect ratio here.
                    fillMode: Image.Stretch
                    asynchronous: true
                    cache: false
                }
            }

            Text {
                anchors.centerIn: parent
                text: preview.thumbnailSource ? "正在更新预览…" : "正在获取预览…"
                color: ThemeService.foregroundColor
                // Match notification/app-launcher legibility on translucent
                // glass without adding a separate label background.
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.38)
                opacity: 0.72
                font {
                    pixelSize: 12
                    weight: Font.DemiBold
                }
                visible: !thumbnailCrop.visible
            }
        }

        Text {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 11
            text: preview.title
            color: ThemeService.foregroundColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.38)
            font {
                pixelSize: 12
                weight: Font.Bold
            }
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
        }

        // A PopupWindow has its own input surface. This explicit hover/click
        // region keeps the preview reachable after leaving the Dock icon and
        // lets a click activate the represented window.
        MouseArea {
            id: previewMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor
            onClicked: preview.activateRequested()
        }
    }

    BackgroundEffect.blurRegion: RoundedBlurRegion {
        item: background
        radius: background.radius
    }
}
