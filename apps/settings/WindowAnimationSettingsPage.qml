import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../shared/qml/controls" as LiquidControls

ColumnLayout {
    id: page
    required property var colors
    property var backend: typeof windowSettings !== "undefined" ? windowSettings : null
    readonly property var snapshot: backend ? backend.state : ({})
    readonly property var radiusStops: [0, 8, 12, 20, 28, 36]
    readonly property var radiusLabels: ["直角", "微圆", "小", "标准", "大", "更大"]
    spacing: 12
    Component.onCompleted: { if (backend) backend.refresh() }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: takeoverColumn.implicitHeight + 32
        radius: 18
        color: page.colors.card
        ColumnLayout {
            id: takeoverColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text { text: "KOS 窗口外观"; color: page.colors.primaryText; font.pixelSize: 14; font.bold: true }
                Item { Layout.fillWidth: true }
                LiquidControls.LiquidGlassSwitch {
                    enabled: page.backend !== null
                    checked: page.snapshot.enabled !== false
                    accentColor: page.colors.accent
                    trackColor: page.colors.divider
                    onToggled: function(checked) { page.backend.setTakeover(checked) }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "启用 KOS 装饰器、圆角、描边与阴影。关闭后恢复原装饰器，其他 KWin 插件可接管外观。装饰器切换在下次登录生效。"
                wrapMode: Text.Wrap
                color: page.colors.secondaryText
                font.pixelSize: 12
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: appearanceColumn.implicitHeight + 32
        radius: 18
        color: page.colors.card
        ColumnLayout {
            id: appearanceColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 12
            enabled: page.backend !== null && page.snapshot.enabled !== false
            opacity: enabled ? 1 : 0.5
            RowLayout {
                Layout.fillWidth: true
                Text { text: "圆角幅度"; color: page.colors.primaryText; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                Text {
                    text: Number(page.snapshot.radius ?? 20) + " px"
                    color: page.colors.secondaryText
                    font.pixelSize: 12
                }
            }
            Slider {
                id: radiusSlider
                Layout.fillWidth: true
                from: 0; to: 5; stepSize: 1; snapMode: Slider.SnapAlways
                value: {
                    let best = 0
                    for (let i = 1; i < page.radiusStops.length; ++i)
                        if (Math.abs(page.radiusStops[i] - Number(page.snapshot.radius ?? 20))
                            < Math.abs(page.radiusStops[best] - Number(page.snapshot.radius ?? 20))) best = i
                    return best
                }
                onMoved: saveRadius.restart()
                Timer {
                    id: saveRadius
                    interval: 80
                    onTriggered: page.backend.setRadius(page.radiusStops[Math.round(radiusSlider.value)])
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: page.radiusLabels
                    Text {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: page.colors.secondaryText
                        font.pixelSize: 11
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "窗口阴影"; color: page.colors.primaryText; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                LiquidControls.LiquidGlassSwitch {
                    checked: page.snapshot.shadow !== false
                    accentColor: page.colors.accent
                    trackColor: page.colors.divider
                    onToggled: function(checked) { page.backend.setShadow(checked) }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: animationColumn.implicitHeight + 32
        radius: 18
        color: page.colors.card
        ColumnLayout {
            id: animationColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 14
            Text { text: "窗口动画"; color: page.colors.primaryText; font.pixelSize: 14; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "隐藏与恢复"; color: page.colors.primaryText; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                ComboBox {
                    Layout.preferredWidth: 180
                    enabled: page.backend !== null
                    model: ["无", "缩放", "水滴"]
                    currentIndex: ["none", "scale", "genie"].indexOf(page.snapshot.hideAnimation ?? "scale")
                    onActivated: function(index) { page.backend.setAnimation("hide", ["none", "scale", "genie"][index]) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "关闭窗口"; color: page.colors.primaryText; font.pixelSize: 14 }
                Item { Layout.fillWidth: true }
                ComboBox {
                    Layout.preferredWidth: 180
                    enabled: page.backend !== null
                    model: ["无", "淡出", "缩小淡出"]
                    currentIndex: ["none", "fade", "scale"].indexOf(page.snapshot.closeAnimation ?? "scale")
                    onActivated: function(index) { page.backend.setAnimation("close", ["none", "fade", "scale"][index]) }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "隐藏指最小化到 Dock。选择“无”后 KOS 不接管该动画，可由其他已启用的 KWin 效果处理。打开窗口继续使用从 Dock 展开的动画。"
                wrapMode: Text.Wrap
                color: page.colors.secondaryText
                font.pixelSize: 12
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !page.backend || page.backend.error.length > 0
        text: page.backend ? page.backend.error : "窗口设置后端不可用"
        color: "#ff453a"
        wrapMode: Text.Wrap
    }
}
