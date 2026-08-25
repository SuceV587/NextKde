import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.desktop.modules.dock

// One concrete top Bar surface. Its content is shared with the optional
// unified Dock host; this file owns only layer-shell geometry.
PanelWindow {
    id: root

    property bool barEnabled: true

    WlrLayershell.namespace: "quickshell-bar"
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Top
    implicitHeight: ConfigService.barHeight
    // Hiding content is insufficient: layer-shell's exclusive zone is what
    // makes maximised windows leave a strip at the top. Commit zero while the
    // Bar is hosted by Dock, then unmap the visual surface.
    exclusiveZone: root.barEnabled ? implicitHeight : 0
    visible: root.barEnabled

    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 0
        left: 15
        right: 15
    }

    Loader {
        anchors.fill: parent
        active: root.barEnabled
        sourceComponent: Component {
            Item {
                BarDateStatus {
                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }
                }

                BarStatusArea {
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
