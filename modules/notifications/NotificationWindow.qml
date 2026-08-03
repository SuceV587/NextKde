import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.dock

// A compact, non-exclusive surface in the top-right corner of one output.
PanelWindow {
    id: root

    required property var notifications
    property int blurRevision: 0

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        right: true
    }
    margins {
        top: 48
        right: 18
    }

    implicitWidth: 350
    implicitHeight: notificationStack.height

    // Each card owns a rounded region. Unlike a single stack-sized region,
    // this leaves the gaps transparent and gives every card a Dock-like edge.
    BackgroundEffect.blurRegion: Region {
        // Region accepts concrete Region children, not a Repeater. Eight
        // independent slots comfortably cover the visible notification stack;
        // empty slots have a zero-sized region.
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(0) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(1) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(2) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(3) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(4) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(5) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(6) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
        NotificationBlurRegion {
            item: { root.blurRevision; return notificationRepeater.itemAt(7) }
            stack: notificationStack
            radius: item ? item.radius : 24
        }
    }

    Column {
        id: notificationStack
        width: parent.width
        spacing: 10
        // NotificationServer appends arrivals. Mirror the stack vertically so
        // that the latest item occupies the top slot without copying or
        // reordering the server-owned notification model.
        transform: Scale {
            origin.x: notificationStack.width / 2
            origin.y: notificationStack.height / 2
            yScale: -1
        }

        Repeater {
            id: notificationRepeater
            model: root.notifications
            onItemAdded: root.blurRevision++
            onItemRemoved: root.blurRevision++

            delegate: Rectangle {
                id: card
                required property var modelData
                readonly property var notification: modelData
                readonly property color foregroundColor: Qt.rgba(1, 1, 1, 0.96)
                readonly property color textOutlineColor: Qt.rgba(0.05, 0.08, 0.12, 0.38)
                readonly property string iconSource: {
                    // A notification is an immutable snapshot. Do not bind
                    // its icon to the global app-identity revision: launcher
                    // config loading or a custom icon save would otherwise
                    // re-resolve every visible card and hitch its animation.
                    return AppIdentityService.iconSourceFor(
                        notification.desktopEntry || notification.appName,
                        notification.image || notification.appIcon
                    )
                }
                property bool closing: false
                property bool closeAsExpired: false

                width: notificationStack.width
                height: content.implicitHeight + 28
                radius: 24
                color: "transparent"
                clip: true
                // Cancel the stack's vertical mirror so card contents remain
                // upright while their ordering is newest-first.
                transform: Scale {
                    origin.x: card.width / 2
                    origin.y: card.height / 2
                    yScale: -1
                }

                // Column updates y whenever another notification appears or
                // leaves. This turns those layout changes into a calm stack
                // rearrangement instead of a jump.
                Behavior on y {
                    NumberAnimation {
                        duration: 320
                        easing.type: Easing.OutCubic
                    }
                }

                function close(expired) {
                    if (closing)
                        return
                    closing = true
                    closeAsExpired = expired
                    exitAnimation.start()
                }

                Component.onCompleted: entranceAnimation.start()

                ParallelAnimation {
                    id: entranceAnimation
                    NumberAnimation {
                        target: card
                        property: "x"
                        from: notificationStack.width + 44
                        to: 0
                        duration: 420
                        easing.type: Easing.OutQuint
                    }
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 240
                        easing.type: Easing.OutCubic
                    }
                }

                ParallelAnimation {
                    id: exitAnimation
                    NumberAnimation {
                        target: card
                        property: "x"
                        to: notificationStack.width + 44
                        duration: 230
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: card
                        property: "opacity"
                        to: 0
                        duration: 180
                        easing.type: Easing.InCubic
                    }
                    onFinished: {
                        if (card.closeAsExpired)
                            card.notification.expire()
                        else
                            card.notification.dismiss()
                    }
                }

                LiquidGlassSurface {
                    anchors.fill: parent
                    radius: parent.radius
                    // A neutral mid-grey glass keeps a balanced appearance
                    // between the previous white and black variants.
                    baseColor: Qt.rgba(0.35, 0.35, 0.35, 0.28)
                    surfaceOpacity: 1.0
                    bottomEdgeVisible: false
                    bottomShadeVisible: false
                    // Match the Dock's living colour response.
                    ambientPrimary: WallpaperPaletteService.primary
                    ambientSecondary: WallpaperPaletteService.secondary
                    ambientStrength: 0.82
                    // The Dock uses the base material depth. Matching it
                    // avoids the heavier, more opaque popup treatment.
                    materialDepth: 0.0
                }

                Timer {
                    // Servers receive -1 for a persistent notification and
                    // 0 when the client leaves timeout selection to us.
                    interval: card.notification.expireTimeout > 0
                        ? Math.max(1000, card.notification.expireTimeout * 1000)
                        : 7000
                    running: true
                    repeat: false
                    onTriggered: card.close(true)
                }

                Item {
                    id: appMark
                    width: 34
                    height: width
                    anchors {
                        left: parent.left
                        leftMargin: 14
                        top: parent.top
                        topMargin: 14
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !iconMask.visible
                        text: card.notification.appName.length > 0
                            ? card.notification.appName.slice(0, 1).toUpperCase()
                            : "•"
                        color: card.foregroundColor
                        style: Text.Outline
                        styleColor: card.textOutlineColor
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Item {
                        id: iconMask
                        anchors.centerIn: parent
                        width: 30
                        height: width
                        visible: card.iconSource.length > 0

                        IconImage {
                            id: appIcon
                            anchors.fill: parent
                            source: card.iconSource
                            asynchronous: true
                            smooth: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: iconMask.width
                                    height: iconMask.height
                                    radius: width * 0.20
                                    color: "black"
                                    visible: false
                                }
                            }
                        }
                    }
                }

                Column {
                    id: content
                    anchors {
                        left: appMark.right
                        leftMargin: 10
                        right: closeButton.left
                        rightMargin: 8
                        top: parent.top
                        topMargin: 14
                        bottom: parent.bottom
                        bottomMargin: 14
                    }
                    spacing: 4

                    Text {
                        width: parent.width
                        text: card.notification.summary.length > 0
                            ? card.notification.summary : card.notification.appName
                        color: card.foregroundColor
                        style: Text.Outline
                        styleColor: card.textOutlineColor
                        font.pixelSize: 14
                        font.bold: true
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }

                    Text {
                        width: parent.width
                        visible: text.length > 0
                        text: card.notification.body
                        color: card.foregroundColor
                        style: Text.Outline
                        styleColor: card.textOutlineColor
                        opacity: 0.78
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        maximumLineCount: 4
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                }

                Text {
                    id: closeButton
                    text: "×"
                    color: card.foregroundColor
                    style: Text.Outline
                    styleColor: card.textOutlineColor
                    opacity: 0.55
                    font.pixelSize: 22
                    anchors {
                        right: parent.right
                        rightMargin: 12
                        top: parent.top
                        topMargin: 9
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.close(false)
                    }
                }
            }
        }
    }
}
