import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../../shared/qml/i18n"
import qs.desktop.modules.common
import "../../../Kos/Ui"

// The status area is edited where it is seen. Visibility is changed by the
// cards themselves and drag order is persisted by the same service used by
// Alt+drag on the live tray. Control Center remains the required end anchor.
AnimatedPopupWindow {
    id: editor

    property Item anchorItem: null
    // Reveal progress of the auto-hiding Bar this editor hangs off (1 for a Bar
    // that is permanently visible). A PopupWindow measures its anchor rectangle
    // once, when its window is created, while the Bar hides by translating its
    // whole content (barWrapper.y) -- so the window may only be created once the
    // Bar has stopped moving.
    property real barRevealProgress: 1
    readonly property bool anchorSettled: barRevealProgress > 0.999
    property bool pendingOpen: false
    // Screen of the Bar that owns this editor; the full-screen dismissal
    // catcher below is a separate surface and needs it explicitly.
    property var targetScreen: null
    readonly property color foregroundColor: AppearanceTokens.surface.pick(
        AppearanceTokens.colors.surfaceForeground,
        AppearanceTokens.isDarkTheme ? "#f5f5f7" : "#1c1c1e")
    readonly property color backgroundColor: AppearanceTokens.surface.pick(
        AppearanceTokens.colors.surfaceContainer,
        AppearanceTokens.isDarkTheme ? "#1c1c1e" : "#ffffff")
    readonly property color accentColor: AppearanceTokens.surface.pick(
        AppearanceTokens.colors.primary, "#0a84ff")
    readonly property var ids: ["network", "battery", "settings", "notifications", "controlcenter"]
    readonly property var labels: ({
        network: I18n.tr("Network"), battery: I18n.tr("Battery"),
        settings: I18n.tr("Settings"), notifications: I18n.tr("Notification History"), controlcenter: I18n.tr("Control Center")
    })
    readonly property var symbols: ({
        network: "⌁", battery: "▱", settings: "⚙", notifications: "♧", controlcenter: "◉"
    })
    readonly property var cellKeys: ids.map(id => "cell:" + id)
    readonly property var arrangedIds: {
        const arranged = SysTrayOrderService.arrange(cellKeys)
            .map(key => key.slice(5))
        for (const id of ids) {
            if (arranged.indexOf(id) < 0)
                arranged.push(id)
        }
        return arranged
    }

    implicitWidth: 424
    implicitHeight: 146
    color: "transparent"
    grabFocus: interactive
    PopupAnchorBinding { popupAnchor: editor.anchor; sourceItem: editor.anchorItem }

    anchor {
        edges: Edges.Bottom
        gravity: Edges.Bottom
        margins.bottom: 10
    }

    function openFor(item) {
        anchorItem = item
        if (anchorSettled)
            show()
        else
            pendingOpen = true
    }

    function close() {
        pendingOpen = false
        hide()
    }

    // The Bar finished sliding; create the window now that its anchor will be
    // measured against the Bar's resting position.
    onAnchorSettledChanged: {
        if (!editor.anchorSettled || !editor.pendingOpen)
            return
        editor.pendingOpen = false
        editor.show()
    }

    // An editor must never outlive a Bar that actually went away (output change,
    // visibility-mode switch, controller reset). Closing it here also releases
    // the Bar's popup inhibitor, so the controller can settle normally.
    onBarRevealProgressChanged: {
        if (editor.barRevealProgress > 0.001)
            return
        if (editor.pendingOpen || editor.requestedOpen)
            editor.close()
    }

    // Safety net: a deferred request must never be swallowed if the Bar stops
    // reporting a settled reveal. Showing the editor slightly high beats not
    // showing it at all -- but a Bar that never came back is not a Bar to anchor
    // to, so that request is dropped instead of orphaned.
    Timer {
        interval: 700
        repeat: false
        running: editor.pendingOpen
        onTriggered: {
            if (!editor.pendingOpen)
                return
            if (editor.barRevealProgress <= 0.001) {
                editor.pendingOpen = false
                return
            }
            console.info("[StatusAreaEditor] Bar reveal never settled; opening anyway")
            editor.pendingOpen = false
            editor.show()
        }
    }

    // If the display server ever closes the popup behind our back, fold the open
    // state too: otherwise `requestedOpen` keeps the Bar inhibited forever.
    onClosed: {
        if (editor.requestedOpen)
            editor.close()
    }

    Connections {
        target: ScreenLifecycle
        function onOutputAvailableChanged() {
            if (!ScreenLifecycle.outputAvailable)
                editor.close()
        }
    }

    // ── Outside-press dismissal ──────────────────────────────────────
    // An AnimatedPopupWindow anchored to the layer-shell Bar cannot take a
    // Wayland popup grab, so an explicit full-screen transparent catcher covers
    // presses on the desktop or the Bar itself while the editor is open.
    PanelWindow {
        id: dismissalCatcher
        screen: editor.targetScreen
        visible: ScreenLifecycle.outputAvailable && editor.targetScreen !== null
            && editor.requestedOpen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "quickshell-statuseditor-backdrop"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.ArrowCursor
            onPressed: editor.close()
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: editor.requestedOpen
        onActivated: editor.close()
    }

    Item {
        anchors.fill: parent
        LiquidGlassPanel {
            anchors.fill: parent
            radius: AppearanceTokens.isMaterial ? 28 : 20
            cornerExponent: AppearanceTokens.isMaterial ? 2.0 : 2.35
            baseColor: editor.backgroundColor
            surfaceOpacity: 1
            scrimEnabled: AppearanceTokens.surface.usesBackdrop
            scrimLevel: "subtle"
        }

        ColumnLayout {
            anchors { fill: parent; margins: 14 }
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                renderType: AppearanceConfigService.nativeTextRendering ? Text.NativeRendering : Text.QtRendering
                    text: I18n.tr("Status Area")
                    color: editor.foregroundColor
                    font { pixelSize: 14; weight: Font.DemiBold }
                }
                Text {
                renderType: AppearanceConfigService.nativeTextRendering ? Text.NativeRendering : Text.QtRendering
                    text: I18n.tr("Drag to reorder, tap to show or hide")
                    color: editor.foregroundColor
                    opacity: 0.58
                    font.pixelSize: 11
                }
                Item { Layout.fillWidth: true; height: 1 }
                Rectangle {
                    width: 48; height: 26; radius: AppearanceTokens.isMaterial ? 13 : 9
                    color: AppearanceTokens.surface.pick(
                        AppearanceTokens.colors.primaryContainer,
                        Qt.rgba(editor.foregroundColor.r,
                            editor.foregroundColor.g,
                            editor.foregroundColor.b, 0.10))
                    Text {
                    renderType: AppearanceConfigService.nativeTextRendering ? Text.NativeRendering : Text.QtRendering
                        anchors.centerIn: parent
                        text: I18n.tr("Done")
                        color: AppearanceTokens.surface.pick(
                            AppearanceTokens.colors.primaryContainerForeground,
                            editor.foregroundColor)
                        font { pixelSize: 11; weight: Font.DemiBold }
                    }
                    TapHandler { onTapped: editor.close() }
                }
            }

            Row {
                id: cellRow
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Repeater {
                    model: editor.arrangedIds
                    delegate: Rectangle {
                        id: cellCard
                        required property string modelData
                        readonly property bool requiredCell: modelData === "controlcenter"
                        readonly property bool active:
                            !AppearanceConfigService.isStatusCellHidden(modelData)
                        readonly property int activeIndex: editor.arrangedIds.indexOf(modelData)
                        property real dragOffset: 0
                        width: 90; height: 66
                        radius: AppearanceTokens.isMaterial ? 18 : 14
                        color: active
                            ? AppearanceTokens.surface.pick(
                                AppearanceTokens.colors.secondaryContainer,
                                Qt.rgba(editor.foregroundColor.r,
                                    editor.foregroundColor.g,
                                    editor.foregroundColor.b, 0.10))
                            : "transparent"
                        border.width: active ? 2 : 1
                        border.color: active ? AppearanceTokens.colors.primary
                            : AppearanceTokens.colors.outlineVariant
                        opacity: active ? 1 : 0.58
                        z: cellDrag.active ? 10 : 0
                        transform: Translate { x: cellCard.dragOffset }
                        scale: cellDrag.active ? 1.06 : 1
                        Behavior on scale { NumberAnimation { duration: 120 } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                            renderType: AppearanceConfigService.nativeTextRendering ? Text.NativeRendering : Text.QtRendering
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: editor.symbols[cellCard.modelData]
                                color: editor.foregroundColor
                                font.pixelSize: 19
                            }
                            Text {
                            renderType: AppearanceConfigService.nativeTextRendering ? Text.NativeRendering : Text.QtRendering
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: editor.labels[cellCard.modelData]
                                color: editor.foregroundColor
                                font { pixelSize: 10; weight: Font.DemiBold }
                            }
                            Text {
                            renderType: AppearanceConfigService.nativeTextRendering ? Text.NativeRendering : Text.QtRendering
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: cellCard.requiredCell
                                    ? I18n.tr("Pinned") : (cellCard.active ? "−" : "+")
                                color: cellCard.requiredCell ? editor.foregroundColor
                                    : (cellCard.active ? "#ff453a" : editor.accentColor)
                                opacity: cellCard.requiredCell ? 0.55 : 1
                                font { pixelSize: 10; weight: Font.Bold }
                            }
                        }

                        TapHandler {
                            enabled: !cellCard.requiredCell && !cellDrag.active
                            onTapped: AppearanceConfigService.setStatusCellVisible(
                                cellCard.modelData, !cellCard.active)
                        }
                        DragHandler {
                            id: cellDrag
                            target: null
                            enabled: cellCard.active && !cellCard.requiredCell
                            xAxis.enabled: true
                            yAxis.enabled: false
                            onTranslationChanged: if (active) cellCard.dragOffset = translation.x
                            onActiveChanged: {
                                if (active)
                                    return
                                if (Math.abs(cellCard.dragOffset) < 8) {
                                    cellCard.dragOffset = 0
                                    return
                                }
                                const delta = Math.round(cellCard.dragOffset
                                    / (cellCard.width + cellRow.spacing))
                                SysTrayOrderService.moveKey("cell:" + cellCard.modelData,
                                    Math.max(0, Math.min(editor.arrangedIds.length - 2,
                                        cellCard.activeIndex + delta)), editor.cellKeys)
                                cellCard.dragOffset = 0
                            }
                        }
                    }
                }
            }
        }
    }
}
