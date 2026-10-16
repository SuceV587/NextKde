import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../../../shared/qml/controls" as LiquidControls
import "../../../shared/qml/foundation" as Foundation
import "../../../shared/qml/i18n"
import "../components" as Controls

ColumnLayout {
    id: section
    Layout.fillWidth: true
    spacing: 8
    required property var colors
    property bool materialForm: false
    property var stageSnapshot: ({})
    signal settingRequested(string key, var value)

    Rectangle {
        Layout.fillWidth: true
        radius: 14
        color: colors.card
        implicitHeight: glassColumn.implicitHeight + 32

        ColumnLayout {
            id: glassColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: I18n.tr("Glass texture")
                color: colors.primaryText
                font { pixelSize: 14; weight: Font.Medium }
            }

            Controls.StageSliderRow {
                objectName: "stage-card-radius-row"
                colors: section.colors
                label: I18n.tr("Card corner radius")
                unit: " px"
                minV: 0
                maxV: 24
                current: section.stageSnapshot.cardRadius !== undefined
                    ? section.stageSnapshot.cardRadius : 14
                onCommit: function(v) { section.settingRequested("cardRadius", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Card opacity")
                unit: ""
                minV: 0.2
                maxV: 1
                decimals: 2
                current: section.stageSnapshot.cardOpacity !== undefined
                    ? section.stageSnapshot.cardOpacity : 1.0
                onCommit: function(v) { section.settingRequested("cardOpacity", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Backdrop density")
                unit: ""
                minV: 0.2
                maxV: 0.95
                decimals: 2
                current: section.stageSnapshot.cardTint !== undefined
                    ? section.stageSnapshot.cardTint : 0.55
                onCommit: function(v) { section.settingRequested("cardTint", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Top-lit")
                unit: ""
                minV: 0
                maxV: 0.3
                decimals: 2
                current: section.stageSnapshot.cardTopLight !== undefined
                    ? section.stageSnapshot.cardTopLight : 0.07
                onCommit: function(v) { section.settingRequested("cardTopLight", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Outline brightness")
                unit: ""
                minV: 0
                maxV: 0.4
                decimals: 2
                current: section.stageSnapshot.cardBorder !== undefined
                    ? section.stageSnapshot.cardBorder : 0.13
                onCommit: function(v) { section.settingRequested("cardBorder", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                // 辉光是静态快照的扇叠背板效果（实时直绘模式无辉光
                // pass，v57 撤）——实时模式下隐藏防"拖了没反应"
                visible: section.stageSnapshot.thumbLiveEffect !== true
                label: I18n.tr("Focus glow strength (static mode)")
                unit: ""
                minV: 0
                maxV: 0.4
                decimals: 2
                current: section.stageSnapshot.cardGlow !== undefined
                    ? section.stageSnapshot.cardGlow : 0.13
                onCommit: function(v) { section.settingRequested("cardGlow", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Depth dimming")
                unit: ""
                minV: 0
                maxV: 0.6
                decimals: 2
                current: section.stageSnapshot.cardDepth !== undefined
                    ? section.stageSnapshot.cardDepth : 0.38
                onCommit: function(v) { section.settingRequested("cardDepth", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Thumbnail sharpness")
                unit: " px"
                minV: 160
                maxV: 640
                current: section.stageSnapshot.thumbSize !== undefined
                    ? section.stageSnapshot.thumbSize : 320
                onCommit: function(v) { section.settingRequested("thumbSize", v)
            }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        radius: 14
        color: colors.card
        implicitHeight: demoteColumn.implicitHeight + 32

        ColumnLayout {
            id: demoteColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: I18n.tr("Collect and refresh timing")
                color: colors.primaryText
                font { pixelSize: 14; weight: Font.Medium }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Collect snapshot wait")
                unit: " ms"
                minV: 100
                maxV: 1500
                current: section.stageSnapshot.demoteCaptureDelay !== undefined
                    ? section.stageSnapshot.demoteCaptureDelay : 300
                onCommit: function(v) { section.settingRequested("demoteCaptureDelay", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Collect dispatch delay")
                unit: " ms"
                minV: 10
                maxV: 200
                current: section.stageSnapshot.demoteDispatchDelay !== undefined
                    ? section.stageSnapshot.demoteDispatchDelay : 30
                onCommit: function(v) { section.settingRequested("demoteDispatchDelay", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Desktop collect debounce")
                unit: " ms"
                minV: 50
                maxV: 1000
                current: section.stageSnapshot.desktopFocusDebounce !== undefined
                    ? section.stageSnapshot.desktopFocusDebounce : 150
                onCommit: function(v) { section.settingRequested("desktopFocusDebounce", v)
            }
            }

            Text {
                Layout.fillWidth: true
                text: I18n.tr("Two-phase collect: wait for the snapshot first (multi-window captures take time), persist the rectangles, then dispatch the minimization")
                      + I18n.tr(" (matched against the expand animation).")
                color: colors.secondaryText
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        radius: 14
        color: colors.card
        implicitHeight: animColumn.implicitHeight + 32

        ColumnLayout {
            id: animColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            Text {
                text: I18n.tr("Window switch animation")
                color: colors.primaryText
                font { pixelSize: 14; weight: Font.Medium }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Animation duration")
                unit: " ms"
                minV: 120
                maxV: 2000
                current: section.stageSnapshot.animDuration !== undefined
                    ? section.stageSnapshot.animDuration : 420
                onCommit: function(v) { section.settingRequested("animDuration", v)
            }
            }

            Controls.StageSliderRow {
                colors: section.colors
                label: I18n.tr("Flying glass opacity")
                unit: "×"
                minV: 0.3
                maxV: 1.0
                decimals: 2
                current: section.stageSnapshot.glassOpacity !== undefined
                    ? section.stageSnapshot.glassOpacity : 0.65
                onCommit: function(v) { section.settingRequested("glassOpacity", v)
            }
            }

            Text {
                text: I18n.tr("Easing curve")
                color: colors.primaryText
                font.pixelSize: 13
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        { id: "OutCubic", label: I18n.tr("Fast out, gentle stop (default)") },
                        { id: "OutQuad", label: I18n.tr("Gentler") },
                        { id: "InOutCubic", label: I18n.tr("Slow-fast-slow") },
                        { id: "OutBack", label: I18n.tr("End overshoot") },
                        { id: "InOutQuad", label: I18n.tr("Soft edges") },
                        { id: "Linear", label: I18n.tr("Linear") },
                    ]

                    delegate: Rectangle {
                        required property var modelData
                        width: curveLabel.implicitWidth + 22
                        height: 28
                        radius: 9
                        property bool isActive: section.stageSnapshot.animEasing === modelData.id
                        color: isActive
                            ? colors.selectedContainer
                            : (curveMouse.containsMouse
                                ? colors.searchField : colors.sidebar)
                        border.width: isActive ? 2 : 0
                        border.color: colors.accent

                        Text {
                            id: curveLabel
                            anchors.centerIn: parent
                            text: modelData.label
                            color: parent.isActive
                                ? colors.selectedForeground : colors.primaryText
                            font { pixelSize: 12; weight: Font.Medium }
                        }

                        MouseArea {
                            id: curveMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: section.settingRequested(
                                "animEasing", modelData.id)
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: I18n.tr("Animation for windows growing out of / back into cards; duration and curve changes apply instantly, ")
                      + I18n.tr("Also adjustable temporarily via the stage-anim CLI. Flying glass opacity: ")
                      + I18n.tr("Windows are translucent mid-flight between card and desktop (desktop shows through), solidifying on landing; ")
                      + I18n.tr("1.00 disables the glass feel.")
                color: colors.secondaryText
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }
    }
}
