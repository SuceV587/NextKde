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
    property var slots: ({})
    property bool initialized: false
    property int lastDropId: -1
    property point dragCenter: Qt.point(0, 0)

    function copySlots() {
        const next = ({})
        const keys = Object.keys(slots)
        for (let i = 0; i < keys.length; ++i)
            next[keys[i]] = slots[keys[i]]
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
    function commitDrop(id, pointX, pointY, occupiedOnly) {
        const target = slotAt(pointX, pointY)
        if (target < 0 || target >= capacity)
            return

        const next = copySlots()
        const owners = ownersFor(next)
        const source = next[id]
        const occupant = owners[target]
        if (occupant === undefined || occupant === id) {
            if (occupiedOnly)
                return
            lastDropId = id
            next[id] = target
            slots = next
            return
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
            next[id] = source
            slots = next
            return
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
        lastDropId = id
        next[id] = target
        slots = next
    }

    Component.onCompleted: {
        const initial = ({})
        for (let index = 0; index < 24 && index < capacity; ++index)
            initial[index] = index
        slots = initial
        initialized = true
    }

    Repeater {
        model: 24
        delegate: Item {
            id: delegateRoot
            required property int index
            readonly property int slot: root.slots[index] ?? index
            readonly property point slotPoint: root.pointForSlot(slot)
            x: slotPoint.x
            y: slotPoint.y
            width: root.cellWidth
            height: root.cellHeight
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
                            root.dragCenter = root.mapFromItem(dragVisual,
                                dragVisual.width / 2, dragVisual.height / 2)
                        } else {
                            root.commitDrop(delegateRoot.index,
                                root.dragCenter.x, root.dragCenter.y, false)
                        }
                    }
                    onActiveTranslationChanged: {
                        if (active) {
                            root.dragCenter = root.mapFromItem(dragVisual,
                                dragVisual.width / 2, dragVisual.height / 2)
                            const slot = root.slotAt(root.dragCenter.x, root.dragCenter.y)
                            if (slot !== enteredSlot) {
                                enteredSlot = slot
                                root.commitDrop(delegateRoot.index,
                                    root.dragCenter.x, root.dragCenter.y, true)
                            }
                        }
                    }
                }
            }
        }
    }
}
