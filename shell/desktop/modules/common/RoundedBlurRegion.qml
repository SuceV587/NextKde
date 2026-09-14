import Quickshell
import QtQuick

// A reusable blur-region mask for a rounded rectangle. Wayland regions are
// rectangular primitives, so this combines two rectangles and four ellipses.
// Use it as: BackgroundEffect.blurRegion: RoundedBlurRegion { item: target }
Region {
    id: root

    // Item may be null (e.g. conditionally deactivated regions like Dock reveal handle)
    property Item item: null
    // Most callers use a direct child of their window, but control-center
    // cards can live several Row/Column levels down. Map those cards into the
    // window's coordinate space before publishing the compositor blur region.
    // Leaving this null preserves the original direct-child behavior.
    property Item coordinateSpace: null

    readonly property bool hasValidItem: item !== null && item.width > 0 && item.height > 0
    property real radius: hasValidItem ? Math.min(item.width, item.height) / 2 : 0

    readonly property point itemPosition: (hasValidItem && coordinateSpace)
        ? item.mapToItem(coordinateSpace, 0, 0)
        : (hasValidItem ? Qt.point(item.x, item.y) : Qt.point(0, 0))
    readonly property int roundedRadius: hasValidItem
        ? Math.max(0, Math.min(Math.round(radius), Math.floor(Math.min(item.width, item.height) / 2)))
        : 0

    // Vertical center of the rounded rectangle.
    x: hasValidItem ? Math.round(itemPosition.x + roundedRadius) : 0
    y: hasValidItem ? Math.round(itemPosition.y) : 0
    width: hasValidItem ? Math.max(0, Math.round(item.width - roundedRadius * 2)) : 0
    height: hasValidItem ? Math.round(item.height) : 0

    // Horizontal center.
    Region {
        x: root.hasValidItem ? Math.round(root.itemPosition.x) : 0
        y: root.hasValidItem ? Math.round(root.itemPosition.y + root.roundedRadius) : 0
        width: root.hasValidItem ? Math.round(root.item.width) : 0
        height: root.hasValidItem ? Math.max(0, Math.round(root.item.height - root.roundedRadius * 2)) : 0
    }

    // The corners complete the rounded outline.
    Region {
        x: root.hasValidItem ? Math.round(root.itemPosition.x) : 0
        y: root.hasValidItem ? Math.round(root.itemPosition.y) : 0
        width: root.hasValidItem ? root.roundedRadius * 2 : 0
        height: root.hasValidItem ? root.roundedRadius * 2 : 0
        shape: RegionShape.Ellipse
    }
    Region {
        x: root.hasValidItem ? Math.round(root.itemPosition.x + root.item.width - root.roundedRadius * 2) : 0
        y: root.hasValidItem ? Math.round(root.itemPosition.y) : 0
        width: root.hasValidItem ? root.roundedRadius * 2 : 0
        height: root.hasValidItem ? root.roundedRadius * 2 : 0
        shape: RegionShape.Ellipse
    }
    Region {
        x: root.hasValidItem ? Math.round(root.itemPosition.x) : 0
        y: root.hasValidItem ? Math.round(root.itemPosition.y + root.item.height - root.roundedRadius * 2) : 0
        width: root.hasValidItem ? root.roundedRadius * 2 : 0
        height: root.hasValidItem ? root.roundedRadius * 2 : 0
        shape: RegionShape.Ellipse
    }
    Region {
        x: root.hasValidItem ? Math.round(root.itemPosition.x + root.item.width - root.roundedRadius * 2) : 0
        y: root.hasValidItem ? Math.round(root.itemPosition.y + root.item.height - root.roundedRadius * 2) : 0
        width: root.hasValidItem ? root.roundedRadius * 2 : 0
        height: root.hasValidItem ? root.roundedRadius * 2 : 0
        shape: RegionShape.Ellipse
    }
}
