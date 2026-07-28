import QtQuick
import Quickshell
import "./AdaptiveMath.mjs" as AdaptiveMath
import qs.modules.applauncher

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
    // The app launcher is a permanent visual slot before persisted pinned apps.
    // Include it in adaptive width fitting, but never in the model used for
    // drag-reordering or persistence.
    readonly property int pinnedCount: DockModelService.pinnedCount + 1
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
    // A drag temporarily enables the iPadOS-like edit state.
    property var draggedPinnedLoader: null
    readonly property bool isEditing: editMode || draggedPinnedLoader !== null
    readonly property real draggedPointerX: draggedPinnedLoader
        ? draggedPinnedLoader.dragPointerX : -1
    // A presentation-only target for DockActiveIndicator. The delayed clear
    // avoids a transient fade when WindowService reports the old window's
    // deactivation one signal before reporting the next window's activation.
    property Item activeIcon: null

    function publishLauncherGeometry() {
        console.log("[DockContainer] publish launcher "
            + computedDockWidth + "x" + computedDockHeight)
        AppLauncherService.setDockPresentation(
            computedDockWidth,
            computedDockHeight,
            ThemeService.backgroundColor,
            WallpaperPaletteService.primary,
            WallpaperPaletteService.secondary,
            ThemeService.foregroundColor)
    }

    Component.onCompleted: publishLauncherGeometry()
    onComputedDockWidthChanged: publishLauncherGeometry()
    onComputedDockHeightChanged: publishLauncherGeometry()

    Connections {
        target: ThemeService
        function onBackgroundColorChanged() { container.publishLauncherGeometry() }
        function onForegroundColorChanged() { container.publishLauncherGeometry() }
    }
    Connections {
        target: WallpaperPaletteService
        function onPrimaryChanged() { container.publishLauncherGeometry() }
        function onSecondaryChanged() { container.publishLauncherGeometry() }
    }
    // Launcher actions enter Dock through the launcher service contract. This
    // keeps launcher UI independent from Dock's persistence/model internals.
    Connections {
        target: AppLauncherService
        function onPinToDockRequested(appId) {
            DockModelService.pinApp(appId)
        }
    }

    function reportActiveIcon(icon, activated) {
        if (activated) {
            activeIconClear.stop()
            activeIcon = icon
            activeIndicator.requestSync()
        } else if (activeIcon === icon) {
            if (!DockModelService.preserveActiveIndicator)
                activeIconClear.restart()
        }
    }

    function _windowTaskIcon(windowId) {
        for (let i = 0; i < windowsRepeater.count; i++) {
            const candidate = windowsRepeater.itemAt(i)
            if (candidate && candidate.windowId === windowId)
                return candidate
        }
        return null
    }

    function animateRequestedWindow(windowId) {
        const target = _windowTaskIcon(windowId)
        if (!target)
            return
        activeIconClear.stop()
        activeIcon = target
        activeIndicator.requestSync()
    }

    function syncActiveIcon(icon) {
        if (activeIcon === icon)
            activeIndicator.requestSync()
    }

    Timer {
        id: activeIconClear
        // Focus providers can emit deactivation and activation in separate
        // event-loop turns (notably QuickSearch). Keep the old target briefly
        // so the next target still receives a continuous travel animation.
        interval: 180
        repeat: false
        onTriggered: {
            if (container.activeIcon && !container.activeIcon.isActivated)
                container.activeIcon = null
        }
    }
    // Nearest top-level slot for the in-progress reorder preview.
    readonly property int dragInsertIndex: {
        if (!draggedPinnedLoader)
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

    DockActiveIndicator {
        id: activeIndicator
        target: container.activeIcon
        moveDuration: 260
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

    Connections {
        target: DockModelService
        function onRequestedActivationWindowIdChanged() {
            container.animateRequestedWindow(DockModelService.requestedActivationWindowId)
        }
        function onPreserveActiveIndicatorChanged() {
            if (!DockModelService.preserveActiveIndicator
                    && container.activeIcon
                    && !container.activeIcon.isActivated)
                activeIconClear.restart()
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
        onXChanged: activeIndicator.requestSync()
        onYChanged: activeIndicator.requestSync()
        onWidthChanged: activeIndicator.requestSync()
        onHeightChanged: activeIndicator.requestSync()

        // ── Pinned apps ──
        // Fixed launcher slot. This project-owned image avoids icon-theme
        // lookup differences. Interaction is deliberately disabled until the
        // app-launcher surface is implemented. Keeping it outside the Repeater
        // makes it immutable with respect to pinned-app ordering.
        DockIcon {
            iconSize: container.iconSize
            activeBackgroundGap: container.activeBackgroundGap
            iconSource: Qt.resolvedUrl("../../assets/appLancher.svg")
            displayName: "应用程序"
            showContextMenu: false
            allowEdit: false
            isPinnedItem: false
            bounceKey: ""
            onActivate: {
                container.editMode = false
                if (DockModelService.activeDockPopup)
                    DockModelService.activeDockPopup.visible = false
                console.log("[DockContainer] app launcher requested")
                AppLauncherService.toggle()
            }
        }

        Repeater {
            id: pinnedRepeater
            model: DockModelService.pinnedItems
            delegate: Loader {
                id: pinnedItemLoader
                required property var modelData
                required property int index
                property real lastDragX: 0
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
                readonly property real iconSlotWidth: container.iconSize
                    + container.activeBackgroundGap * 2
                readonly property int extraWindowCount: itemData.type === "app"
                    ? (itemData.extraWindows?.length ?? 0) : 0
                width: iconSlotWidth * (1 + extraWindowCount)
                    + container.itemSpacing * extraWindowCount
                // Row places delegates at y=0; keep the Loader dock-height
                // tall so the nested square icon can remain vertically centred.
                height: container.computedDockHeight
                z: reorderDrag.active ? 10 : 0
                scale: reorderDrag.active ? 1.10 : 1.0
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
                sourceComponent: appDelegate

                // Releasing a drag commits the reordered top-level app.
                DragHandler {
                    id: reorderDrag
                    target: null
                    acceptedButtons: Qt.LeftButton
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
                        let nearestIndex = pinnedItemLoader.pinnedIndex
                        let nearestDistance = Number.POSITIVE_INFINITY
                        for (let i = 0; i < pinnedRepeater.count; i++) {
                            const candidate = pinnedRepeater.itemAt(i)
                            if (!candidate)
                                continue
                            const candidateCenter = candidate.x + candidate.width / 2
                            const distance = Math.abs(center - candidateCenter)
                            if (distance < nearestDistance) {
                                nearestDistance = distance
                                nearestIndex = i
                            }
                        }
                        DockModelService.movePinnedItem(
                                    pinnedItemLoader.itemData.type,
                                    pinnedItemLoader.itemData.appId,
                                    nearestIndex)
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
                        Row {
                            anchors.centerIn: parent
                            spacing: container.itemSpacing

                            DockIcon {
                            iconSize: container.iconSize
                            activeBackgroundGap: container.activeBackgroundGap
                            iconSource: pinnedItemLoader.itemData.icon ?? ""
                            displayName: pinnedItemLoader.itemData.name ?? ""
                            isRunning: pinnedItemLoader.itemData.isRunning ?? false
                            isActivated: pinnedItemLoader.itemData.isActivated ?? false
                            activeIndicatorHost: container
                            appId: pinnedItemLoader.itemData.appId ?? ""
                            isWindowItem: false
                            isPinnedItem: true
                            bounceKey: ""   // pinned never bounce
                            editMode: container.isEditing
                            isDragging: reorderDrag.active
                            onRequestEdit: container.editMode = true
                            onActivate: DockModelService.activateApp(appId)
                            }

                            Repeater {
                                model: pinnedItemLoader.itemData.extraWindows ?? []
                                delegate: DockIcon {
                                    required property var modelData
                                    iconSize: container.iconSize
                                    activeBackgroundGap: container.activeBackgroundGap
                                    iconSource: modelData.iconSource
                                        ?? modelData.identity.iconSource ?? ""
                                    displayName: modelData.title ?? ""
                                    isRunning: true
                                    isActivated: modelData.toplevel.activated ?? false
                                    isUrgent: modelData.isUrgent ?? false
                                    activeIndicatorHost: container
                                    appId: modelData.identity.desktopId ?? ""
                                    windowId: modelData.windowId ?? ""
                                    isWindowItem: true
                                    isPinnedItem: false
                                    bounceKey: modelData.windowId ?? ""
                                    onActivate: DockModelService.toggleWindow(windowId)
                                }
                            }
                        }
                    }
                }

            }
        }

        // ── Divider: persistent launchers | temporary windows ──
        DockDivider {
            dockHeight: container.computedDockHeight
            // Make the app/window boundary read as a deliberate section break.
            dividerWidth: 2
            sideMargin: container.dividerMargin
            lineColor: Qt.rgba(1, 1, 1, 1)
            lineOpacity: 0.46
            lineRadius: 999
            visible: pinnedRepeater.count > 0 && windowsRepeater.count > 0
        }

        // ── Unpinned window tasks ──
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
                isUrgent: model.isUrgent ?? false
                activeIndicatorHost: container
                appId: model.appId ?? ""
                windowId: model.windowId ?? ""
                isWindowItem: true
                isPinnedItem: false
                bounceKey: model.windowId ?? ""
                onActivate: {
                    container.editMode = false
                    DockModelService.toggleWindow(windowId)
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
