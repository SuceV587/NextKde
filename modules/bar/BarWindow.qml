import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.modules.dock

// iPadOS-inspired top status bar for one concrete output.
PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    // Keep persistent chrome on the normal layer-shell Top layer.
    WlrLayershell.layer: WlrLayer.Top
    implicitHeight: 35
    exclusiveZone: implicitHeight

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
                        sharedPanelOpen: networkPanel.visible || bluetoothPanel.visible || controlCenter.isOpen
                        onPanelToggleRequested: {
                            // Top-bar popups are mutually exclusive. Closing
                            // first also releases the Control Center focus
                            // grab before the Wi-Fi list asks for its own.
                            bluetoothPanel.close()
                            if (!networkPanel.visible) {
                                controlCenter.close()
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
                    panelOpen: controlCenter.isOpen
                    onPanelToggleRequested: {
                        bluetoothPanel.close()
                        if (!controlCenter.isOpen) {
                            networkPanel.close()
                        }
                        controlCenter.toggle(controlCenterToggle)
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
    ControlCenterPanel {
        id: controlCenter
        onNetworkRequested: {
            controlCenter.close()
            bluetoothPanel.close()
            networkPanel.open(networkStatus)
        }
        onBluetoothRequested: {
            controlCenter.close()
            bluetoothPanel.open(controlCenterToggle)
        }
    }
}
