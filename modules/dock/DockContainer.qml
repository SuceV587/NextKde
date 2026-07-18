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
    // Long press enters the persistent iPadOS-like edit state. A real drag
    // also enables it transiently, so direct drag remains available.
    property bool editMode: false
    // The active top-level app drag is shared with folder delegates so they
    // can advertise a valid drop target before release.
    property var draggedPinnedLoader: null
    readonly property bool isEditing: editMode || draggedPinnedLoader !== null
    readonly property real draggedPointerX: draggedPinnedLoader
        ? draggedPinnedLoader.dragPointerX : -1
    readonly property string dropFolderId: {
        if (!draggedPinnedLoader || draggedPinnedLoader.itemData.type !== "app")
            return ""
        for (let i = 0; i < pinnedRepeater.count; i++) {
            const candidate = pinnedRepeater.itemAt(i)
            if (candidate && candidate.itemData.type === "folder"
                    && draggedPointerX >= candidate.x
                    && draggedPointerX <= candidate.x + candidate.width)
                return candidate.itemData.folderId
        }
        return ""
    }
    // Nearest top-level slot for the in-progress reorder preview. Folder
    // targets take priority, so no icons are pushed aside while dropping.
    readonly property int dragInsertIndex: {
        if (!draggedPinnedLoader || dropFolderId)
            return -1
        let nearestIndex = draggedPinnedLoader.pinnedIndex
        let nearestDistance = Number.POSITIVE_INFINITY
        for (let i = 0; i < pinnedRepeater.count; i++) {
            const candidate = pinnedRepeater.itemAt(i)
            if (!candidate)
                continue
            const distance = Math.abs(draggedPointerX
                                      - (candidate.x + candidate.width / 2))
            if (distance < nearestDistance) {
                nearestDistance = distance
                nearestIndex = i
            }
        }
        return nearestIndex
    }

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

    // Quickshell cannot observe clicks delivered to another Wayland surface,
    // but it can observe when the pointer leaves this Dock surface. That is
    // the non-invasive equivalent of tapping away from an iPadOS edit state.
    HoverHandler {
        enabled: container.editMode && !container.draggedPinnedLoader
        onHoveredChanged: {
            if (!hovered)
                container.editMode = false
        }
    }

    // This sits behind the delegates, so it only receives clicks in the Dock
    // gaps. It provides a natural way to leave the persistent edit state.
    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: container.editMode && !container.draggedPinnedLoader
        onClicked: container.editMode = false
    }

    // A Dock panel cannot receive pointer events from the rest of the
    // desktop. WindowService does observe focus changes, which lets an edit
    // session end naturally when the user clicks any other application.
    Connections {
        target: WindowService
        function onActiveWindowIdChanged() {
            if (container.editMode)
                container.editMode = false
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
            delegate: Loader {
                id: pinnedItemLoader
                required property var modelData
                required property int index
                property var itemData: modelData
                property int pinnedIndex: index
                property bool dragged: false
                property real lastDragOffsetX: 0
                readonly property real dragPointerX: reorderDrag.active
                    ? pinnedItemLoader.x + pinnedItemLoader.width / 2
                      + reorderDrag.translation.x : -1
                // Keep the Row in charge of geometry while the visual item
                // follows the pointer above it. This leaves a clear gap at
                // the original position and avoids fighting Row's layout.
                property real dragOffsetX: reorderDrag.active
                    ? reorderDrag.translation.x
                    : 0
                readonly property real reorderOffsetX: {
                    const source = container.draggedPinnedLoader
                    const destination = container.dragInsertIndex
                    if (!source || source === pinnedItemLoader || destination < 0)
                        return 0
                    const slotStep = pinnedItemLoader.width + container.itemSpacing
                    if (destination < source.pinnedIndex
                            && pinnedItemLoader.pinnedIndex >= destination
                            && pinnedItemLoader.pinnedIndex < source.pinnedIndex)
                        return slotStep
                    if (destination > source.pinnedIndex
                            && pinnedItemLoader.pinnedIndex <= destination
                            && pinnedItemLoader.pinnedIndex > source.pinnedIndex)
                        return -slotStep
                    return 0
                }
                property real visualOffsetX: dragOffsetX + reorderOffsetX
                width: container.iconSize + container.activeBackgroundGap * 2
                // Row places delegates at y=0. Give the Loader the complete
                // Dock height so DockIcon/DockFolderIcon can keep anchoring
                // their icon slot to its vertical center, exactly like the
                // pre-folder direct DockIcon delegate did.
                height: container.computedDockHeight
                z: reorderDrag.active ? 10 : 0
                // Once the pointer is over a folder, make the source app
                // visibly contract as if it is being absorbed by the folder.
                scale: reorderDrag.active
                    ? (container.dropFolderId ? 0.68 : 1.10) : 1.0
                opacity: reorderDrag.active ? 0.88 : 1.0
                transformOrigin: Item.Center
                layer.enabled: reorderDrag.active
                transform: Translate { x: pinnedItemLoader.visualOffsetX }
                Behavior on visualOffsetX {
                    // The dragged source follows immediately. Neighbours ease
                    // out of the way as the candidate insertion slot changes.
                    enabled: pinnedItemLoader !== container.draggedPinnedLoader
                    NumberAnimation { duration: 240; easing.type: Easing.Linear }
                }
                Behavior on scale {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                }
                sourceComponent: itemData.type === "folder"
                    ? folderDelegate : appDelegate

                // A release over a folder moves a top-level app into that
                // folder. Any other release commits the existing reorder.
                // The Row continues to own layout, which keeps adaptive width
                // calculation and all existing icon interactions intact.
                DragHandler {
                    id: reorderDrag
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onActiveChanged: {
                        if (active) {
                            pinnedItemLoader.dragged = true
                            pinnedItemLoader.lastDragOffsetX = 0
                            container.draggedPinnedLoader = pinnedItemLoader
                            return
                        }
                        if (!pinnedItemLoader.dragged)
                            return

                        // `translation` is measured from this Loader's start
                        // position, so it gives the actual visual centre in
                        // contentRow coordinates without centroid-space
                        // ambiguity.
                        const center = pinnedItemLoader.x
                                + pinnedItemLoader.width / 2
                                + pinnedItemLoader.lastDragOffsetX
                        let destinationFolderId = ""
                        let nearestIndex = pinnedItemLoader.pinnedIndex
                        let nearestDistance = Number.POSITIVE_INFINITY
                        for (let i = 0; i < pinnedRepeater.count; i++) {
                            const candidate = pinnedRepeater.itemAt(i)
                            if (!candidate)
                                continue
                            if (pinnedItemLoader.itemData.type === "app"
                                    && candidate.itemData.type === "folder"
                                    && center >= candidate.x
                                    && center <= candidate.x + candidate.width) {
                                destinationFolderId = candidate.itemData.folderId
                                break
                            }
                            const candidateCenter = candidate.x + candidate.width / 2
                            const distance = Math.abs(center - candidateCenter)
                            if (distance < nearestDistance) {
                                nearestDistance = distance
                                nearestIndex = i
                            }
                        }
                        if (destinationFolderId) {
                            DockModelService.moveAppToFolder(
                                        destinationFolderId,
                                        pinnedItemLoader.itemData.appId)
                        } else {
                            DockModelService.movePinnedItem(
                                        pinnedItemLoader.itemData.type,
                                        pinnedItemLoader.itemData.type === "folder"
                                            ? pinnedItemLoader.itemData.folderId
                                            : pinnedItemLoader.itemData.appId,
                                        nearestIndex)
                        }
                        pinnedItemLoader.dragged = false
                        container.draggedPinnedLoader = null
                    }
                    // DragHandler clears translation during deactivation,
                    // before onActiveChanged(false) runs. Keep the final
                    // non-zero value for the release transaction above.
                    onTranslationChanged: {
                        if (active)
                            pinnedItemLoader.lastDragOffsetX = translation.x
                    }
                }

                Component {
                    id: appDelegate
                    // Loader resizes its root item to the full Dock height.
                    // Keep the actual square icon in a nested child so its
                    // backgrounds are never stretched by that layout wrapper.
                    Item {
                        DockIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            iconSize: container.iconSize
                            activeBackgroundGap: container.activeBackgroundGap
                            iconSource: pinnedItemLoader.itemData.icon ?? ""
                            displayName: pinnedItemLoader.itemData.name ?? ""
                            isRunning: pinnedItemLoader.itemData.isRunning ?? false
                            isActivated: pinnedItemLoader.itemData.isActivated ?? false
                            appId: pinnedItemLoader.itemData.appId ?? ""
                            isWindowItem: false
                            bounceKey: ""   // pinned never bounce
                            editMode: container.isEditing
                            isDragging: reorderDrag.active
                            onRequestEdit: container.editMode = true
                            onActivate: DockModelService.activateApp(appId)
                        }
                    }
                }

                Component {
                    id: folderDelegate
                    Item {
                        DockFolderIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            iconSize: container.iconSize
                            activeBackgroundGap: container.activeBackgroundGap
                            folderId: pinnedItemLoader.itemData.folderId ?? ""
                            folderName: pinnedItemLoader.itemData.name ?? "新文件夹"
                            apps: pinnedItemLoader.itemData.apps ?? []
                            dropTarget: container.dropFolderId === folderId
                            editMode: container.isEditing
                            isDragging: reorderDrag.active
                            onRequestEdit: container.editMode = true
                        }
                    }
                }
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
                isWindowItem: true
                bounceKey: model.windowId ?? ""
                onActivate: {
                    container.editMode = false
                    DockModelService.activateWindow(model.windowId ?? "")
                }
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
