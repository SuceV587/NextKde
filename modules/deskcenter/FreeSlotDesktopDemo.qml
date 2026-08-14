import QtQuick

// Isolated free-slot desktop test. It deliberately has no file model,
// persistence, menu, selection, or per-motion sorting work.
Item {
    id: root

    property real validX: 0
    property real validY: 0
    property real validWidth: width
    property real validHeight: height
    property int cellWidth: 112
    property int cellHeight: 114
    readonly property int columnCount: Math.max(1, Math.floor(validWidth / cellWidth))
    readonly property int rowCount: Math.max(1, Math.floor(validHeight / cellHeight))
    readonly property int capacity: columnCount * rowCount
    // `slots` is the durable layout. `previewSlots` is a private drag-time
    // layout: delegates animate it immediately, but it becomes durable only
    // when a valid drop is committed.
    property var slots: ({})
    property var previewSlots: ({})
    property bool dragActive: false
    property bool initialized: false
    property int lastDropId: -1
    property point dragCenter: Qt.point(0, 0)
    // Folders are ordinary grid occupants. Their type only adds the ability
    // to accept a file when the drag visual enters this hit radius.
    property var folderIds: [100, 101]
    property int targetFolder: -1
    property string dragMode: "none" // none, addToFolder, reorderActive
    // iOS-style policy: merging has priority throughout the target grid's
    // visual region; outside the circle, the target remains reorderable.
    readonly property real folderMergeRadius: Math.min(cellWidth, cellHeight)
    property var mergedFiles: ({})
    property var folderCounts: ({})
    // Delegates render the preview during a drag, otherwise the committed map.
    readonly property var visibleSlots: dragActive ? previewSlots : slots

    function isFolderId(id) {
        return folderIds.indexOf(id) >= 0
    }

    function folderAtSlot(slot) {
        const owner = ownersFor(visibleSlots)[slot]
        return owner !== undefined && isFolderId(owner) ? owner : -1
    }

    function folderAtPoint(pointX, pointY, sourceId) {
        const slot = slotAt(pointX, pointY)
        const folderId = folderAtSlot(slot)
        if (folderId < 0 || folderId === sourceId)
            return -1

        const cellPoint = pointForSlot(slot)
        const centerX = cellPoint.x + cellWidth / 2
        const centerY = cellPoint.y + cellHeight / 2
        const dx = pointX - centerX
        const dy = pointY - centerY
        return dx * dx + dy * dy <= folderMergeRadius * folderMergeRadius ? folderId : -1
    }

    function isMergeTargetValid(fileId, folderId) {
        return folderId >= 0
            && !isMerged(fileId)
            && folderAtPoint(dragCenter.x, dragCenter.y, fileId) === folderId
    }

    function isMerged(index) {
        return mergedFiles[index] === true
    }

    function mergeIntoFolder(fileIndex, folderId) {
        const nextMerged = ({})
        const mergedKeys = Object.keys(mergedFiles)
        for (let i = 0; i < mergedKeys.length; ++i)
            nextMerged[mergedKeys[i]] = mergedFiles[mergedKeys[i]]
        nextMerged[fileIndex] = true
        mergedFiles = nextMerged

        const nextCounts = ({})
        const countKeys = Object.keys(folderCounts)
        for (let i = 0; i < countKeys.length; ++i)
            nextCounts[countKeys[i]] = folderCounts[countKeys[i]]
        nextCounts[folderId] = (nextCounts[folderId] || 0) + 1
        folderCounts = nextCounts

        const nextSlots = copySlots(previewSlots)
        delete nextSlots[fileIndex]
        slots = nextSlots
        previewSlots = nextSlots
    }

    function copySlots(source) {
        const next = ({})
        const keys = Object.keys(source)
        for (let i = 0; i < keys.length; ++i)
            next[keys[i]] = source[keys[i]]
        return next
    }

    function pointForSlot(slot) {
        const column = columnCount - 1 - Math.floor(slot / rowCount)
        const row = slot % rowCount
        return Qt.point(validX + column * cellWidth, validY + row * cellHeight)
    }

    function slotAt(pointX, pointY) {
        if (pointX < validX || pointY < validY
                || pointX >= validX + validWidth || pointY >= validY + validHeight)
            return -1
        const column = Math.floor((pointX - validX) / cellWidth)
        const row = Math.floor((pointY - validY) / cellHeight)
        return (columnCount - 1 - column) * rowCount + row
    }

    function ownersFor(map) {
        const owners = ({})
        const keys = Object.keys(map)
        for (let i = 0; i < keys.length; ++i)
            owners[map[keys[i]]] = Number(keys[i])
        return owners
    }

    // Empty slots update one entry. For an occupied target, shift the
    // collision chain toward the source slot: this is insertion, not a
    // fixed "push forward", so it never leaves a hole on the wrong side.
    function layoutAfterDrop(sourceSlots, id, pointX, pointY, occupiedOnly) {
        const target = slotAt(pointX, pointY)
        if (target < 0 || target >= capacity)
            return sourceSlots
        const next = copySlots(sourceSlots)
        const owners = ownersFor(next)
        const source = next[id]
        const occupant = owners[target]
        if (occupant === undefined || occupant === id) {
            if (occupiedOnly)
                return sourceSlots
            next[id] = target
            return next
        }

        delete next[id]
        delete owners[source]
        const direction = source > target ? 1 : -1
        let freeSlot = -1
        for (let slot = target + direction;
                slot >= 0 && slot < capacity;
                slot += direction) {
            if (owners[slot] === undefined) {
                freeSlot = slot
                break
            }
        }
        // No free slot in the insertion direction: preserve the layout.
        if (freeSlot < 0) {
            return sourceSlots
        }
        if (direction > 0) {
            for (let slot = freeSlot; slot > target; --slot) {
                const previous = owners[slot - 1]
                if (previous !== undefined) {
                    next[previous] = slot
                    owners[slot] = previous
                    delete owners[slot - 1]
                }
            }
        } else {
            for (let slot = freeSlot; slot < target; ++slot) {
                const nextOwner = owners[slot + 1]
                if (nextOwner !== undefined) {
                    next[nextOwner] = slot
                    owners[slot] = nextOwner
                    delete owners[slot + 1]
                }
            }
        }
        next[id] = target
        return next
    }

    function applyPreview(id, pointX, pointY) {
        // Real-time reorder: only the transient layout changes here.
        const next = layoutAfterDrop(previewSlots, id, pointX, pointY, true)
        if (next !== previewSlots) {
            lastDropId = id
            previewSlots = next
        }
    }

    function commitDrop(id, pointX, pointY) {
        // The sole ordinary-drop commit point. Invalid desktop coordinates
        // intentionally keep `slots` unchanged.
        if (slotAt(pointX, pointY) < 0)
            return
        const next = layoutAfterDrop(previewSlots, id, pointX, pointY, false)
        lastDropId = id
        slots = next
        previewSlots = next
    }

    Component.onCompleted: {
        const initial = ({})
        const usedSlots = ({})
        for (let index = 0; index < folderIds.length; ++index) {
            const folderSlot = 4 + index * 7
            initial[folderIds[index]] = folderSlot
            usedSlots[folderSlot] = true
        }

        let slot = 0
        for (let index = 0; index < 18 && slot < capacity; ++index) {
            while (slot < capacity && usedSlots[slot] === true)
                ++slot
            if (slot < capacity)
                initial[index] = slot++
        }
        slots = initial
        previewSlots = initial
        initialized = true
    }

    function clearFolderTarget() {
        targetFolder = -1
        if (dragMode === "addToFolder")
            dragMode = "none"
    }

    function beginDrag() {
        // A new drag always starts from the committed snapshot, never from a
        // preview that a prior drag abandoned.
        dragActive = true
        previewSlots = copySlots(slots)
        lastDropId = -1
        dragMode = "none"
        clearFolderTarget()
    }

    function finishDrag() {
        // Discard any uncommitted preview after a drop or cancellation.
        clearFolderTarget()
        dragActive = false
        previewSlots = slots
        dragMode = "none"
    }

    function canReorder(id, slot) {
        if (slot < 0 || slot >= capacity)
            return false
        const owner = ownersFor(previewSlots)[slot]
        return owner !== undefined && owner !== id
    }

    function updateDrag(id, isFolder, point, enteredSlot) {
        const slot = slotAt(point.x, point.y)
        const folderId = isFolder ? -1 : folderAtPoint(point.x, point.y, id)
        if (folderId >= 0) {
            // Folder acceptance is exclusive with reordering for this frame.
            targetFolder = folderId
            dragMode = "addToFolder"
            return enteredSlot
        }

        clearFolderTarget()
        if (slot !== enteredSlot && canReorder(id, slot)) {
            // All regular occupants, including folders, use this same
            // insertion preview path.
            applyPreview(id, point.x, point.y)
            dragMode = "reorderActive"
        }
        return slot
    }

    Repeater {
        model: root.folderIds
        delegate: Item {
            id: folderDelegate
            required property int modelData
            readonly property int folderId: modelData
            readonly property int slot: root.visibleSlots[folderId] ?? -1
            readonly property point folderPoint: root.pointForSlot(slot)
            x: folderPoint.x
            y: folderPoint.y
            width: root.cellWidth
            height: root.cellHeight
            z: folderDrag.active ? 100 : 1

            Behavior on x {
                enabled: root.initialized && root.lastDropId !== folderDelegate.folderId
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: root.initialized && root.lastDropId !== folderDelegate.folderId
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }

            Item {
                id: folderVisual
                width: root.cellWidth
                height: root.cellHeight
                anchors.centerIn: parent
                states: State {
                    when: folderDrag.active
                    ParentChange { target: folderVisual; parent: root }
                    AnchorChanges {
                        target: folderVisual
                        anchors {
                            horizontalCenter: undefined
                            verticalCenter: undefined
                        }
                    }
                }

                Rectangle {
                    x: 16
                    y: 24
                    width: 80
                    height: 68
                    radius: 10
                    color: root.targetFolder === folderDelegate.folderId ? "#ffd86b" : "#e9b949"
                    border.width: root.targetFolder === folderDelegate.folderId ? 3 : 1
                    border.color: "white"
                    Behavior on color { ColorAnimation { duration: 90 } }
                    Text {
                        anchors.centerIn: parent
                        text: "文件夹 " + (folderDelegate.index + 1)
                            + "\n已收纳 " + (root.folderCounts[folderDelegate.folderId] || 0)
                        horizontalAlignment: Text.AlignHCenter
                        color: "white"
                        font.bold: true
                    }
                }
                Rectangle {
                    x: 22
                    y: 14
                    width: 38
                    height: 22
                    radius: 6
                    color: root.targetFolder === folderDelegate.folderId ? "#ffd86b" : "#e9b949"
                    border.width: 1
                    border.color: "white"
                }
                DragHandler {
                    id: folderDrag
                    property int enteredSlot: -1
                    onActiveChanged: {
                        if (active) {
                            enteredSlot = -1
                            root.beginDrag()
                            root.dragCenter = root.mapFromItem(folderVisual,
                                folderVisual.width / 2, folderVisual.height / 2)
                        } else {
                            root.commitDrop(folderDelegate.folderId,
                                root.dragCenter.x, root.dragCenter.y)
                            root.finishDrag()
                        }
                    }
                    onActiveTranslationChanged: if (active) {
                        root.dragCenter = root.mapFromItem(folderVisual,
                            folderVisual.width / 2, folderVisual.height / 2)
                        enteredSlot = root.updateDrag(folderDelegate.folderId, true,
                            root.dragCenter, enteredSlot)
                    }
                }
            }
        }
    }

    Repeater {
        model: 18
        delegate: Item {
            id: delegateRoot
            required property int index
            readonly property int slot: root.visibleSlots[index] ?? index
            readonly property point slotPoint: root.pointForSlot(slot)
            x: slotPoint.x
            y: slotPoint.y
            width: root.cellWidth
            height: root.cellHeight
            visible: !root.isMerged(index)
            Behavior on x {
                enabled: root.initialized && root.lastDropId !== delegateRoot.index
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: root.initialized && root.lastDropId !== delegateRoot.index
                NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
            }
            Item {
                id: dragVisual
                width: root.cellWidth
                height: root.cellHeight
                z: dragHandler.active ? 100 : 0
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }
                states: State {
                    when: dragHandler.active
                    ParentChange { target: dragVisual; parent: root }
                    AnchorChanges {
                        target: dragVisual
                        anchors {
                            horizontalCenter: undefined
                            verticalCenter: undefined
                        }
                    }
                }

                Rectangle {
                    anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                    width: 68
                    height: 68
                    radius: 8
                    color: Qt.hsla((delegateRoot.index * 0.07) % 1, 0.58, 0.56, 1)
                    Text { anchors.centerIn: parent; text: delegateRoot.index + 1; color: "white"; font.bold: true }
                }
                Text {
                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 82 }
                    text: "Item " + (delegateRoot.index + 1)
                    horizontalAlignment: Text.AlignHCenter
                    color: "white"
                }
                DragHandler {
                    id: dragHandler
                    property int enteredSlot: -1
                    onActiveChanged: {
                        if (active) {
                            enteredSlot = -1
                            root.beginDrag()
                            root.dragCenter = root.mapFromItem(dragVisual,
                                dragVisual.width / 2, dragVisual.height / 2)
                        } else {
                            const mergeFolder = root.targetFolder
                            const shouldMerge = root.dragMode === "addToFolder"
                                && root.isMergeTargetValid(delegateRoot.index, mergeFolder)
                            if (shouldMerge)
                                root.mergeIntoFolder(delegateRoot.index, mergeFolder)
                            else
                                root.commitDrop(delegateRoot.index,
                                    root.dragCenter.x, root.dragCenter.y)
                            root.finishDrag()
                        }
                    }
                    onActiveTranslationChanged: {
                        if (active) {
                            root.dragCenter = root.mapFromItem(dragVisual,
                                dragVisual.width / 2, dragVisual.height / 2)
                            enteredSlot = root.updateDrag(delegateRoot.index, false,
                                root.dragCenter, enteredSlot)
                        }
                    }
                }
            }
        }
    }
}
