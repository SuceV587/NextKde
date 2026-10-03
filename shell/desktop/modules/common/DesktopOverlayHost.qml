import QtQuick

// An empty composition layer with no pointer handlers or feature state.
Item {
    id: root
    required property var screen

    anchors.fill: parent
    Component.onCompleted: DesktopSurfaceRegistry.registerHost(root)
    Component.onDestruction: DesktopSurfaceRegistry.unregisterHost(root)
}
