import QtQuick
import Quickshell
import "./AdaptiveMath.mjs" as AdaptiveMath

// ────────────────────────────────────────────────────────────────
// DockContainer — Adaptive layout engine.
//
// Calls AdaptiveMath.computeLayout(...) reactively whenever
// model counts or screen dimensions change.  Derives iconSize,
// dockHeight, dockWidth, and all spacing values.  Hosts the
// horizontal Row of three sections: pinned | windows | music.
//
// Animation Behaviors on computed dimensions ensure smooth
// transitions when the dock resizes.
// ────────────────────────────────────────────────────────────────

Item {
    id: container

    // ═══════════════════════════════════════════════════════════
    // Inputs (from services / parent)
    // ═══════════════════════════════════════════════════════════
    readonly property int pinnedCount: DockModelService.pinnedCount
    readonly property int windowCount: DockModelService.windowCount
    readonly property bool hasPlayer: DockMprisService.hasPlayer
    readonly property int screenWidth: Quickshell.screens[0]?.width ?? 1920
    readonly property real baseHeight: ConfigService.baseHeight
    readonly property real maxWidthRatio: ConfigService.maxWidthRatio
    readonly property var proportions: ConfigService.proportions

    // ═══════════════════════════════════════════════════════════
    // Computed layout (re-evaluates on any input change)
    // ═══════════════════════════════════════════════════════════
    // All adaptive inputs are passed into one pure calculation. New content
    // must affect the calculation through counts/units instead of changing
    // height or spacing locally, otherwise width fitting can be bypassed.
    readonly property var _layout: AdaptiveMath.computeLayout(
        baseHeight, pinnedCount, windowCount, hasPlayer, screenWidth,
        maxWidthRatio, proportions
    )

    readonly property int computedDockHeight: _layout.dockHeight
    readonly property int iconSize: _layout.iconSize
    readonly property int computedDockWidth: _layout.dockWidth
    readonly property int itemSpacing: _layout.itemSpacing
    readonly property int hPadding: _layout.hPadding
    readonly property int vPadding: _layout.vPadding
    readonly property int dividerMargin: _layout.dividerMargin
    readonly property int pillRadius: _layout.pillRadius
    // DockIcon reserves this invisible outer slot even when inactive. This
    // keeps the Row width stable while the active background appears/disappears.
    readonly property real activeBackgroundGap: _layout.activeBackgroundGap
    readonly property int iconUnits: _layout.iconUnits
    readonly property int musicUnits: _layout.musicUnits

    // ── Debug: periodic state dump ──
    property Timer _dbg: Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: console.log("[DockContainer] pinned=" + container.pinnedCount + " windows=" + container.windowCount + " music=" + container.hasPlayer + " screenW=" + container.screenWidth + " baseH=" + container.baseHeight + " → H=" + container.computedDockHeight + " icon=" + container.iconSize + " W=" + container.computedDockWidth)
    }

    // ═══════════════════════════════════════════════════════════
    // Size
    // ═══════════════════════════════════════════════════════════
    implicitWidth: computedDockWidth
    implicitHeight: computedDockHeight
    width: implicitWidth
    height: implicitHeight

    // ── Smooth resize transitions ──
    Behavior on width {
        NumberAnimation {
            duration: DockAnimation.dockResizeDuration
            easing.type: DockAnimation.dockResizeEasing
        }
    }
    Behavior on height {
        NumberAnimation {
            duration: DockAnimation.dockResizeDuration
            easing.type: DockAnimation.dockResizeEasing
        }
    }

    // ═══════════════════════════════════════════════════════════
    // Content row
    // ═══════════════════════════════════════════════════════════

    opacity: iconUnits > 0 ? 1.0 : 0.0
    Behavior on opacity {
        NumberAnimation {
            duration: DockAnimation.dockFadeDuration
            easing.type: DockAnimation.dockFadeEasing
        }
    }

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: container.itemSpacing
        leftPadding: container.hPadding
        rightPadding: container.hPadding
        height: container.computedDockHeight

        // ── Pinned apps ──
        Repeater {
            id: pinnedRepeater
            model: DockModelService.pinnedItems
            delegate: DockIcon {
                iconSize: container.iconSize
                activeBackgroundGap: container.activeBackgroundGap
                iconSource: modelData.icon ?? ""
                displayName: modelData.name ?? ""
                isRunning: modelData.isRunning ?? false
                isActivated: modelData.isActivated ?? false
                appId: modelData.appId ?? ""
                bounceKey: ""   // pinned never bounce
                // Use the delegate's stable appId property instead of reading
                // modelData again inside the signal handler. This keeps the
                // click target correct when pinnedItems is rebuilt.
                onActivate: DockModelService.activateApp(appId)
            }
        }

        // ── Divider 1: pinned | windows ──
        DockDivider {
            dockHeight: container.computedDockHeight
            dividerWidth: 1
            sideMargin: container.dividerMargin
            visible: pinnedRepeater.count > 0 && windowsRepeater.count > 0
        }

        // ── Open windows ──
        Repeater {
            id: windowsRepeater
            model: DockModelService.windowModel
            delegate: DockIcon {
                iconSize: container.iconSize
                activeBackgroundGap: container.activeBackgroundGap
                iconSource: model.icon ?? ""
                displayName: model.title ?? ""
                isRunning: true
                isActivated: model.isActivated ?? false
                appId: model.appId ?? ""
                windowId: model.windowId ?? ""
                bounceKey: model.windowId ?? ""
                onActivate: DockModelService.activateWindow(model.windowId ?? "")
            }
        }

        // ── Divider 2: windows | music (conditional) ──
        DockDivider {
            dockHeight: container.computedDockHeight
            dividerWidth: 2
            sideMargin: container.dividerMargin
            visible: container.hasPlayer
        }

        // ── Music player (conditional) ──
        DockMusicPlayer {
            iconSize: container.iconSize
            dockHeight: container.computedDockHeight
            widthUnits: container.musicUnits
            visible: container.hasPlayer
        }
    }
}
