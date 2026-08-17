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
        // AppIcon is used by the launcher grid as well as persistent Dock
        // items. IconImage already decodes to `actualSize`; disabling the
        // global pixmap cache prevents one launcher visit from retaining every
        // application icon after its on-demand window is destroyed.
        backer.cache: false
    }
}
