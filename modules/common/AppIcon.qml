import QtQuick
import Quickshell.Widgets

// One renderer for application artwork across Dock, QuickSearch and Launcher.
// Layout owns width/height; this component owns source loading consistency.
Item {
    id: root
    property string source: ""

    IconImage {
        anchors.fill: parent
        source: root.source
        smooth: true
        asynchronous: true
    }
}
