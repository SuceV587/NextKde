import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import "../../shared/qml/controls" as LiquidControls

ApplicationWindow {
    id: window

    width: 1100
    height: 720
    minimumWidth: 840
    minimumHeight: 560
    visible: true
    title: "kos设置界面"
    color: theme.background

    property int currentPage: 0
    property string searchText: ""

    // Qt updates SystemPalette when the desktop colour scheme changes. We use
    // it only to select the system appearance, then apply the matching iPadOS
    // palette so both modes keep a coherent Settings visual language.
    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    QtObject {
        id: theme

        readonly property bool dark: {
            const color = systemPalette.window
            return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722 < 0.5
        }
        readonly property color background: dark ? "#000000" : "#f2f2f7"
        readonly property color sidebar: dark ? "#1c1c1e" : "#fafbff"
        readonly property color contentSurface: dark ? "#000000" : "#fafbff"
        readonly property color primaryText: dark ? "#f5f5f7" : "#1c1c1e"
        readonly property color secondaryText: dark ? "#98989d" : "#6d6d72"
        readonly property color tertiaryText: dark ? "#8e8e93" : "#8e8e93"
        readonly property color card: dark ? "#1c1c1e" : "#ffffff"
        readonly property color separator: dark ? "#38383a" : "#e5e5ea"
        readonly property color divider: dark ? "#2c2c2e" : "#d1d1d6"
        readonly property color searchField: dark ? "#2c2c2e" : "#e3e3e8"
        readonly property color selected: dark ? "#0a84ff" : "#d9e9ff"
        readonly property color sidebarHover: dark
            ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.045)
        readonly property color chevron: dark ? "#636366" : "#c7c7cc"
        readonly property color iconForeground: "#ffffff"
        readonly property color floatingBorder: dark
            ? Qt.rgba(1, 1, 1, 0.075) : Qt.rgba(0, 0, 0, 0.055)
        readonly property color floatingShadow: dark
            ? Qt.rgba(0, 0, 0, 0.42) : Qt.rgba(0.17, 0.21, 0.30, 0.16)
        readonly property color previewPane: dark ? "#14151a" : "#eef2f7"
        readonly property color previewBar: dark ? "#2c2d35" : "#ffffff"
        readonly property color previewTaskbar: dark ? "#1e2028" : "#ffffff"
        readonly property color previewDock: dark ? "#323540" : "#ffffff"
        readonly property color previewIcon: dark ? "#a0a4b0" : "#7c8290"
    }
    readonly property var contentByPage: [
        {
            subtitle: "外观",
            groups: []
        },
        {
            subtitle: "顶栏",
            groups: []
        },
        {
            subtitle: "Dock",
            groups: []
        },
        {
            subtitle: "启动台",
            groups: []
        },
        {
            subtitle: "快捷键",
            groups: []
        },
        {
            subtitle: "接入状态",
            groups: []
        }
    ]

    component SettingIcon: Rectangle {
        required property string symbol
        required property color tint
        width: 29
        height: 29
        radius: 10
        color: tint
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -0.5
            text: symbol
            color: theme.iconForeground
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    component SidebarEntry: ItemDelegate {
        required property int pageIndex
        required property string label
        required property string navSymbol
        required property color navTint
        width: parent ? parent.width : 0
        height: 40
        leftPadding: 10
        rightPadding: 10
        highlighted: window.currentPage === pageIndex
        visible: window.searchText.length === 0
            || label.toLowerCase().indexOf(window.searchText.toLowerCase()) >= 0
        background: Rectangle {
            radius: 18
            color: parent.highlighted ? theme.selected
                : (parent.hovered ? theme.sidebarHover : "transparent")
        }
        contentItem: Item {
            implicitHeight: 40
            SettingIcon {
                id: sidebarIcon
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                symbol: navSymbol
                tint: navTint
            }
            Text {
                anchors.left: sidebarIcon.right
                anchors.leftMargin: 10
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: label
                color: theme.primaryText
                font.pixelSize: 13
                font.weight: window.currentPage === pageIndex
                    ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }
        onClicked: window.currentPage = pageIndex
    }

    // One visual contract for every segmented choice in Settings. Individual
    // rows only provide model/currentIndex and content-driven width overrides.
    component SettingsNavBar: LiquidControls.LiquidNavBar {
        size: "tiny"
        accentColor: theme.dark ? "#64b5ff" : "#0066cc"
        itemColor: theme.dark ? "#ffffff" : "#1c1c1e"
        trackColor: theme.dark
            ? Qt.rgba(1, 1, 1, 0.10) : "#d1d1d6"
        labelFontPixelSize: 10
        labelFontWeight: Font.DemiBold
    }

    component SettingRow: Item {
        required property var row
        width: ListView.view ? ListView.view.width : parent.width
        height: 48

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 13
            anchors.rightMargin: 13
            spacing: 11
            SettingIcon { symbol: row.icon; tint: row.tint }
            Text {
                Layout.fillWidth: true
                text: row.title
                color: theme.primaryText
                font.pixelSize: 14
                elide: Text.ElideRight
            }
            Text {
                text: row.detail
                color: theme.tertiaryText
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.maximumWidth: 180
            }
            Text {
                text: "›"
                color: theme.chevron
                font.pixelSize: 24
                font.weight: Font.Light
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 53
            anchors.bottom: parent.bottom
            height: 1
            color: theme.separator
            visible: index < ListView.view.count - 1
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
        }
    }

    component IntegrationStatusPage: ColumnLayout {
        id: integrationPage

        Layout.fillWidth: true
        spacing: 8
        property var bridge: (typeof settingsBridge !== "undefined")
            ? settingsBridge : null
        property var snapshot: ({})
        property string errorText: ""

        function refresh() {
            if (!bridge) {
                errorText = "尚未构建 Settings 桥接程序"
                return
            }
            snapshot = bridge.integrationSnapshot()
            errorText = bridge.lastError || ""
        }

        function notificationState() {
            const provider = snapshot.notificationProvider || "none"
            if (provider === "kos")
                return { label: "KOS 已接管", color: "#30d158",
                    detail: "通知将显示在 KOS 通知中心" }
            if (provider === "plasma")
                return { label: "Plasma 接管", color: "#ff9f0a",
                    detail: "KOS 正在等待 org.freedesktop.Notifications 所有权" }
            if (provider === "other")
                return { label: "其他程序接管", color: "#ff9f0a",
                    detail: snapshot.notificationCommand || snapshot.notificationOwner || "未知通知服务" }
            return { label: "未注册", color: "#ff453a",
                detail: "当前没有可用的桌面通知服务" }
        }

        function statusRow(icon, tint, title, ready, readyLabel, detail) {
            return { icon: icon, tint: tint, title: title,
                label: ready ? readyLabel : "未连接",
                color: ready ? "#30d158" : "#ff453a", detail: detail }
        }

        readonly property var notification: notificationState()
        readonly property var rows: [
            statusRow("K", "#0a84ff", "KOS Shell", !!snapshot.shellReady,
                "运行中", "设置页与 Quickshell IPC 通道"),
            statusRow("↔", "#5ac8fa", "平台桥接", !!snapshot.platformConnected,
                "已连接", "窗口、网络、音频与系统操作"),
            statusRow("D", "#34c759", "数据服务", !!snapshot.dataConnected,
                "已连接", "系统指标、活动记录与桌面文件"),
            statusRow("▦", "#af52de", "桌面组件", !!snapshot.desktopWidgetsVisible,
                "已显示", snapshot.desktopFilesReady
                    ? "时钟、天气、资源卡片与桌面文件已就绪"
                    : "组件层已显示，桌面文件仍在同步"),
            { icon: "N", tint: "#ff9500", title: "通知接管",
                label: notification.label, color: notification.color,
                detail: notification.detail },
            statusRow("G", "#64d2ff", "Glass 特效", !!snapshot.glassLoaded,
                "已加载", "KWin 模糊与液态玻璃效果"),
            statusRow("A", "#ff375f", "Dock 窗口动画",
                !!snapshot.dockAnimationLoaded, "已加载", "KWin Dock 缩放／Genie 动画"),
            statusRow("I", "#bf5af2", "桌面输入桥接",
                !!snapshot.contextMenuInputLoaded, "已加载", "全局点击与菜单收起事件")
        ]

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13

            Text {
                Layout.fillWidth: true
                text: snapshot.updatedAt
                    ? "最后检查 " + snapshot.updatedAt : "正在读取实时状态…"
                color: theme.secondaryText
                font.pixelSize: 12
            }

            Rectangle {
                implicitWidth: 72
                implicitHeight: 30
                radius: 15
                color: refreshPointer.containsMouse
                    ? theme.sidebarHover : theme.card
                border.width: 1
                border.color: theme.floatingBorder

                Text {
                    anchors.centerIn: parent
                    text: "刷新"
                    color: theme.primaryText
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    id: refreshPointer
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: integrationPage.refresh()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: statusColumn.implicitHeight + 8
            radius: 24
            color: theme.card

            Column {
                id: statusColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 4

                Repeater {
                    model: integrationPage.rows

                    delegate: Item {
                        required property var modelData
                        required property int index
                        width: statusColumn.width
                        height: 62

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 12
                            spacing: 11

                            SettingIcon {
                                symbol: modelData.icon
                                tint: modelData.tint
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text {
                                    text: modelData.title
                                    color: theme.primaryText
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.detail
                                    color: theme.secondaryText
                                    font.pixelSize: 11
                                    elide: Text.ElideRight
                                }
                            }
                            Rectangle {
                                implicitWidth: statusLabel.implicitWidth + 18
                                implicitHeight: 24
                                radius: 12
                                color: theme.dark
                                    ? Qt.rgba(1, 1, 1, 0.09)
                                    : Qt.rgba(0, 0, 0, 0.055)
                                Text {
                                    id: statusLabel
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: modelData.color
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 49
                            anchors.bottom: parent.bottom
                            height: 1
                            color: theme.separator
                            visible: index < integrationPage.rows.length - 1
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            visible: errorText.length > 0
            text: errorText
            color: "#ff453a"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Timer {
            interval: 5000
            repeat: true
            running: integrationPage.visible
            onTriggered: integrationPage.refresh()
        }
        Component.onCompleted: refresh()
    }

    component DockSettingsPage: ColumnLayout {
        id: dockPage

        Layout.fillWidth: true
        spacing: 7
        property var bridge: (typeof settingsBridge !== "undefined") ? settingsBridge : null
        property real dockHeight: 60
        property int dockPositionIndex: 0
        readonly property var dockPositions: ["bottom", "left", "right"]
        property int iconModeIndex: 0
        readonly property var iconModes: ["color", "grayscale", "tint"]
        property int visibilityModeIndex: 0
        readonly property var visibilityModes: ["always", "smart", "persistent"]
        property int windowGroupingIndex: 0
        readonly property var windowGroupings: ["grouped", "separate"]
        property real iconOpacity: 0.5
        property string iconTintColor: "#a855f7"
        readonly property var tintPresets: [
            { label: "紫色", color: "#a855f7" },
            { label: "红色", color: "#ef4444" },
            { label: "蓝色", color: "#3b82f6" },
            { label: "橙色", color: "#f97316" }
        ]
        property real tintHuePosition: 0.75
        property real tintTonePosition: 0.5
        readonly property color pureTintHue: Qt.hsva(tintHuePosition, 1, 1, 1)
        readonly property color selectedTintColor: toneColor(tintTonePosition)
        readonly property var hueRamp: [
            Qt.hsva(0 / 6, 1, 1, 1), Qt.hsva(1 / 6, 1, 1, 1),
            Qt.hsva(2 / 6, 1, 1, 1), Qt.hsva(3 / 6, 1, 1, 1),
            Qt.hsva(4 / 6, 1, 1, 1), Qt.hsva(5 / 6, 1, 1, 1),
            Qt.hsva(6 / 6, 1, 1, 1)
        ]
        readonly property var toneRamp: [
            Qt.rgba(1, 1, 1, 1), blend(Qt.rgba(1, 1, 1, 1), pureTintHue, 1 / 3),
            blend(Qt.rgba(1, 1, 1, 1), pureTintHue, 2 / 3), pureTintHue,
            blend(pureTintHue, Qt.rgba(0, 0, 0, 1), 1 / 3),
            blend(pureTintHue, Qt.rgba(0, 0, 0, 1), 2 / 3), Qt.rgba(0, 0, 0, 1)
        ]
        property bool iconOpacityDirty: false
        property string errorText: ""
        property bool layoutDirty: false

        property bool dockBlurInherit: true
        property real dockBlurStrength: 0.42
        property real dockLiquidStrength: 1.0
        property bool dockBlurDirty: false
        property bool dockLiquidDirty: false

        function percentage(value) {
            return Math.round(value * 100) + "%"
        }

        function setDockBlurInherit(enabled) {
            if (!bridge) return
            applyAppearanceState(bridge.updateDockBlurInherit(enabled))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        Timer {
            id: liveDockBlurDebounce
            interval: 60
            repeat: false
            onTriggered: {
                if (dockPage.bridge && dockPage.dockBlurDirty) {
                    dockPage.bridge.updateDockBlurStrength(dockPage.dockBlurStrength)
                }
            }
        }

        Timer {
            id: liveDockLiquidDebounce
            interval: 60
            repeat: false
            onTriggered: {
                if (dockPage.bridge && dockPage.dockLiquidDirty) {
                    dockPage.bridge.updateDockLiquidStrength(dockPage.dockLiquidStrength)
                }
            }
        }

        function previewDockBlur(value) {
            const clamped = Math.max(0, Math.min(1, value))
            if (Math.abs(dockBlurStrength - clamped) < 0.005)
                return
            dockBlurStrength = clamped
            dockBlurDirty = true
            liveDockBlurDebounce.restart()
        }

        function commitDockBlur() {
            liveDockBlurDebounce.stop()
            if (!dockBlurDirty || !bridge)
                return
            dockBlurDirty = false
            applyAppearanceState(bridge.updateDockBlurStrength(dockBlurStrength))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function previewDockLiquid(value) {
            const clamped = Math.max(0, Math.min(1, value))
            if (Math.abs(dockLiquidStrength - clamped) < 0.005)
                return
            dockLiquidStrength = clamped
            dockLiquidDirty = true
            liveDockLiquidDebounce.restart()
        }

        function commitDockLiquid() {
            liveDockLiquidDebounce.stop()
            if (!dockLiquidDirty || !bridge)
                return
            dockLiquidDirty = false
            applyAppearanceState(bridge.updateDockLiquidStrength(dockLiquidStrength))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function applyAppearanceState(state) {
            if (!state) return
            dockBlurInherit = state.dockBlurInherit !== undefined ? Boolean(state.dockBlurInherit) : true
            dockBlurStrength = Number.isFinite(Number(state.dockBlurStrength)) ? Number(state.dockBlurStrength) : 0.42
            dockLiquidStrength = Number.isFinite(Number(state.dockLiquidStrength)) ? Number(state.dockLiquidStrength) : 1.0
            dockBlurDirty = false
            dockLiquidDirty = false
        }

        function positionIndexFromString(position) {
            const idx = dockPositions.indexOf(position)
            return idx >= 0 ? idx : 0
        }

        function iconModeIndexFromString(mode) {
            if (mode === "duotone")
                mode = "tint"
            const idx = iconModes.indexOf(mode)
            return idx >= 0 ? idx : 0
        }

        function visibilityModeIndexFromString(mode) {
            const idx = visibilityModes.indexOf(mode)
            return idx >= 0 ? idx : 0
        }

        function windowGroupingIndexFromString(mode) {
            const idx = windowGroupings.indexOf(mode)
            return idx >= 0 ? idx : 0
        }

        function colorHex(color) {
            function channel(value) {
                return Math.round(value * 255).toString(16).padStart(2, "0")
            }
            return "#" + channel(color.r) + channel(color.g) + channel(color.b)
        }

        function colorFromHex(value) {
            const hex = String(value).replace("#", "")
            if (hex.length !== 6)
                return Qt.rgba(0.66, 0.33, 0.97, 1)
            return Qt.rgba(
                parseInt(hex.slice(0, 2), 16) / 255,
                parseInt(hex.slice(2, 4), 16) / 255,
                parseInt(hex.slice(4, 6), 16) / 255,
                1)
        }

        function blend(first, second, amount) {
            return Qt.rgba(
                first.r + (second.r - first.r) * amount,
                first.g + (second.g - first.g) * amount,
                first.b + (second.b - first.b) * amount,
                1)
        }

        function toneColor(position) {
            if (position <= 0.5)
                return blend(Qt.rgba(1, 1, 1, 1), pureTintHue, position * 2)
            return blend(pureTintHue, Qt.rgba(0, 0, 0, 1), (position - 0.5) * 2)
        }

        function hueForColor(color) {
            const maximum = Math.max(color.r, color.g, color.b)
            const minimum = Math.min(color.r, color.g, color.b)
            const delta = maximum - minimum
            if (delta < 0.0001)
                return tintHuePosition
            let hue = 0
            if (maximum === color.r)
                hue = ((color.g - color.b) / delta) % 6
            else if (maximum === color.g)
                hue = (color.b - color.r) / delta + 2
            else
                hue = (color.r - color.g) / delta + 4
            return ((hue / 6) + 1) % 1
        }

        function nearestToneForColor(color) {
            let closestPosition = 0.5
            let closestDistance = Number.MAX_VALUE
            for (let step = 0; step <= 200; step++) {
                const position = step / 200
                const candidate = toneColor(position)
                const distance = Math.pow(candidate.r - color.r, 2)
                    + Math.pow(candidate.g - color.g, 2)
                    + Math.pow(candidate.b - color.b, 2)
                if (distance < closestDistance) {
                    closestDistance = distance
                    closestPosition = position
                }
            }
            return closestPosition
        }

        function syncTintControls(color) {
            tintHuePosition = hueForColor(color)
            tintTonePosition = nearestToneForColor(color)
        }

        function presetMatches(preset) {
            return preset.color === iconTintColor
        }

        function tintPresetIndex() {
            for (let index = 0; index < tintPresets.length; index++) {
                if (presetMatches(tintPresets[index]))
                    return index
            }
            return 0
        }

        function applyState(state) {
            if (!state || state.baseHeight === undefined)
                return
            dockHeight = Number(state.baseHeight)
            dockPositionIndex = positionIndexFromString(state.position)
            iconModeIndex = iconModeIndexFromString(state.iconMode)
            iconOpacity = Number(state.iconOpacity)
            iconTintColor = String(state.iconTintColor || "#a855f7").toLowerCase()
            syncTintControls(colorFromHex(iconTintColor))
            visibilityModeIndex = visibilityModeIndexFromString(state.visibilityMode)
            windowGroupingIndex = windowGroupingIndexFromString(state.windowGrouping)
            iconOpacityDirty = false
            layoutDirty = false
            errorText = ""
        }

        function savePosition(index) {
            if (!bridge)
                return
            const position = dockPositions[index]
            applyState(bridge.updateDockPosition(position))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveIconMode(index) {
            if (!bridge)
                return
            const mode = iconModes[index]
            applyState(bridge.updateDockIconMode(mode))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveTintColor(color) {
            if (!bridge)
                return
            applyState(bridge.updateDockIconTintColor(color))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveVisibilityMode(index) {
            if (!bridge)
                return
            const mode = visibilityModes[index]
            applyState(bridge.updateDockVisibilityMode(mode))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveWindowGrouping(index) {
            if (!bridge)
                return
            const mode = windowGroupings[index]
            applyState(bridge.updateDockWindowGrouping(mode))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function applyTintPreset(index) {
            saveTintColor(tintPresets[index].color)
        }

        function refresh() {
            if (!bridge) {
                errorText = "尚未构建 Settings 桥接程序"
                return
            }
            applyState(bridge.dockSnapshot())
            applyAppearanceState(bridge.appearanceSnapshot())
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveLayout() {
            if (!bridge)
                return
            applyState(bridge.updateDockLayout(dockHeight))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function previewDockHeight(position) {
            const nextHeight = Math.round(40 + position * 60)
            if (nextHeight === dockHeight)
                return
            dockHeight = nextHeight
            layoutDirty = true
        }

        function commitLayout() {
            if (!layoutDirty)
                return
            layoutDirty = false
            saveLayout()
        }

        function previewIconOpacity(position) {
            const nextOpacity = Math.max(0.1, Math.round(position * 100) / 100)
            if (Math.abs(iconOpacity - nextOpacity) < 0.001)
                return
            iconOpacity = nextOpacity
            iconOpacityDirty = true
        }

        function commitIconOpacity() {
            if (!iconOpacityDirty || !bridge)
                return
            iconOpacityDirty = false
            applyState(bridge.updateDockIconOpacity(iconOpacity))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        Component.onCompleted: refresh()

        Text {
            text: "大小和位置".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
        }

        Rectangle {
            Layout.fillWidth: true
            color: theme.card
            radius: 18
            implicitHeight: 97

            Column {
                anchors.fill: parent

                Item {
                    width: parent.width
                    height: 48
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "▰"; tint: "#0a84ff" }
                        Text {
                            text: "Dock 高度"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(dockPage.dockHeight) + " pt"
                            color: theme.secondaryText
                            font.pixelSize: 12
                        }
                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 190
                            value: (dockPage.dockHeight - 40) / 60
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                dockPage.previewDockHeight(position)
                            }
                            onCommitRequested: dockPage.commitLayout()
                        }
                    }
                }
            }
        }

        Text {
            text: "窗口".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 14
        }

        Rectangle {
            Layout.fillWidth: true
            color: theme.card
            radius: 18
            implicitHeight: 54

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                SettingIcon { symbol: "▦"; tint: "#5856d6" }
                Text {
                    text: "是否按应用合并窗口"
                    color: theme.primaryText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                LiquidControls.LiquidGlassSwitch {
                    id: windowGroupingSwitch
                    checked: dockPage.windowGroupingIndex === 0
                    accentColor: "#0a84ff"
                    trackColor: theme.divider
                    onToggled: function(checked) {
                        const requestedIndex = checked ? 0 : 1
                        if (requestedIndex !== dockPage.windowGroupingIndex) {
                            dockPage.saveWindowGrouping(requestedIndex)
                        }
                        // The shared switch owns its checked state after a
                        // click. Put it back to the IPC-confirmed value.
                        windowGroupingSwitch.checked = dockPage.windowGroupingIndex === 0
                    }
                }
            }
        }

        Text {
            text: "DOCK 程序栏".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 14
        }

        Rectangle {
            Layout.fillWidth: true
            color: theme.card
            radius: 18
            implicitHeight: 111

            Column {
                anchors.fill: parent

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "▣"; tint: "#0a84ff" }
                        Text {
                            text: "Dock 位置"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            id: positionNavBar
                            model: [
                                { id: "bottom", icon: "↓" },
                                { id: "left",   icon: "←" },
                                { id: "right",  icon: "→" }
                            ]
                            currentIndex: dockPage.dockPositionIndex
                            onSelectionChanged: function(index) {
                                dockPage.savePosition(index)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "◉"; tint: "#0a84ff" }
                        Text {
                            text: "Dock 显示方式"
                            color: theme.primaryText
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            id: visibilityNavBar
                            model: [
                                { id: "always", label: "始终显示" },
                                { id: "smart", label: "智能隐藏" },
                                { id: "persistent", label: "持续隐藏" }
                            ]
                            itemWidthOverride: 76
                            currentIndex: dockPage.visibilityModeIndex
                            onSelectionChanged: function(index) {
                                dockPage.saveVisibilityMode(index)
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "图标风格".toUpperCase()
            visible: false
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 14
        }

        Rectangle {
            Layout.fillWidth: true
            visible: false
            color: theme.card
            radius: 18
            implicitHeight: iconOpacityColumn.implicitHeight

            Column {
                id: iconOpacityColumn
                anchors.fill: parent

                Item {
                    width: parent.width
                    height: 48
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "◐"; tint: "#af52de" }
                        Text {
                            text: "Dock 颜色"
                            color: theme.primaryText
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            id: iconModeNavBar
                            model: [
                                { id: "color", label: "彩色" },
                                { id: "grayscale", label: "黑白" },
                                { id: "tint", label: "染色" }
                            ]
                            currentIndex: dockPage.iconModeIndex

                            Connections {
                                target: iconModeNavBar
                                function onSelectionChanged(index) {
                                    dockPage.saveIconMode(index)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                    visible: dockPage.iconModeIndex > 0
                }

                Item {
                    id: iconOpacityRow
                    width: parent.width
                    height: dockPage.iconModeIndex > 0 ? 48 : 0
                    visible: dockPage.iconModeIndex > 0
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "◔"; tint: "#5ac8fa" }
                        Text {
                            text: "不透明度"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Math.round(dockPage.iconOpacity * 100) + "%"
                            color: theme.secondaryText
                            font.pixelSize: 12
                        }
                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 190
                            value: dockPage.iconOpacity
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                dockPage.previewIconOpacity(position)
                            }
                            onCommitRequested: dockPage.commitIconOpacity()
                        }
                    }
                }
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                    visible: dockPage.iconModeIndex === 2
                }

                Item {
                    width: parent.width
                    height: dockPage.iconModeIndex === 2 ? 58 : 0
                    visible: dockPage.iconModeIndex === 2
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 8
                        SettingIcon { symbol: "▦"; tint: "#ff9f0a" }
                        Text {
                            text: "快速方案"
                            color: theme.primaryText
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            id: tintPresetNavBar
                            model: [
                                { id: "purple", label: "紫色" },
                                { id: "red", label: "红色" },
                                { id: "blue", label: "蓝色" },
                                { id: "orange", label: "橙色" }
                            ]
                            currentIndex: dockPage.tintPresetIndex()
                            onSelectionChanged: function(index) {
                                dockPage.applyTintPreset(index)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                    visible: dockPage.iconModeIndex === 2
                }

                Item {
                    width: parent.width
                    height: dockPage.iconModeIndex === 2 ? 48 : 0
                    visible: dockPage.iconModeIndex === 2
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 9
                        SettingIcon { symbol: "●"; tint: dockPage.iconTintColor }
                        Text {
                            text: "自定义颜色"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            id: tintPreview
                            width: 28
                            height: 28
                            radius: 9
                            color: dockPage.iconTintColor
                            border.width: 1
                            border.color: theme.dark ? "#55ffffff" : "#22000000"
                        }
                        Text {
                            text: "›"
                            color: theme.chevron
                            font.pixelSize: 24
                            font.weight: Font.Light
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                    visible: dockPage.iconModeIndex === 2
                }

                Item {
                    width: parent.width
                    height: dockPage.iconModeIndex === 2 ? 48 : 0
                    visible: dockPage.iconModeIndex === 2
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Item { Layout.fillWidth: true }
                        LiquidControls.ColorRampSlider {
                            Layout.preferredWidth: 190
                            value: dockPage.tintHuePosition
                            rampColors: dockPage.hueRamp
                            thumbColor: dockPage.pureTintHue
                            onPreviewChanged: function(position) {
                                dockPage.tintHuePosition = position
                            }
                            onCommitRequested: dockPage.saveTintColor(
                                dockPage.colorHex(dockPage.selectedTintColor))
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                    visible: dockPage.iconModeIndex === 2
                }

                Item {
                    width: parent.width
                    height: dockPage.iconModeIndex === 2 ? 48 : 0
                    visible: dockPage.iconModeIndex === 2
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        Item { Layout.fillWidth: true }
                        LiquidControls.ColorRampSlider {
                            Layout.preferredWidth: 190
                            value: dockPage.tintTonePosition
                            rampColors: dockPage.toneRamp
                            thumbColor: dockPage.selectedTintColor
                            onPreviewChanged: function(position) {
                                dockPage.tintTonePosition = position
                            }
                            onCommitRequested: dockPage.saveTintColor(
                                dockPage.colorHex(dockPage.selectedTintColor))
                        }
                    }
                }

            }
        }

        Text {
            text: "外观与模糊效果".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 14
            visible: false
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: dockBlurCol.implicitHeight
            visible: false
            radius: 18
            color: theme.card

            Column {
                id: dockBlurCol
                anchors.left: parent.left
                anchors.right: parent.right

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "⎘"; tint: "#30d158" }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "跟随显示设置"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "关闭后可为 Dock 单独自定义背景模糊与液态强度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                            }
                        }
                        LiquidControls.LiquidGlassSwitch {
                            checked: dockPage.dockBlurInherit
                            accentColor: "#30d158"
                            trackColor: theme.divider
                            onToggled: function(checked) {
                                dockPage.setDockBlurInherit(checked)
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !dockPage.dockBlurInherit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    visible: !dockPage.dockBlurInherit
                    width: parent.width
                    height: 48
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "◌"; tint: "#5ac8fa" }
                        Text {
                            text: "Dock 模糊强度"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: dockPage.percentage(dockPage.dockBlurStrength)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                        }
                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 190
                            value: dockPage.dockBlurStrength
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                dockPage.previewDockBlur(position)
                            }
                            onCommitRequested: dockPage.commitDockBlur()
                        }
                    }
                }

                Rectangle {
                    visible: !dockPage.dockBlurInherit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    visible: !dockPage.dockBlurInherit
                    width: parent.width
                    height: 48
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "≈"; tint: "#af52de" }
                        Text {
                            text: "Dock 液态强度"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: dockPage.percentage(dockPage.dockLiquidStrength)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                        }
                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 190
                            value: dockPage.dockLiquidStrength
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                dockPage.previewDockLiquid(position)
                            }
                            onCommitRequested: dockPage.commitDockLiquid()
                        }
                    }
                }
            }
        }
    }

    component IconAppearanceSection: ColumnLayout {
        id: iconAppearance

        Layout.fillWidth: true
        spacing: 7
        property var bridge: (typeof settingsBridge !== "undefined")
            ? settingsBridge : null
        property int modeIndex: 0
        readonly property var modes: ["color", "grayscale", "tint"]
        property real iconOpacity: 0.5
        property string tintColor: "#a855f7"
        property real huePosition: 0.75
        property real tonePosition: 0.5
        property bool opacityDirty: false
        readonly property color pureHue: Qt.hsva(huePosition, 1, 1, 1)
        readonly property color selectedColor: toneColor(tonePosition)
        readonly property var presets: [
            { label: "紫色", color: "#a855f7" },
            { label: "红色", color: "#ef4444" },
            { label: "蓝色", color: "#3b82f6" },
            { label: "橙色", color: "#f97316" }
        ]
        readonly property var hueRamp: [
            Qt.hsva(0 / 6, 1, 1, 1), Qt.hsva(1 / 6, 1, 1, 1),
            Qt.hsva(2 / 6, 1, 1, 1), Qt.hsva(3 / 6, 1, 1, 1),
            Qt.hsva(4 / 6, 1, 1, 1), Qt.hsva(5 / 6, 1, 1, 1),
            Qt.hsva(6 / 6, 1, 1, 1)
        ]
        readonly property var toneRamp: [
            Qt.rgba(1, 1, 1, 1), blend(Qt.rgba(1, 1, 1, 1), pureHue, 1 / 3),
            blend(Qt.rgba(1, 1, 1, 1), pureHue, 2 / 3), pureHue,
            blend(pureHue, Qt.rgba(0, 0, 0, 1), 1 / 3),
            blend(pureHue, Qt.rgba(0, 0, 0, 1), 2 / 3), Qt.rgba(0, 0, 0, 1)
        ]

        function blend(first, second, amount) {
            return Qt.rgba(first.r + (second.r - first.r) * amount,
                first.g + (second.g - first.g) * amount,
                first.b + (second.b - first.b) * amount, 1)
        }
        function toneColor(position) {
            return position <= 0.5
                ? blend(Qt.rgba(1, 1, 1, 1), pureHue, position * 2)
                : blend(pureHue, Qt.rgba(0, 0, 0, 1), (position - 0.5) * 2)
        }
        function colorHex(color) {
            function channel(value) { return Math.round(value * 255).toString(16).padStart(2, "0") }
            return "#" + channel(color.r) + channel(color.g) + channel(color.b)
        }
        function colorFromHex(value) {
            const hex = String(value).replace("#", "")
            return hex.length === 6 ? Qt.rgba(parseInt(hex.slice(0, 2), 16) / 255,
                parseInt(hex.slice(2, 4), 16) / 255, parseInt(hex.slice(4, 6), 16) / 255, 1)
                : Qt.rgba(0.66, 0.33, 0.97, 1)
        }
        function hueFor(color) {
            const max = Math.max(color.r, color.g, color.b)
            const min = Math.min(color.r, color.g, color.b)
            const delta = max - min
            if (delta < 0.0001) return huePosition
            let hue = max === color.r ? (color.g - color.b) / delta
                : (max === color.g ? (color.b - color.r) / delta + 2
                    : (color.r - color.g) / delta + 4)
            return ((hue / 6) + 1) % 1
        }
        function nearestTone(color) {
            let best = 0.5
            let distance = Number.MAX_VALUE
            for (let step = 0; step <= 100; ++step) {
                const candidate = toneColor(step / 100)
                const delta = Math.pow(candidate.r - color.r, 2)
                    + Math.pow(candidate.g - color.g, 2) + Math.pow(candidate.b - color.b, 2)
                if (delta < distance) { distance = delta; best = step / 100 }
            }
            return best
        }
        function applyState(state) {
            if (!state) return
            const index = modes.indexOf(state.iconMode)
            modeIndex = index >= 0 ? index : 0
            iconOpacity = Number.isFinite(Number(state.iconOpacity)) ? Number(state.iconOpacity) : 0.5
            tintColor = String(state.iconTintColor || "#a855f7").toLowerCase()
            const color = colorFromHex(tintColor)
            huePosition = hueFor(color)
            tonePosition = nearestTone(color)
            opacityDirty = false
        }
        function refresh() { if (bridge) applyState(bridge.appearanceSnapshot()) }
        function saveMode(index) { if (bridge) applyState(bridge.updateGlobalIconMode(modes[index])) }
        function saveTint(color) { if (bridge) applyState(bridge.updateGlobalIconTintColor(color)) }
        function commitOpacity() {
            if (!opacityDirty || !bridge) return
            opacityDirty = false
            applyState(bridge.updateGlobalIconOpacity(iconOpacity))
        }
        Component.onCompleted: refresh()

        Text {
            text: "图标外观".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 10
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: appearanceRows.implicitHeight
            radius: 18
            color: theme.card
            Column {
                id: appearanceRows
                anchors.left: parent.left
                anchors.right: parent.right
                Item {
                    width: parent.width; height: 52
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                        SettingIcon { symbol: "◐"; tint: "#af52de" }
                        Text { text: "图标颜色"; color: theme.primaryText; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            model: [{ id: "color", label: "彩色" }, { id: "grayscale", label: "黑白" }, { id: "tint", label: "染色" }]
                            currentIndex: iconAppearance.modeIndex
                            onSelectionChanged: function(index) { iconAppearance.saveMode(index) }
                        }
                    }
                }
                Rectangle { width: parent.width - 53; x: 53; height: 1; color: theme.separator; visible: iconAppearance.modeIndex > 0 }
                Item {
                    width: parent.width; height: iconAppearance.modeIndex > 0 ? 48 : 0; visible: height > 0
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12
                        SettingIcon { symbol: "◔"; tint: "#5ac8fa" }
                        Text { text: "不透明度"; color: theme.primaryText; font.pixelSize: 14 }
                        Item { Layout.fillWidth: true }
                        Text { text: Math.round(iconAppearance.iconOpacity * 100) + "%"; color: theme.secondaryText; font.pixelSize: 12 }
                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 190; value: iconAppearance.iconOpacity; trackColor: theme.divider
                            onPreviewChanged: function(position) { iconAppearance.iconOpacity = Math.max(0.1, position); iconAppearance.opacityDirty = true }
                            onCommitRequested: iconAppearance.commitOpacity()
                        }
                    }
                }
                Rectangle { width: parent.width - 53; x: 53; height: 1; color: theme.separator; visible: iconAppearance.modeIndex === 2 }
                Item {
                    width: parent.width; height: iconAppearance.modeIndex === 2 ? 55 : 0; visible: height > 0
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 10
                        SettingIcon { symbol: "●"; tint: iconAppearance.tintColor }
                        Text { text: "颜色"; color: theme.primaryText; font.pixelSize: 14 }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            model: iconAppearance.presets
                            currentIndex: 0
                            onSelectionChanged: function(index) { iconAppearance.saveTint(iconAppearance.presets[index].color) }
                        }
                    }
                }
                Item {
                    width: parent.width; height: iconAppearance.modeIndex === 2 ? 48 : 0; visible: height > 0
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        Text { text: "自定义"; color: theme.secondaryText; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        LiquidControls.ColorRampSlider {
                            Layout.preferredWidth: 190; value: iconAppearance.huePosition; rampColors: iconAppearance.hueRamp; thumbColor: iconAppearance.pureHue
                            onPreviewChanged: function(position) { iconAppearance.huePosition = position }
                            onCommitRequested: function(position) {
                                iconAppearance.huePosition = position
                                iconAppearance.saveTint(iconAppearance.colorHex(iconAppearance.selectedColor))
                            }
                        }
                    }
                }
                Item {
                    width: parent.width; height: iconAppearance.modeIndex === 2 ? 48 : 0; visible: height > 0
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                        Text { text: "明暗"; color: theme.secondaryText; font.pixelSize: 13 }
                        Item { Layout.fillWidth: true }
                        LiquidControls.ColorRampSlider {
                            Layout.preferredWidth: 190; value: iconAppearance.tonePosition; rampColors: iconAppearance.toneRamp; thumbColor: iconAppearance.selectedColor
                            onPreviewChanged: function(position) { iconAppearance.tonePosition = position }
                            onCommitRequested: function(position) {
                                iconAppearance.tonePosition = position
                                iconAppearance.saveTint(iconAppearance.colorHex(iconAppearance.selectedColor))
                            }
                        }
                    }
                }
            }
        }
    }

    component ThemeSettingsPage: ColumnLayout {
        id: themePage

        Layout.fillWidth: true
        spacing: 10

        property var bridge: (typeof settingsBridge !== "undefined")
            ? settingsBridge : null
        property string shellStyle: "macos"
        property string materialStyle: "liquid"
        property real blurStrength: 0.42
        property real liquidStrength: 1.0
        property bool blurDirty: false
        property bool liquidDirty: false
        property string dockWindowAnimationStyle: "scale"
        property string errorText: ""
        property string tuningErrorText: ""
        // 材质微调（柔光玻璃 / 轻透磨砂）——只在对应材质下写入生效
        property real bionicRefract: 4.0
        property real bionicEdgeLight: 1.4
        property real bionicSoftEdgePx: 1.5
        property real bionicHsvv: 1.0
        property real classicRefract: 1.5
        property real classicReflect: 0.06
        property real classicEdgeLight: 0.1
        property real classicSoftEdgePx: 1.5
        property real bionicTransparency: 1.0
        property real bionicRefractMin: 1.0
        property real bionicRefractMax: 5.0
        property real bionicEdgeLightMin: 0.0
        property real bionicEdgeLightMax: 3.0
        property real bionicSoftEdgePxMin: 0.1
        property real bionicSoftEdgePxMax: 25.0
        property real bionicHsvvMin: 0.0
        property real bionicHsvvMax: 2.0
        property real bionicTransparencyMin: 0.0
        property real bionicTransparencyMax: 1.0
        property real classicRefractMin: 1.0
        property real classicRefractMax: 2.0
        property real classicReflectMin: 0.0
        property real classicReflectMax: 1.5
        property real classicEdgeLightMin: 0.0
        property real classicEdgeLightMax: 0.5
        property real classicSoftEdgePxMin: 0.5
        property real classicSoftEdgePxMax: 25.0
        property real bionicRefractPreview: -1
        property real bionicEdgeLightPreview: -1
        property real bionicSoftEdgePxPreview: -1
        property real bionicHsvvPreview: -1
        property real bionicTransparencyPreview: -1
        property real classicRefractPreview: -1
        property real classicReflectPreview: -1
        property real classicEdgeLightPreview: -1
        property real classicSoftEdgePxPreview: -1
        readonly property var styles: [
            {
                id: "windows12",
                name: "Windows 12",
                description: "居中任务栏、轻亚克力表面与紧凑圆角组件",
                accent: "#3b82f6"
            },
            {
                id: "macos",
                name: "macOS",
                description: "悬浮 Dock、通透顶部栏与更柔和的大圆角组件",
                accent: "#0a84ff"
            },
            {
                id: "material",
                name: "Material Design",
                description: "Tonal 表面、状态指示和标准化层级与动效",
                accent: "#6750a4"
            }
        ]

        function isValidStyle(style) {
            return style === "windows12" || style === "macos"
                || style === "material"
        }

        function isValidDockWindowAnimationStyle(style) {
            return style === "scale" || style === "genie"
        }

        function applyState(state) {
            if (!state || !isValidStyle(state.shellStyle))
                return
            shellStyle = state.shellStyle
            if (state.materialStyle === "liquid" || state.materialStyle === "bionic"
                    || state.materialStyle === "classic")
                materialStyle = state.materialStyle
            if (isValidDockWindowAnimationStyle(state.dockWindowAnimationStyle))
                dockWindowAnimationStyle = state.dockWindowAnimationStyle
            if (isFinite(state.globalBlurStrength))
                blurStrength = Math.max(0, Math.min(1, Number(state.globalBlurStrength)))
            if (isFinite(state.globalLiquidStrength))
                liquidStrength = Math.max(0, Math.min(1, Number(state.globalLiquidStrength)))
            // 材质微调字段
            if (isFinite(state.bionicRefract)) bionicRefract = state.bionicRefract
            if (isFinite(state.bionicEdgeLight)) bionicEdgeLight = state.bionicEdgeLight
            if (isFinite(state.bionicSoftEdgePx)) bionicSoftEdgePx = state.bionicSoftEdgePx
            if (isFinite(state.bionicHsvv)) bionicHsvv = state.bionicHsvv
            if (isFinite(state.bionicTransparency)) bionicTransparency = state.bionicTransparency
            if (isFinite(state.bionicTransparencyMin)) bionicTransparencyMin = state.bionicTransparencyMin
            if (isFinite(state.bionicTransparencyMax)) bionicTransparencyMax = state.bionicTransparencyMax
            if (isFinite(state.classicRefract)) classicRefract = state.classicRefract
            if (isFinite(state.classicReflect)) classicReflect = state.classicReflect
            if (isFinite(state.classicEdgeLight)) classicEdgeLight = state.classicEdgeLight
            if (isFinite(state.classicSoftEdgePx)) classicSoftEdgePx = state.classicSoftEdgePx
            if (isFinite(state.bionicRefractMin)) bionicRefractMin = state.bionicRefractMin
            if (isFinite(state.bionicRefractMax)) bionicRefractMax = state.bionicRefractMax
            if (isFinite(state.bionicEdgeLightMin)) bionicEdgeLightMin = state.bionicEdgeLightMin
            if (isFinite(state.bionicEdgeLightMax)) bionicEdgeLightMax = state.bionicEdgeLightMax
            if (isFinite(state.bionicSoftEdgePxMin)) bionicSoftEdgePxMin = state.bionicSoftEdgePxMin
            if (isFinite(state.bionicSoftEdgePxMax)) bionicSoftEdgePxMax = state.bionicSoftEdgePxMax
            if (isFinite(state.bionicHsvvMin)) bionicHsvvMin = state.bionicHsvvMin
            if (isFinite(state.bionicHsvvMax)) bionicHsvvMax = state.bionicHsvvMax
            if (isFinite(state.classicRefractMin)) classicRefractMin = state.classicRefractMin
            if (isFinite(state.classicRefractMax)) classicRefractMax = state.classicRefractMax
            if (isFinite(state.classicReflectMin)) classicReflectMin = state.classicReflectMin
            if (isFinite(state.classicReflectMax)) classicReflectMax = state.classicReflectMax
            if (isFinite(state.classicEdgeLightMin)) classicEdgeLightMin = state.classicEdgeLightMin
            if (isFinite(state.classicEdgeLightMax)) classicEdgeLightMax = state.classicEdgeLightMax
            if (isFinite(state.classicSoftEdgePxMin)) classicSoftEdgePxMin = state.classicSoftEdgePxMin
            if (isFinite(state.classicSoftEdgePxMax)) classicSoftEdgePxMax = state.classicSoftEdgePxMax
            errorText = ""
        }


        function applyTuningState(state) {
            if (!state || !isFinite(state.bionicRefract)) {
                tuningErrorText = bridge ? "外观设置返回的数据不完整" : ""
                return
            }
            // Reuse the one parser so the two groups can never drift apart.
            applyState(state)
            tuningErrorText = ""
        }


        Timer {
            id: liveBlurDebounce
            interval: 60
            repeat: false
            onTriggered: {
                if (themePage.bridge && themePage.blurDirty) {
                    themePage.bridge.updateGlobalBlurStrength(themePage.blurStrength)
                }
            }
        }

        Timer {
            id: liveLiquidDebounce
            interval: 60
            repeat: false
            onTriggered: {
                if (themePage.bridge && themePage.liquidDirty) {
                    themePage.bridge.updateGlobalLiquidStrength(themePage.liquidStrength)
                }
            }
        }

        function previewBlur(value) {
            const clamped = Math.max(0, Math.min(1, value))
            if (Math.abs(blurStrength - clamped) < 0.005)
                return
            blurStrength = clamped
            blurDirty = true
            liveBlurDebounce.restart()
        }

        function commitBlur() {
            liveBlurDebounce.stop()
            if (!blurDirty || !bridge)
                return
            blurDirty = false
            applyState(bridge.updateGlobalBlurStrength(blurStrength))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function previewLiquid(value) {
            const clamped = Math.max(0, Math.min(1, value))
            if (Math.abs(liquidStrength - clamped) < 0.005)
                return
            liquidStrength = clamped
            liquidDirty = true
            liveLiquidDebounce.restart()
        }

        function commitLiquid() {
            liveLiquidDebounce.stop()
            if (!liquidDirty || !bridge)
                return
            liquidDirty = false
            applyState(bridge.updateGlobalLiquidStrength(liquidStrength))
            if (bridge.lastError)
                errorText = bridge.lastError
        }


        function setSystemAppearance(index) {
            if (!bridge) {
                errorText = "尚未构建 Settings 桥接程序"
                return
            }
            if (!bridge.applySystemAppearance(index === 1)) {
                errorText = bridge.lastError
                return
            }
            errorText = ""
        }


        function setMaterialStyle(style) {
            if (!bridge || (style !== "liquid" && style !== "bionic" && style !== "classic")) {
                errorText = bridge ? "未知的材质风格" : "尚未构建 Settings 桥接程序"
                return
            }
            // 立即本地更新（橙色框即时反馈），随后与 Shell 回传对齐
            materialStyle = style
            applyState(bridge.updateMaterialStyle(style))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function setBionicRefract(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            bionicRefract = value
            applyTuningState(bridge.updateBionicRefract(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setBionicEdgeLight(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            bionicEdgeLight = value
            applyTuningState(bridge.updateBionicEdgeLight(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setBionicSoftEdgePx(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            bionicSoftEdgePx = value
            applyTuningState(bridge.updateBionicSoftEdgePx(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setBionicHsvv(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            bionicHsvv = value
            applyTuningState(bridge.updateBionicHsvv(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setClassicRefract(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            classicRefract = value
            applyTuningState(bridge.updateClassicRefract(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setClassicReflect(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            classicReflect = value
            applyTuningState(bridge.updateClassicReflect(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setClassicEdgeLight(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            classicEdgeLight = value
            applyTuningState(bridge.updateClassicEdgeLight(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setClassicSoftEdgePx(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            classicSoftEdgePx = value
            applyTuningState(bridge.updateClassicSoftEdgePx(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function setBionicTransparency(value) {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            bionicTransparency = value
            applyTuningState(bridge.updateBionicTransparency(value))
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }

        function resetMaterialTuning() {
            if (!bridge) {
                tuningErrorText = "尚未构建 Settings 桥接程序"
                return
            }
            applyTuningState(bridge.resetMaterialTuning())
            if (bridge.lastError)
                tuningErrorText = bridge.lastError
        }


        function refresh() {
            if (!bridge) {
                errorText = "尚未构建 Settings 桥接程序"
                return
            }
            applyState(bridge.appearanceSnapshot())
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function selectStyle(style) {
            if (!bridge || !isValidStyle(style)) {
                errorText = bridge ? "未知的主题形态" : "尚未构建 Settings 桥接程序"
                return
            }
            applyState(bridge.updateShellStyle(style))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function setDockWindowAnimationStyle(style) {
            if (!bridge || !isValidDockWindowAnimationStyle(style)) {
                errorText = bridge ? "未知的窗口动画" : "尚未构建 Settings 桥接程序"
                return
            }
            applyState(bridge.updateDockWindowAnimationStyle(style))
            if (bridge.lastError)
                errorText = bridge.lastError
        }
        Component.onCompleted: refresh()

        Text {
            text: "系统外观".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 54
            radius: 18
            color: theme.card

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                SettingIcon { symbol: "◐"; tint: "#5ac8fa" }
                Text {
                    text: "色彩模式"
                    color: theme.primaryText
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                SettingsNavBar {
                    id: systemAppearanceNavBar
                    model: [
                        { id: "light", label: "明亮" },
                        { id: "dark", label: "暗色" }
                    ]
                    currentIndex: theme.dark ? 1 : 0
                    onSelectionChanged: function(index) {
                        themePage.setSystemAppearance(index)
                    }
                }
            }
        }


        IconAppearanceSection {
            bridge: themePage.bridge
        }


        Text {
            text: "界面形态".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
        }

        Repeater {
            model: themePage.styles

            delegate: Rectangle {
                id: styleCard
                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 148
                radius: 22
                color: theme.card
                border.width: themePage.shellStyle === modelData.id ? 2 : 1
                border.color: themePage.shellStyle === modelData.id
                    ? modelData.accent : theme.floatingBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 16

                    Rectangle {
                        Layout.preferredWidth: 156
                        Layout.fillHeight: true
                        radius: 14
                        color: theme.previewPane
                        clip: true

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 14
                            color: theme.previewBar
                            visible: styleCard.modelData.id !== "windows12"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 14
                                height: 4
                                radius: 2
                                color: styleCard.modelData.accent
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: styleCard.modelData.id === "macos" ? 8 : 0
                            width: styleCard.modelData.id === "windows12"
                                ? parent.width : (styleCard.modelData.id === "macos" ? 112 : 92)
                            height: styleCard.modelData.id === "windows12" ? 18 : 16
                            radius: styleCard.modelData.id === "windows12"
                                ? 0 : (styleCard.modelData.id === "macos" ? 8 : 4)
                            color: styleCard.modelData.id === "windows12"
                                ? theme.previewTaskbar : theme.previewDock

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                Repeater {
                                    model: 4
                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: styleCard.modelData.id === "macos" ? 4 : 2
                                        color: index === 0
                                            ? styleCard.modelData.accent : theme.previewIcon
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: styleCard.modelData.name
                                color: theme.primaryText
                                font.pixelSize: 17
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                visible: themePage.shellStyle === styleCard.modelData.id
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 20
                                radius: 10
                                color: Qt.rgba(0.04, 0.52, 1, 0.16)

                                Text {
                                    anchors.centerIn: parent
                                    text: "当前"
                                    color: styleCard.modelData.accent
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: styleCard.modelData.description
                            color: theme.secondaryText
                            font.pixelSize: 13
                            wrapMode: Text.Wrap
                        }

                        Item { Layout.fillHeight: true }

                        Text {
                            text: themePage.shellStyle === styleCard.modelData.id
                                ? "已应用到桌面" : "点击切换此形态"
                            color: themePage.shellStyle === styleCard.modelData.id
                                ? styleCard.modelData.accent : theme.tertiaryText
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: themePage.selectStyle(styleCard.modelData.id)
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            text: "选择界面形态会立即切换桌面组件的圆角、间距与表面质感规范。"
            color: theme.secondaryText
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        // ── 材质风格（柔光玻璃 / 轻透磨砂 · 对标澎湃材质风格）──
        Text {
            text: "材质风格".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 8
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: [
                    { id: "liquid", name: "液态玻璃", desc: "KOS 经典玻璃效果" },
                    { id: "bionic", name: "柔光玻璃", desc: "更高通透，光影流动" },
                    { id: "classic", name: "轻透磨砂", desc: "经典磨砂，沉稳内敛" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: 92
                    radius: 18
                    color: theme.card
                    border.width: themePage.materialStyle === modelData.id ? 2 : 1
                    border.color: themePage.materialStyle === modelData.id
                        ? "#ff6900" : theme.floatingBorder

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.name
                            color: theme.primaryText
                            font.pixelSize: 15
                            font.weight: Font.Bold
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: modelData.desc
                            color: theme.secondaryText
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: themePage.setMaterialStyle(modelData.id)
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            Layout.topMargin: 8
            text: themePage.materialStyle === "bionic" ? "柔光玻璃微调"
                : themePage.materialStyle === "classic" ? "轻透磨砂微调"
                : themePage.materialStyle === "liquid" ? "液态玻璃微调"
                : "材质微调"
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }

        // ════════════════════════════════════════════════════════════

        Rectangle {
            id: materialTuningCard
            Layout.fillWidth: true
            implicitHeight: materialTuningColumn.implicitHeight + 32
            radius: 18
            color: theme.card
            visible: themePage.materialStyle === "bionic" || themePage.materialStyle === "classic" || themePage.materialStyle === "liquid"

            ColumnLayout {
                id: materialTuningColumn
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    visible: themePage.materialStyle === "liquid"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◌"; tint: "#5ac8fa" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "模糊强度"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "液态玻璃背景的模糊程度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Math.round(themePage.blurStrength * 100) + "%"
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: themePage.blurStrength
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.previewBlur(position)
                            }
                            onCommitRequested: themePage.commitBlur()
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◍"; tint: "#5ac8fa" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "液态强度"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "液态玻璃的流动感强度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Math.round(themePage.liquidStrength * 100) + "%"
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: themePage.liquidStrength
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.previewLiquid(position)
                            }
                            onCommitRequested: themePage.commitLiquid()
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    visible: themePage.materialStyle === "bionic"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◈"; tint: "#af52de" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "折射强度"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "玻璃边缘的光线弯折程度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Number(themePage.bionicRefractPreview >= 0 ? themePage.bionicRefractPreview : themePage.bionicRefract).toFixed(2)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.bionicRefractPreview >= 0
                                    ? themePage.bionicRefractPreview : themePage.bionicRefract
                                return themePage.bionicRefractMax <= themePage.bionicRefractMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.bionicRefractMin)
                                        / (themePage.bionicRefractMax - themePage.bionicRefractMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.bionicRefractPreview = themePage.bionicRefractMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.bionicRefractMax - themePage.bionicRefractMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.bionicRefractMin
                                    + clamped * (themePage.bionicRefractMax - themePage.bionicRefractMin)
                                themePage.bionicRefractPreview = -1
                                themePage.setBionicRefract(v)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◉"; tint: "#ff9500" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "边缘光"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "鼠标靠近时点亮的边缘光强度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Number(themePage.bionicEdgeLightPreview >= 0 ? themePage.bionicEdgeLightPreview : themePage.bionicEdgeLight).toFixed(2)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.bionicEdgeLightPreview >= 0
                                    ? themePage.bionicEdgeLightPreview : themePage.bionicEdgeLight
                                return themePage.bionicEdgeLightMax <= themePage.bionicEdgeLightMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.bionicEdgeLightMin)
                                        / (themePage.bionicEdgeLightMax - themePage.bionicEdgeLightMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.bionicEdgeLightPreview = themePage.bionicEdgeLightMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.bionicEdgeLightMax - themePage.bionicEdgeLightMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.bionicEdgeLightMin
                                    + clamped * (themePage.bionicEdgeLightMax - themePage.bionicEdgeLightMin)
                                themePage.bionicEdgeLightPreview = -1
                                themePage.setBionicEdgeLight(v)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "☀"; tint: "#ffcc00" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "柔光强度"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "柔光提亮的强度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Number(themePage.bionicHsvvPreview >= 0 ? themePage.bionicHsvvPreview : themePage.bionicHsvv).toFixed(2)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.bionicHsvvPreview >= 0
                                    ? themePage.bionicHsvvPreview : themePage.bionicHsvv
                                return themePage.bionicHsvvMax <= themePage.bionicHsvvMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.bionicHsvvMin)
                                        / (themePage.bionicHsvvMax - themePage.bionicHsvvMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.bionicHsvvPreview = themePage.bionicHsvvMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.bionicHsvvMax - themePage.bionicHsvvMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.bionicHsvvMin
                                    + clamped * (themePage.bionicHsvvMax - themePage.bionicHsvvMin)
                                themePage.bionicHsvvPreview = -1
                                themePage.setBionicHsvv(v)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◭"; tint: "#5ac8fa" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "边缘软边"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "玻璃边缘的柔和过渡宽度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Math.round((themePage.bionicSoftEdgePxPreview >= 0 ? themePage.bionicSoftEdgePxPreview : themePage.bionicSoftEdgePx) * 10) / 10 + " px"
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.bionicSoftEdgePxPreview >= 0
                                    ? themePage.bionicSoftEdgePxPreview : themePage.bionicSoftEdgePx
                                return themePage.bionicSoftEdgePxMax <= themePage.bionicSoftEdgePxMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.bionicSoftEdgePxMin)
                                        / (themePage.bionicSoftEdgePxMax - themePage.bionicSoftEdgePxMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.bionicSoftEdgePxPreview = themePage.bionicSoftEdgePxMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.bionicSoftEdgePxMax - themePage.bionicSoftEdgePxMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.bionicSoftEdgePxMin
                                    + clamped * (themePage.bionicSoftEdgePxMax - themePage.bionicSoftEdgePxMin)
                                themePage.bionicSoftEdgePxPreview = -1
                                themePage.setBionicSoftEdgePx(v)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◐"; tint: "#ff375f" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "透明度"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "玻璃整体的透明程度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Number(themePage.bionicTransparencyPreview >= 0
                                ? themePage.bionicTransparencyPreview
                                : themePage.bionicTransparency).toFixed(2)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.bionicTransparencyPreview >= 0
                                    ? themePage.bionicTransparencyPreview : themePage.bionicTransparency
                                return themePage.bionicTransparencyMax <= themePage.bionicTransparencyMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.bionicTransparencyMin)
                                        / (themePage.bionicTransparencyMax - themePage.bionicTransparencyMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.bionicTransparencyPreview = themePage.bionicTransparencyMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.bionicTransparencyMax - themePage.bionicTransparencyMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.bionicTransparencyMin
                                    + clamped * (themePage.bionicTransparencyMax - themePage.bionicTransparencyMin)
                                themePage.bionicTransparencyPreview = -1
                                themePage.setBionicTransparency(v)
                            }
                        }
                    }

                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 14
                    visible: themePage.materialStyle === "classic"
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◈"; tint: "#af52de" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "折射强度"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "玻璃边缘的透镜折射"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Number(themePage.classicRefractPreview >= 0 ? themePage.classicRefractPreview : themePage.classicRefract).toFixed(2)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.classicRefractPreview >= 0
                                    ? themePage.classicRefractPreview : themePage.classicRefract
                                return themePage.classicRefractMax <= themePage.classicRefractMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.classicRefractMin)
                                        / (themePage.classicRefractMax - themePage.classicRefractMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.classicRefractPreview = themePage.classicRefractMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.classicRefractMax - themePage.classicRefractMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.classicRefractMin
                                    + clamped * (themePage.classicRefractMax - themePage.classicRefractMin)
                                themePage.classicRefractPreview = -1
                                themePage.setClassicRefract(v)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◍"; tint: "#5e5ce6" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "反射强度"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "边缘反射的提亮强度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Number(themePage.classicReflectPreview >= 0 ? themePage.classicReflectPreview : themePage.classicReflect).toFixed(2)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.classicReflectPreview >= 0
                                    ? themePage.classicReflectPreview : themePage.classicReflect
                                return themePage.classicReflectMax <= themePage.classicReflectMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.classicReflectMin)
                                        / (themePage.classicReflectMax - themePage.classicReflectMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.classicReflectPreview = themePage.classicReflectMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.classicReflectMax - themePage.classicReflectMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.classicReflectMin
                                    + clamped * (themePage.classicReflectMax - themePage.classicReflectMin)
                                themePage.classicReflectPreview = -1
                                themePage.setClassicReflect(v)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◉"; tint: "#ff9500" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "边缘光"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "玻璃描边的亮度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Number(themePage.classicEdgeLightPreview >= 0 ? themePage.classicEdgeLightPreview : themePage.classicEdgeLight).toFixed(2)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.classicEdgeLightPreview >= 0
                                    ? themePage.classicEdgeLightPreview : themePage.classicEdgeLight
                                return themePage.classicEdgeLightMax <= themePage.classicEdgeLightMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.classicEdgeLightMin)
                                        / (themePage.classicEdgeLightMax - themePage.classicEdgeLightMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.classicEdgeLightPreview = themePage.classicEdgeLightMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.classicEdgeLightMax - themePage.classicEdgeLightMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.classicEdgeLightMin
                                    + clamped * (themePage.classicEdgeLightMax - themePage.classicEdgeLightMin)
                                themePage.classicEdgeLightPreview = -1
                                themePage.setClassicEdgeLight(v)
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        SettingIcon { symbol: "◭"; tint: "#5ac8fa" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "边缘软边"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "玻璃边缘的柔和过渡宽度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: Math.round((themePage.classicSoftEdgePxPreview >= 0 ? themePage.classicSoftEdgePxPreview : themePage.classicSoftEdgePx) * 10) / 10 + " px"
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 56
                            horizontalAlignment: Text.AlignRight
                            Layout.alignment: Qt.AlignVCenter
                        }

                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 150
                            value: {
                                const shown = themePage.classicSoftEdgePxPreview >= 0
                                    ? themePage.classicSoftEdgePxPreview : themePage.classicSoftEdgePx
                                return themePage.classicSoftEdgePxMax <= themePage.classicSoftEdgePxMin
                                    ? 0
                                    : Math.max(0, Math.min(1,
                                        (shown - themePage.classicSoftEdgePxMin)
                                        / (themePage.classicSoftEdgePxMax - themePage.classicSoftEdgePxMin)))
                            }
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                themePage.classicSoftEdgePxPreview = themePage.classicSoftEdgePxMin
                                    + Math.max(0, Math.min(1, position))
                                        * (themePage.classicSoftEdgePxMax - themePage.classicSoftEdgePxMin)
                            }
                            onCommitRequested: function(position) {
                                const clamped = Math.max(0, Math.min(1, position))
                                const v = themePage.classicSoftEdgePxMin
                                    + clamped * (themePage.classicSoftEdgePxMax - themePage.classicSoftEdgePxMin)
                                themePage.classicSoftEdgePxPreview = -1
                                themePage.setClassicSoftEdgePx(v)
                            }
                        }
                    }

                }


                // 恢复默认 → OS4 原生值（柔光玻璃：1.2 / 1.4 / 1.0 / 1.5px；
                // 轻透磨砂：1.5 / 0.6 / 0.1 / 1.5px）
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "恢复默认"
                        color: theme.selected
                        font.pixelSize: 12
                        font.weight: Font.Medium

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: themePage.resetMaterialTuning()
                        }
                    }
                }
            }
        }


        Text {
            text: "窗口动画"
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 4
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 82
            radius: 18
            color: theme.card

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12
                SettingIcon { symbol: "◒"; tint: "#af52de" }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "窗口显示/隐藏"
                        color: theme.primaryText
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: themePage.dockWindowAnimationStyle === "genie"
                            ? "水滴形变缩入图标；打开窗口仍使用常规展开"
                            : "等比例缩放到图标；最小化与恢复均保持平直路径"
                        color: theme.secondaryText
                        font.pixelSize: 11
                    }
                }
                SettingsNavBar {
                    Layout.preferredWidth: 148
                    Layout.preferredHeight: 30
                    // LiquidNavBar delegates expect { id, label, icon }.
                    // A string model leaves modelData.label undefined, so the
                    // previous control had no visible text despite rendering
                    // its track and thumb.
                    size: "tiny"
                    barHeight: 30
                    itemWidthOverride: 74
                    model: [
                        { id: "scale", label: "缩放" },
                        { id: "genie", label: "水滴" }
                    ]
                    currentIndex: themePage.dockWindowAnimationStyle === "genie" ? 1 : 0
                    onSelectionChanged: function(index) {
                        themePage.setDockWindowAnimationStyle(
                            index === 1 ? "genie" : "scale")
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            text: "窗口动画会立即同步到 KWin；顶栏与 Dock 的布局在各自设置页中管理。"
            color: theme.secondaryText
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            visible: themePage.errorText.length > 0
            text: themePage.errorText
            color: "#ff453a"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }

    component BarSettingsPage: ColumnLayout {
        id: barPage

        Layout.fillWidth: true
        spacing: 10

        property var bridge: (typeof settingsBridge !== "undefined")
            ? settingsBridge : null
        property bool barIntegratedWithDock: false
        property int barVisibilityModeIndex: 0
        readonly property var barVisibilityModes: ["always", "smart", "persistent"]
        property int barLayoutModeIndex: 2
        readonly property var barLayoutModes: ["full", "floating", "transparent"]
        property bool barBlurInherit: true
        property real barBlurStrength: 0.42
        property real barLiquidStrength: 1.0
        property bool barBlurDirty: false
        property bool barLiquidDirty: false
        property string errorText: ""

        function percentage(value) {
            return Math.round(value * 100) + "%"
        }

        function barVisibilityModeIndexFromString(mode) {
            const idx = barVisibilityModes.indexOf(mode)
            return idx >= 0 ? idx : 0
        }

        function barLayoutModeIndexFromString(mode) {
            const idx = barLayoutModes.indexOf(mode)
            return idx >= 0 ? idx : 0
        }

        function applyState(state) {
            if (!state) return
            barIntegratedWithDock = Boolean(state.barIntegratedWithDock)
            barVisibilityModeIndex = barVisibilityModeIndexFromString(state.barVisibilityMode)
            barLayoutModeIndex = barLayoutModeIndexFromString(state.barLayoutMode)
            barBlurInherit = state.barBlurInherit !== undefined
                ? Boolean(state.barBlurInherit)
                : (state.barBlurInheritDock !== undefined ? Boolean(state.barBlurInheritDock) : true)
            barBlurStrength = Number.isFinite(Number(state.barBlurStrength)) ? Number(state.barBlurStrength) : 0.42
            barLiquidStrength = Number.isFinite(Number(state.barLiquidStrength)) ? Number(state.barLiquidStrength) : 1.0
            barBlurDirty = false
            barLiquidDirty = false
            errorText = ""
        }

        function refresh() {
            if (!bridge) {
                errorText = "尚未构建 Settings 桥接程序"
                return
            }
            applyState(bridge.appearanceSnapshot())
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function setBarIntegratedWithDock(enabled) {
            if (!bridge) {
                errorText = "尚未构建 Settings 桥接程序"
                return
            }
            applyState(bridge.updateBarIntegratedWithDock(enabled))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveBarVisibilityMode(index) {
            if (!bridge)
                return
            const mode = barVisibilityModes[index]
            applyState(bridge.updateBarVisibilityMode(mode))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveBarLayoutMode(index) {
            if (!bridge)
                return
            const mode = barLayoutModes[index]
            applyState(bridge.updateBarLayoutMode(mode))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function setBarBlurInherit(enabled) {
            if (!bridge) return
            applyState(bridge.updateBarBlurInherit(enabled))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        Timer {
            id: liveBarBlurDebounce
            interval: 60
            repeat: false
            onTriggered: {
                if (barPage.bridge && barPage.barBlurDirty) {
                    barPage.bridge.updateBarBlurStrength(barPage.barBlurStrength)
                }
            }
        }

        Timer {
            id: liveBarLiquidDebounce
            interval: 60
            repeat: false
            onTriggered: {
                if (barPage.bridge && barPage.barLiquidDirty) {
                    barPage.bridge.updateBarLiquidStrength(barPage.barLiquidStrength)
                }
            }
        }

        function previewBarBlur(value) {
            const clamped = Math.max(0, Math.min(1, value))
            if (Math.abs(barBlurStrength - clamped) < 0.005)
                return
            barBlurStrength = clamped
            barBlurDirty = true
            liveBarBlurDebounce.restart()
        }

        function commitBarBlur() {
            liveBarBlurDebounce.stop()
            if (!barBlurDirty || !bridge)
                return
            barBlurDirty = false
            applyState(bridge.updateBarBlurStrength(barBlurStrength))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function previewBarLiquid(value) {
            const clamped = Math.max(0, Math.min(1, value))
            if (Math.abs(barLiquidStrength - clamped) < 0.005)
                return
            barLiquidStrength = clamped
            barLiquidDirty = true
            liveBarLiquidDebounce.restart()
        }

        function commitBarLiquid() {
            liveBarLiquidDebounce.stop()
            if (!barLiquidDirty || !bridge)
                return
            barLiquidDirty = false
            applyState(bridge.updateBarLiquidStrength(barLiquidStrength))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        Component.onCompleted: refresh()

        Text {
            text: "显示与布局".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: barLayoutCol.implicitHeight
            radius: 18
            color: theme.card

            Column {
                id: barLayoutCol
                anchors.left: parent.left
                anchors.right: parent.right

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "⎍"; tint: "#5ac8fa" }
                        Text {
                            text: "顶栏形态"
                            color: theme.primaryText
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            id: barLayoutNavBar
                            model: [
                                { id: "full", label: "全宽贴边" },
                                { id: "floating", label: "悬浮胶囊" },
                                { id: "transparent", label: "全透明" }
                            ]
                            itemWidthOverride: 76
                            currentIndex: barPage.barLayoutModeIndex
                            onSelectionChanged: function(index) {
                                barPage.saveBarLayoutMode(index)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "◉"; tint: "#0a84ff" }
                        Text {
                            text: "Bar 显示方式"
                            color: theme.primaryText
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            id: barVisibilityNavBar
                            model: [
                                { id: "always", label: "始终显示" },
                                { id: "smart", label: "智能隐藏" },
                                { id: "persistent", label: "持续隐藏" }
                            ]
                            itemWidthOverride: 76
                            currentIndex: barPage.barVisibilityModeIndex
                            onSelectionChanged: function(index) {
                                barPage.saveBarVisibilityMode(index)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    width: parent.width
                    height: 64
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "⇲"; tint: "#ff9f0a" }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "Bar 融入 Dock"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "仅在 Dock 位于底部时生效；侧边 Dock 自动保留顶部 Bar"
                                color: theme.secondaryText
                                font.pixelSize: 11
                            }
                        }
                        LiquidControls.LiquidGlassSwitch {
                            checked: barPage.barIntegratedWithDock
                            accentColor: "#0a84ff"
                            trackColor: theme.divider
                            onToggled: function(checked) {
                                barPage.setBarIntegratedWithDock(checked)
                            }
                        }
                    }
                }
            }
        }

        Text {
            text: "外观与模糊效果".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 4
            visible: false
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: barBlurCol.implicitHeight
            visible: false
            radius: 18
            color: theme.card

            Column {
                id: barBlurCol
                anchors.left: parent.left
                anchors.right: parent.right

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "⎘"; tint: "#30d158" }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "跟随显示设置"
                                color: theme.primaryText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: "关闭后可为顶栏及控制中心单独自定义背景模糊与液态强度"
                                color: theme.secondaryText
                                font.pixelSize: 11
                            }
                        }
                        LiquidControls.LiquidGlassSwitch {
                            checked: barPage.barBlurInherit
                            accentColor: "#30d158"
                            trackColor: theme.divider
                            onToggled: function(checked) {
                                barPage.setBarBlurInherit(checked)
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !barPage.barBlurInherit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    visible: !barPage.barBlurInherit
                    width: parent.width
                    height: 48
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "◌"; tint: "#5ac8fa" }
                        Text {
                            text: "顶栏模糊强度"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: barPage.percentage(barPage.barBlurStrength)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                        }
                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 190
                            value: barPage.barBlurStrength
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                barPage.previewBarBlur(position)
                            }
                            onCommitRequested: barPage.commitBarBlur()
                        }
                    }
                }

                Rectangle {
                    visible: !barPage.barBlurInherit
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    visible: !barPage.barBlurInherit
                    width: parent.width
                    height: 48
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "≈"; tint: "#af52de" }
                        Text {
                            text: "顶栏液态强度"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: barPage.percentage(barPage.barLiquidStrength)
                            color: theme.secondaryText
                            font.pixelSize: 12
                            Layout.preferredWidth: 38
                            horizontalAlignment: Text.AlignRight
                        }
                        LiquidControls.LiquidSlider {
                            Layout.preferredWidth: 190
                            value: barPage.barLiquidStrength
                            trackColor: theme.divider
                            onPreviewChanged: function(position) {
                                barPage.previewBarLiquid(position)
                            }
                            onCommitRequested: barPage.commitBarLiquid()
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            text: "Bar 保持通透液态外观，可在上方选择跟随 Dock 模糊基准或在此独立定制。"
            visible: false
            color: theme.secondaryText
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            visible: barPage.errorText.length > 0
            text: barPage.errorText
            color: "#ff453a"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }

    component ShortcutsSettingsPage: ColumnLayout {
        id: shortcutsPage

        Layout.fillWidth: true
        spacing: 7
        property var bridge: (typeof settingsBridge !== "undefined") ? settingsBridge : null
        property var shortcuts: []
        property string errorText: ""
        readonly property var rowIcons: ({
            "net.local.kos-launcher": { symbol: "❖", tint: "#ff9500" },
            "net.local.kos-window-switcher": { symbol: "⌕", tint: "#0a84ff" },
            "net.local.kos-control-center": { symbol: "≋", tint: "#5ac8fa" },
            "net.local.kos-overview": { symbol: "▦", tint: "#af52de" },
            "net.local.kos-clipboard": { symbol: "⧉", tint: "#34c759" },
            "net.local.kos-show-desktop": { symbol: "⌂", tint: "#ff375f" },
        })

        function applyState(state) {
            if (!state) return
            // A QVariantList nested in the bridge's QVariantMap arrives as an
            // array-LIKE object (has .length) but Array.isArray() is false,
            // so the list must be copied into a real JS array here or the
            // Repeater silently renders nothing.
            const raw = state.shortcuts
            shortcuts = Array.isArray(raw) ? raw
                : (raw && raw.length !== undefined
                    ? Array.prototype.slice.call(raw) : [])
            errorText = state.error || ""
        }

        function refresh() {
            if (!bridge) {
                errorText = "尚未构建 Settings 桥接程序"
                return
            }
            applyState(bridge.shortcutsSnapshot())
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveBinding(id, combo) {
            if (!bridge)
                return
            applyState(bridge.updateShortcut(id, combo))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function resetBinding(id) {
            if (!bridge)
                return
            applyState(bridge.resetShortcut(id))
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        // Maps a raw key event to its kglobalaccel PortableText name.
        // Returns "" for lone modifier presses so recording keeps waiting.
        function keyDisplayName(event) {
            if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
                return String.fromCharCode(event.key)
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
                return String.fromCharCode(event.key)
            if (event.key >= Qt.Key_F1 && event.key <= Qt.Key_F24)
                return "F" + (event.key - Qt.Key_F1 + 1)
            switch (event.key) {
                case Qt.Key_Space: return "Space"
                case Qt.Key_Tab: return "Tab"
                case Qt.Key_Backspace: return "Backspace"
                case Qt.Key_Return: return "Return"
                case Qt.Key_Enter: return "Enter"
                case Qt.Key_Insert: return "Ins"
                case Qt.Key_Delete: return "Del"
                case Qt.Key_Home: return "Home"
                case Qt.Key_End: return "End"
                case Qt.Key_Left: return "Left"
                case Qt.Key_Up: return "Up"
                case Qt.Key_Right: return "Right"
                case Qt.Key_Down: return "Down"
                case Qt.Key_PageUp: return "PgUp"
                case Qt.Key_PageDown: return "PgDown"
                case Qt.Key_Print: return "Print"
                case Qt.Key_Pause: return "Pause"
            }
            const text = String(event.text || "")
            if (text.length === 1) {
                const upper = text.toUpperCase()
                const code = upper.charCodeAt(0)
                if (code >= 0x21 && code <= 0x7e)
                    return upper
            }
            return ""
        }

        Component.onCompleted: refresh()

        Text {
            text: "点击任一键位胶囊后按下新的组合键即可更换；Esc 取消。"
            color: theme.secondaryText
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
        }

        Rectangle {
            id: shortcutsCard
            Layout.fillWidth: true
            color: theme.card
            radius: 18
            implicitHeight: shortcutsColumn.implicitHeight

            Column {
                id: shortcutsColumn
                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                    model: shortcutsPage.shortcuts

                    delegate: Item {
                        id: shortcutRow

                        required property var modelData
                        required property int index
                        readonly property var iconInfo:
                            shortcutsPage.rowIcons[modelData.id]
                            || { symbol: "⌘", tint: "#8e8e93" }
                        readonly property string rowCombo: modelData.combo || ""

                        width: shortcutsColumn.width
                        height: 54

                        // Explicit anchoring: icon + title group left-aligned,
                        // combo pill right-aligned, everything vertically
                        // centered — no layout-engine ambiguity between rows.
                        SettingIcon {
                            id: rowIcon
                            x: 16
                            anchors.verticalCenter: parent.verticalCenter
                            symbol: shortcutRow.iconInfo.symbol
                            tint: shortcutRow.iconInfo.tint
                        }

                        ColumnLayout {
                            id: rowText
                            anchors.left: rowIcon.right
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: shortcutRow.modelData.description
                                color: theme.primaryText
                                font.pixelSize: 14
                            }
                            Text {
                                text: shortcutRow.modelData.custom
                                    ? "自定义快捷键" : "默认快捷键"
                                color: theme.secondaryText
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            id: resetLabel
                            anchors.right: comboPill.left
                            anchors.rightMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            visible: shortcutRow.modelData.custom
                            text: "恢复默认"
                            color: theme.dark ? "#64b5ff" : "#0066cc"
                            font.pixelSize: 11
                            font.weight: Font.DemiBold

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -8
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shortcutsPage.resetBinding(shortcutRow.modelData.id)
                            }
                        }

                        // Click to record: the pill grabs keyboard focus
                        // and shows a hint; the next full combo commits.
                        Rectangle {
                            id: comboPill

                            anchors.right: parent.right
                            anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            width: 158
                            height: 30
                            radius: 15
                            property bool recording: false
                            color: recording
                                ? Qt.rgba(0.04, 0.52, 1.0, 0.18)
                                : (theme.dark
                                    ? Qt.rgba(1, 1, 1, 0.09)
                                    : Qt.rgba(0, 0, 0, 0.055))
                            border.width: recording ? 2 : 1
                            border.color: recording
                                ? "#0a84ff" : theme.floatingBorder

                            Text {
                                anchors.centerIn: parent
                                text: comboPill.recording
                                    ? "按下新的组合键…"
                                    : (shortcutRow.rowCombo || "点击设置")
                                color: comboPill.recording
                                    ? (theme.dark ? "#64b5ff" : "#0066cc")
                                    : theme.primaryText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    comboPill.forceActiveFocus()
                                    comboPill.recording = true
                                }
                            }

                            Keys.onPressed: function(event) {
                                if (!comboPill.recording)
                                    return
                                event.accepted = true
                                if (event.key === Qt.Key_Escape) {
                                    comboPill.recording = false
                                    comboPill.focus = false
                                    return
                                }
                                const name = shortcutsPage.keyDisplayName(event)
                                if (name === "")
                                    return
                                const parts = []
                                if (event.modifiers & Qt.MetaModifier)
                                    parts.push("Meta")
                                if (event.modifiers & Qt.ControlModifier)
                                    parts.push("Ctrl")
                                if (event.modifiers & Qt.AltModifier)
                                    parts.push("Alt")
                                if (event.modifiers & Qt.ShiftModifier)
                                    parts.push("Shift")
                                parts.push(name)
                                comboPill.recording = false
                                comboPill.focus = false
                                shortcutsPage.saveBinding(
                                    shortcutRow.modelData.id, parts.join("+"))
                            }

                            onActiveFocusChanged: if (!activeFocus) recording = false
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 53
                            anchors.bottom: parent.bottom
                            height: 1
                            color: theme.separator
                            visible: index < shortcutsPage.shortcuts.length - 1
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            visible: shortcutsPage.errorText.length > 0
            text: shortcutsPage.errorText
            color: "#ff453a"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }

    component LauncherSettingsPage: ColumnLayout {
        id: launcherPage

        Layout.fillWidth: true
        spacing: 7
        property var bridge: (typeof settingsBridge !== "undefined") ? settingsBridge : null
        property string displayMode: "bottom"
        readonly property var displayModes: ["bottom", "center", "fullscreen"]
        property int displayModeIndex: 0
        property string iconSize: "medium"
        property string density: "balanced"
        property string fontWeight: "normal"
        readonly property var iconSizes: ["small", "medium", "large"]
        readonly property var densities: ["compact", "balanced", "spacious"]
        property int iconSizeIndex: 1
        property int densityIndex: 1
        readonly property var fontWeights: ["normal", "medium", "bold"]
        property int fontWeightIndex: 0
        property string errorText: ""

        function applySnapshot(snapshot) {
            if (!snapshot) return
            if (snapshot.displayMode !== undefined) {
                displayMode = snapshot.displayMode
                const idx = displayModes.indexOf(displayMode)
                displayModeIndex = idx >= 0 ? idx : 0
            }
            const profiles = snapshot.layoutProfiles
            const profile = profiles && profiles[displayMode] ? profiles[displayMode] : null
            if (!profile)
                return
            iconSize = iconSizes.indexOf(profile.iconSize) >= 0 ? profile.iconSize : "medium"
            density = densities.indexOf(profile.density) >= 0 ? profile.density : "balanced"
            fontWeight = fontWeights.indexOf(profile.fontWeight) >= 0 ? profile.fontWeight : "normal"
            iconSizeIndex = iconSizes.indexOf(iconSize)
            densityIndex = densities.indexOf(density)
            fontWeightIndex = fontWeights.indexOf(fontWeight)
        }

        function reloadFromBridge() {
            if (!bridge) return
            const snap = bridge.launcherSnapshot()
            applySnapshot(snap)
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        function saveDisplayMode(index) {
            displayModeIndex = index
            displayMode = displayModes[index] || "bottom"
            if (bridge) {
                const snap = bridge.updateLauncherDisplayMode(displayMode)
                applySnapshot(snap)
                if (bridge.lastError)
                    errorText = bridge.lastError
            }
        }

        function saveFontWeight(index) {
            fontWeightIndex = index
            fontWeight = fontWeights[index] || "normal"
            if (bridge) {
                const snap = bridge.updateLauncherProfileFontWeight(displayMode, fontWeight)
                applySnapshot(snap)
                if (bridge.lastError)
                    errorText = bridge.lastError
            }
        }

        function saveIconSize(index) {
            iconSizeIndex = index
            iconSize = iconSizes[index] || "medium"
            if (bridge) {
                const snap = bridge.updateLauncherProfileIconSize(displayMode, iconSize)
                applySnapshot(snap)
                if (bridge.lastError)
                    errorText = bridge.lastError
            }
        }

        function saveDensity(index) {
            densityIndex = index
            density = densities[index] || "balanced"
            if (bridge) {
                const snap = bridge.updateLauncherProfileDensity(displayMode, density)
                applySnapshot(snap)
                if (bridge.lastError)
                    errorText = bridge.lastError
            }
        }

        function resetCurrentProfile() {
            if (!bridge)
                return
            const snap = bridge.resetLauncherLayoutProfile(displayMode)
            applySnapshot(snap)
            if (bridge.lastError)
                errorText = bridge.lastError
        }

        Component.onCompleted: reloadFromBridge()

        Text {
            text: "显示形态".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
        }

        Rectangle {
            Layout.fillWidth: true
            color: theme.card
            radius: 18
            implicitHeight: 54

            Item {
                anchors.fill: parent
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    SettingIcon { symbol: "❖"; tint: "#ff9500" }
                    Text {
                        text: "启动台形态"
                        color: theme.primaryText
                        font.pixelSize: 14
                    }
                    Item { Layout.fillWidth: true }
                    SettingsNavBar {
                        id: launcherModeNavBar
                        model: [
                            { id: "bottom",     label: "底部吸附" },
                            { id: "center",     label: "屏幕居中" },
                            { id: "fullscreen", label: "全屏覆盖" }
                        ]
                        itemWidthOverride: 76
                        currentIndex: launcherPage.displayModeIndex
                        onSelectionChanged: function(index) {
                            launcherPage.saveDisplayMode(index)
                        }
                    }
                }
            }
        }

        Text {
            text: "网格、图标与文字".toUpperCase()
            color: theme.secondaryText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            Layout.leftMargin: 13
            Layout.topMargin: 14
        }

        Rectangle {
            Layout.fillWidth: true
            color: theme.card
            radius: 18
            implicitHeight: 221

            Column {
                anchors.fill: parent

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "◉"; tint: "#ff9500" }
                        Text {
                            text: "图标大小"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            model: [
                                { id: "small", label: "小" },
                                { id: "medium", label: "中" },
                                { id: "large", label: "大" }
                            ]
                            itemWidthOverride: 56
                            currentIndex: launcherPage.iconSizeIndex
                            onSelectionChanged: function(index) {
                                launcherPage.saveIconSize(index)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "↔"; tint: "#5ac8fa" }
                        Text {
                            text: "网格密度"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            model: [
                                { id: "compact", label: "紧凑" },
                                { id: "balanced", label: "标准" },
                                { id: "spacious", label: "宽松" }
                            ]
                            itemWidthOverride: 56
                            currentIndex: launcherPage.densityIndex
                            onSelectionChanged: function(index) {
                                launcherPage.saveDensity(index)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "B"; tint: "#ff9500" }
                        Text {
                            text: "字体粗细"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        SettingsNavBar {
                            id: launcherFontWeightNavBar
                            model: [
                                { id: "normal", label: "常规" },
                                { id: "medium", label: "中黑" },
                                { id: "bold",   label: "粗体" }
                            ]
                            itemWidthOverride: 56
                            currentIndex: launcherPage.fontWeightIndex
                            onSelectionChanged: function(index) {
                                launcherPage.saveFontWeight(index)
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 53
                    height: 1
                    color: theme.separator
                }

                Item {
                    width: parent.width
                    height: 54
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12
                        SettingIcon { symbol: "↺"; tint: "#8e8e93" }
                        Text {
                            text: "恢复推荐布局"
                            color: theme.primaryText
                            font.pixelSize: 14
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: "仅当前形态"
                            color: theme.secondaryText
                            font.pixelSize: 11
                        }
                        Rectangle {
                            width: 52
                            height: 26
                            radius: 13
                            color: resetProfileMouse.containsMouse
                                ? Qt.rgba(0.04, 0.52, 1.0, 0.20)
                                : Qt.rgba(0.04, 0.52, 1.0, 0.12)
                            Text {
                                anchors.centerIn: parent
                                text: "恢复"
                                color: theme.dark ? "#64b5ff" : "#0066cc"
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                id: resetProfileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: launcherPage.resetCurrentProfile()
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 13
            Layout.rightMargin: 13
            visible: launcherPage.errorText.length > 0
            text: launcherPage.errorText
            color: "#ff453a"
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }

    Item {
        anchors.fill: parent

        Rectangle {
            id: sidebar
            x: 0
            y: 0
            width: 302
            height: parent.height
            radius: 0
            color: theme.sidebar

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.topMargin: 22
                anchors.bottomMargin: 16
                spacing: 0

                Text {
                    text: "设置"
                    color: theme.primaryText
                    font.pixelSize: 26
                    font.weight: Font.Bold
                    Layout.leftMargin: 6
                    Layout.bottomMargin: 8
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    Layout.bottomMargin: 10

                    LiquidControls.LiquidTextField {
                        anchors.fill: parent
                        leftPadding: 36
                        rightPadding: 10
                        placeholderText: "搜索"
                        glassColor: theme.searchField
                        textColor: theme.primaryText
                        mutedTextColor: theme.secondaryText
                        font.pixelSize: 13
                        onTextChanged: window.searchText = text
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        color: theme.secondaryText
                        font.pixelSize: 16
                        z: 1
                    }
                }

                SidebarEntry {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    pageIndex: 0
                    label: "外观"
                    navSymbol: "◈"
                    navTint: "#af52de"
                }

                SidebarEntry {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    pageIndex: 1
                    label: "顶栏"
                    navSymbol: "⎍"
                    navTint: "#5ac8fa"
                }

                SidebarEntry {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    pageIndex: 2
                    label: "Dock"
                    navSymbol: "▰"
                    navTint: "#0a84ff"
                }

                SidebarEntry {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    pageIndex: 3
                    label: "启动台"
                    navSymbol: "❖"
                    navTint: "#ff9500"
                }

                SidebarEntry {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    pageIndex: 4
                    label: "快捷键"
                    navSymbol: "⌘"
                    navTint: "#5856d6"
                }

                SidebarEntry {
                    Layout.fillWidth: true
                    Layout.topMargin: 1
                    pageIndex: 5
                    label: "接入状态"
                    navSymbol: "✓"
                    navTint: "#30d158"
                }

                Item {
                    Layout.fillHeight: true
                }
            }
        }

        Rectangle {
            id: contentSurface
            x: sidebar.width
            y: 0
            width: parent.width - x
            height: parent.height
            radius: 0
            color: theme.background

            Flickable {
                id: pageScroll
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                contentWidth: Math.max(width, pageContent.width)
                contentHeight: pageContent.implicitHeight
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                ColumnLayout {
                    id: pageContent
                    readonly property real maximumWidth: 700
                    width: Math.max(0, Math.min(pageScroll.width, maximumWidth))
                    x: Math.max(0, Math.round((pageScroll.width - width) / 2))
                    spacing: 0

                    Text {
                        text: window.contentByPage[window.currentPage].subtitle
                        color: theme.primaryText
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        Layout.bottomMargin: 18
                    }
                    Repeater {
                        model: (window.currentPage >= 0 && window.currentPage <= 5)
                            ? [] : window.contentByPage[window.currentPage].groups
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 5
                            Text {
                                text: modelData.header.toUpperCase()
                                color: theme.secondaryText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.leftMargin: 13
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: settingsList.contentHeight
                                radius: 28
                                color: theme.card
                                ListView {
                                    id: settingsList
                                    width: parent.width
                                    height: contentHeight
                                    interactive: false
                                    model: modelData.rows
                                    delegate: SettingRow { row: modelData }
                                }
                            }
                            Item { Layout.preferredHeight: 14 }
                        }
                    }

                    LauncherSettingsPage {
                        visible: window.currentPage === 3
                    }

                    ShortcutsSettingsPage {
                        visible: window.currentPage === 4
                    }

                    IntegrationStatusPage {
                        visible: window.currentPage === 5
                    }

                    DockSettingsPage {
                        visible: window.currentPage === 2
                    }

                    BarSettingsPage {
                        visible: window.currentPage === 1
                    }

                    ThemeSettingsPage {
                        visible: window.currentPage === 0
                    }
                }
            }
        }
    }
}
