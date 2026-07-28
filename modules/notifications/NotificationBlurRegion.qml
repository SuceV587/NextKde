import Quickshell
import QtQuick

// Rounded blur mask for an individual card inside the vertically mirrored
// notification stack. Region geometry does not inherit QML transforms, so we
// map the card back into its visible (newest-first) y coordinate explicitly.
Region {
    id: root

    property Item item: null
    required property Item stack
    property real radius: item ? Math.min(item.width, item.height) / 2 : 0

    readonly property bool valid: !!item && !!stack
    readonly property int roundedRadius: valid ? Math.max(
        0,
        Math.min(Math.round(radius), Math.floor(Math.min(item.width, item.height) / 2))
    ) : 0
    readonly property int visualY: valid
        ? Math.round(stack.y + stack.height - item.y - item.height) : 0

    x: valid ? Math.round(item.x + roundedRadius) : 0
    y: visualY
    width: valid ? Math.max(0, Math.round(item.width - roundedRadius * 2)) : 0
    height: valid ? Math.round(item.height) : 0

    Region {
        x: root.valid ? Math.round(root.item.x) : 0
        y: root.visualY + root.roundedRadius
        width: root.valid ? Math.round(root.item.width) : 0
        height: root.valid ? Math.max(0, Math.round(root.item.height - root.roundedRadius * 2)) : 0
    }
    Region {
        x: root.valid ? Math.round(root.item.x) : 0
        y: root.visualY
        width: root.roundedRadius * 2
        height: root.roundedRadius * 2
        shape: RegionShape.Ellipse
    }
    Region {
        x: root.valid ? Math.round(root.item.x + root.item.width - root.roundedRadius * 2) : 0
        y: root.visualY
        width: root.roundedRadius * 2
        height: root.roundedRadius * 2
        shape: RegionShape.Ellipse
    }
    Region {
        x: root.valid ? Math.round(root.item.x) : 0
        y: root.visualY + (root.valid ? root.item.height - root.roundedRadius * 2 : 0)
        width: root.roundedRadius * 2
        height: root.roundedRadius * 2
        shape: RegionShape.Ellipse
    }
    Region {
        x: root.valid ? Math.round(root.item.x + root.item.width - root.roundedRadius * 2) : 0
        y: root.visualY + (root.valid ? root.item.height - root.roundedRadius * 2 : 0)
        width: root.roundedRadius * 2
        height: root.roundedRadius * 2
        shape: RegionShape.Ellipse
    }
}
