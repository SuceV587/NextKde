import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.dock

// iPadOS-inspired top status bar for one concrete output.
PanelWindow {
    id: root

    // Distinguish this surface from other quickshell panels so the glass
    // plugin can give it its own highlight direction.
    WlrLayershell.namespace: "quickshell-bar"

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    // Keep persistent chrome on the normal layer-shell Top layer.
    WlrLayershell.layer: WlrLayer.Top
    implicitHeight: 35
    exclusiveZone: implicitHeight

    // The control center is nine independent blurred PanelWindows. Keeping
    // them mapped while closed costs far more memory than the top bar itself.
    // Load the complete card tree only while it is in use, then release it
    // shortly after close so the compositor can process the hidden state.
    property bool controlCenterLoaded: false
    readonly property var controlCenter: controlCenterLoader.item
    readonly property bool controlCenterOpen: controlCenter?.isOpen ?? false

    function toggleControlCenter(anchorItem) {
        controlCenterUnloadTimer.stop()
        if (controlCenterOpen) {
            closeControlCenter()
            return
        }
        controlCenterLoaded = true
        // Loader creation is synchronous today, but deferring lets all nine
        // cards register with their coordinator before openAll cascades them.
        Qt.callLater(function() {
            if (controlCenterLoaded && controlCenter
                    && !controlCenter.isOpen)
                controlCenter.toggle(anchorItem)
        })
    }

    function closeControlCenter() {
        if (controlCenter)
            controlCenter.close()
        if (controlCenterLoaded)
            controlCenterUnloadTimer.restart()
    }

    Timer {
        id: controlCenterUnloadTimer
        interval: 180
        repeat: false
        onTriggered: {
            if (!root.controlCenterOpen)
                root.controlCenterLoaded = false
        }
    }

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

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Row {
        id: dateStatus
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }
        spacing: 7

        Text {
            id: timeText
            text: Qt.formatDateTime(clock.date, "h:mm")
            color: ThemeService.foregroundColor
            // Match launcher app labels: the thin dark outline preserves
            // white-text contrast when this transparent bar sits on a bright
            // or detailed wallpaper, without adding a visible text plate.
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.38)
            font {
                family: "SF Pro Display"
                pixelSize: 14
                weight: Font.Bold
            }
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: dateText
            text: Qt.formatDateTime(clock.date, "M月d日 dddd")
            color: ThemeService.foregroundColor
            style: Text.Outline
            styleColor: Qt.rgba(0, 0, 0, 0.38)
            font {
                family: "Noto Sans CJK SC"
                pixelSize: 14
                weight: Font.Bold
            }
            anchors.baseline: timeText.baseline
        }
    }

    Row {
        id: statusArea
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        spacing: 10

        // Row lays out children from its top edge. Give the 20px thermal
        // indicator the same 24px slot as SysTray and quick controls, then
        // center it so its icon and two-line label share their visual axis.
        Item {
            width: cpuTemperature.implicitWidth
            height: 24
            CpuTemperature {
                id: cpuTemperature
                anchors.centerIn: parent
            }
        }
        // Keep NetworkTraffic.qml available for the control centre, but hide
        // its Bar glyph and up/down text until the status area needs it again.
        // NetworkTraffic {
        //     onPanelToggleRequested: networkPanel.toggle(networkStatus)
        // }
        Item {
            width: systemTray.implicitWidth
            height: 24
            // SysTray is 20px high. Centre it in the same slot as the other
            // status glyphs instead of retaining its old -2px visual offset.
            SysTray {
                id: systemTray
                anchors.centerIn: parent
                iconSize: 16
                visualYOffset: 0
            }
        }
        // Wi-Fi, battery, and Control Center sit to the *right* of SysTray.
        // The translucent pill is visual only: children keep independent hit
        // targets and popup anchors inside this shared status cluster.
        Rectangle {
            id: quickControlsCluster
            implicitWidth: quickControls.implicitWidth + 12
            implicitHeight: 24
            width: implicitWidth
            height: implicitHeight
            radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.16)

            Row {
                id: quickControls
                anchors.centerIn: parent
                spacing: 6

                // Equal 24px slots compensate for Row's top alignment so all
                // compact glyphs keep the same visual centre.
                Item {
                    width: networkStatus.implicitWidth
                    height: 24
                    NetworkStatus {
                        id: networkStatus
                        anchors.centerIn: parent
                        sharedPanelOpen: networkPanel.visible || bluetoothPanel.visible
                            || root.controlCenterOpen
                        onPanelToggleRequested: {
                            // Top-bar popups are mutually exclusive. Closing
                            // first also releases the Control Center focus
                            // grab before the Wi-Fi list asks for its own.
                            bluetoothPanel.close()
                            if (!networkPanel.visible) {
                                root.closeControlCenter()
                            }
                            networkPanel.toggle(networkStatus)
                        }
                    }
                }
                Item {
                    width: batteryStatus.implicitWidth
                    height: 24
                    Battery {
                        id: batteryStatus
                        anchors.centerIn: parent
                    }
                }
                ControlCenterToggle {
                    id: controlCenterToggle
                    panelOpen: root.controlCenterOpen
                    onPanelToggleRequested: {
                        bluetoothPanel.close()
                        if (!root.controlCenterOpen) {
                            networkPanel.close()
                        }
                        root.toggleControlCenter(controlCenterToggle)
                    }
                }
            }
        }
    }

    // One shared card owns the network interaction; the Wi-Fi icon remains
    // its stable visual popup anchor.
    NetworkPanel {
        id: networkPanel
    }
    BluetoothPanel {
        id: bluetoothPanel
    }
    Loader {
        id: controlCenterLoader
        active: root.controlCenterLoaded
        sourceComponent: Component {
            ControlCenterPanel {
                onNetworkRequested: {
                    root.closeControlCenter()
                    bluetoothPanel.close()
                    networkPanel.open(networkStatus)
                }
                onBluetoothRequested: {
                    root.closeControlCenter()
                    bluetoothPanel.open(controlCenterToggle)
                }
            }
        }
    }

    // The global Meta+B shortcut reaches the panel through the service's
    // intent signal; the panel instance (and its anchor item) lives here.
    Connections {
        target: ControlCenterService
        function onToggleRequested() {
            bluetoothPanel.close()
            if (!root.controlCenterOpen)
                networkPanel.close()
            root.toggleControlCenter(controlCenterToggle)
        }
    }
}
