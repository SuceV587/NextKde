import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.desktop.modules.common
import qs.desktop.modules.dock

// Win11 风格的独立剪贴板面板（Meta+V）。
//
// 它与 QuickSearch 的窗口/应用切换器是两套独立面板：剪贴板有自己的尺寸、
// 布局和键盘语义，塞进同一个面板会让两边都难改。
//
// 交互契约：
//   单击条目    = 写入剪贴板 + 注入 Ctrl+V 到原窗口（「一点就是输入」）
//   Ctrl+单击   = 只写入剪贴板，不注入
//   ↑↓ / Enter / Esc / Delete / Tab 键盘等价
PanelWindow {
    id: root

    // 让 KWin 的 glass 插件能把这个 surface 和其他 quickshell 面板区分开。
    WlrLayershell.namespace: "quickshell-clipboard"

    property bool open: false
    property string query: ""
    property int selectedIndex: 0
    // 0 = 全部（历史），1 = 固定
    property int activeTab: 0
    property bool settingsOpen: false

    signal closeRequested
    // 请求把选中的条目写进剪贴板并按需注入粘贴（调度交给 Clipboard 控制器）。
    signal pasteRequested(var item, bool copyOnly)

    readonly property bool showingPinned: activeTab === 1

    // 尺寸常量集中在这里：布局和高度计算必须用同一组数字，否则列表会
    // 和卡片底部错位。
    readonly property int panelWidth: 560
    readonly property int itemHeight: 62
    readonly property int maxVisibleItems: 8
    readonly property int horizontalPadding: 12

    property real revealProgress: open ? 1.0 : 0.0
    Behavior on revealProgress {
        NumberAnimation { duration: 110; easing.type: Easing.OutCubic }
    }

    // ------------------------------------------------------------ 视图模型
    // 历史条目与固定条目的字段不同，这里归一成一种形状，delegate 和键盘
    // 导航就都不必再关心来源差异。
    readonly property var model: {
        ClipboardService.revision
        ClipboardService.pinnedRevision
        const needle = query.trim().toLowerCase()
        const out = []

        if (root.showingPinned) {
            const items = ClipboardService.pinned || []
            for (let i = 0; i < items.length; i++) {
                const item = items[i]
                const text = item.isImage ? "图片" : item.preview
                if (needle && !text.toLowerCase().includes(needle))
                    continue
                out.push({
                    key: "p-" + item.pinId,
                    source: "pinned",
                    isImage: item.isImage,
                    text: text,
                    detail: item.isImage ? root.imageDetail(item.preview) : "已固定",
                    pinId: item.pinId,
                    record: "",
                    entry: null,
                    pinnedThumbnail: item.thumbnail,
                })
            }
        } else {
            const items = ClipboardService.entries || []
            for (let i = 0; i < items.length; i++) {
                const item = items[i]
                const text = item.isImage ? "图片" : item.preview
                if (needle && !text.toLowerCase().includes(needle))
                    continue
                out.push({
                    key: "h-" + item.id,
                    source: "history",
                    isImage: item.isImage,
                    text: text,
                    detail: item.isImage
                        ? root.imageDetail(item.preview)
                        : "文本 · " + text.length + " 字符",
                    pinId: "",
                    record: item.record,
                    entry: item,
                    pinnedThumbnail: "",
                })
            }
        }
        return out
    }

    readonly property int modelCount: model.length
    readonly property int pinnedCount: (ClipboardService.pinned || []).length

    // "[[ binary data 38 KiB png 904x346 ]]" → "PNG · 904 × 346"
    function imageDetail(preview) {
        const match = preview.match(/\[\[ binary data .+ (png|jpe?g|gif|bmp|tiff?|webp) (\d+)x(\d+) \]\]/i)
        if (!match)
            return "图片"
        return match[1].toUpperCase() + " · " + match[2] + " × " + match[3]
    }

    // ------------------------------------------------------------ 行为
    function reset() {
        query = ""
        selectedIndex = 0
        settingsOpen = false
        focusTimer.restart()
        list.positionViewAtBeginning()
    }

    function moveSelection(delta) {
        if (modelCount === 0)
            return
        selectedIndex = (selectedIndex + delta + modelCount) % modelCount
        list.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    // copyOnly 为真时只写剪贴板不注入键——留给「我想把它放到别处」的场景。
    // 真正的粘贴调度（等焦点归位再注入 Ctrl+V）交给 Clipboard 控制器。
    function activate(index, copyOnly) {
        if (index < 0 || index >= modelCount)
            return
        pasteRequested(model[index], copyOnly)
        closeRequested()
    }

    function deleteCurrentSelection() {
        if (selectedIndex < 0 || selectedIndex >= modelCount)
            return
        const item = model[selectedIndex]
        if (item.source === "pinned")
            ClipboardService.unpinById(item.pinId)
        else
            ClipboardService.deleteEntry(item.record)
    }

    // 当前选中条目对应的固定项 id（空串表示未固定）。列表里用它决定
    // 按钮显示「固定」还是「取消固定」。
    function pinIdOf(item) {
        if (!item)
            return ""
        if (item.source === "pinned")
            return item.pinId
        return ClipboardService.pinIdFor(item.entry)
    }

    function togglePin(item) {
        if (!item)
            return
        const existing = pinIdOf(item)
        if (existing)
            ClipboardService.unpinById(existing)
        else if (item.entry)
            ClipboardService.pinEntry(item.entry)
    }

    onOpenChanged: {
        if (open) {
            reset()
            ClipboardService.refresh()
            ClipboardService.refreshPinned()
        }
        // 注意：收起时不要取消粘贴请求。activate() 的流程本来就是「先发出
        // 粘贴请求，再关面板」，在这里取消等于把自己的请求掐掉。
        // 清场由 Clipboard.show() 负责 —— 那才是「上一次的残留会不会落到
        // 新窗口上」真正该判断的时刻。
    }

    Timer {
        id: focusTimer
        interval: 1
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    // 面板开着时新内容进历史，列表要跟着动。
    Timer {
        interval: 900
        repeat: true
        running: root.open && !root.showingPinned
        onTriggered: ClipboardService.refresh()
    }

    visible: open
    color: "transparent"
    focusable: true
    BackgroundEffect.blurRegion: (root.visible && dialog.radius > 0) ? blurRegionHolder : null

    Region {
        id: blurRegionHolder
        RoundedBlurRegion {
            item: dialog
            radius: dialog.radius
        }
    }

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // 点击卡片外部关闭。不做调暗遮罩：这是高频快捷键面板，保持
    // Spotlight 式的轻量手感。
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            if (root.settingsOpen)
                root.settingsOpen = false
            else
                root.closeRequested()
        }
    }

    Rectangle {
        id: dialog
        width: root.panelWidth
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: Math.round(parent.height * 0.11)
        }
        // 卡片高度完全由内容列撑开：设置弹层是浮在卡片外侧的，不参与计算。
        height: contentColumn.implicitHeight + 16
        radius: AppearanceTokens.isMaterial
            ? AppearanceTokens.shape.extraLarge : 26
        color: "transparent"
        opacity: root.revealProgress

        readonly property color textOutlineColor: ThemeService.isDark
            ? Qt.rgba(0.05, 0.08, 0.12, 0.38)
            : Qt.rgba(1, 1, 1, 0.50)

        LiquidGlassSurface {
            anchors.fill: parent
            radius: dialog.radius
            baseColor: ThemeService.isDark
                ? Qt.rgba(0.08, 0.09, 0.12, 0.42)
                : Qt.rgba(0.95, 0.95, 0.98, 0.55)
            blurStrength: AppearanceConfigService.effectiveLauncherBlur
            liquidStrength: AppearanceConfigService.effectiveLauncherLiquid
            // 保持中性：壁纸取色会让这个瞬时面板显得发脏。
            ambientStrength: 0.0
            border.width: 1
            border.color: ThemeService.isDark
                ? Qt.rgba(1, 1, 1, 0.12)
                : Qt.rgba(1, 1, 1, 0.60)
        }

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 8
            }
            spacing: 6

            // ================================================== 标题栏
            Item {
                width: parent.width
                height: 32

                GlassText {
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: "剪贴板"
                    color: ThemeService.foregroundColor
                    font {
                        family: "Noto Sans CJK SC"
                        pixelSize: 14
                        weight: Font.DemiBold
                    }
                    style: ThemeService.isDark ? Text.Outline : Text.Normal
                    styleColor: dialog.textOutlineColor
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: 2
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 2

                    // 设置（图片监听 / 保留条数）
                    IconButton {
                        glyph: "⚙"
                        active: root.settingsOpen
                        onClicked: root.settingsOpen = !root.settingsOpen
                    }
                    // 清空全部历史
                    IconButton {
                        glyph: "🗑"
                        danger: true
                        enabled: !root.showingPinned && root.modelCount > 0
                        onClicked: ClipboardService.clearAll()
                    }
                    IconButton {
                        glyph: "✕"
                        onClicked: root.closeRequested()
                    }
                }
            }

            // ================================================== 搜索框
            Item {
                width: parent.width
                height: 40

                LiquidGlassSurface {
                    id: fieldPill
                    anchors.fill: parent
                    radius: AppearanceTokens.isMaterial
                        ? AppearanceTokens.shape.medium : height / 2
                    baseColor: ThemeService.isDark
                        ? Qt.rgba(1, 1, 1, 0.07)
                        : Qt.rgba(0, 0, 0, 0.06)
                    surfaceOpacity: 1.0
                    materialDepth: 1.0
                    bottomShadeVisible: false
                    ambientStrength: 0.0

                    Rectangle {
                        anchors.fill: parent
                        radius: fieldPill.radius
                        color: "transparent"
                        border.width: searchInput.activeFocus ? 1 : 0
                        border.color: ThemeService.isDark
                            ? Qt.rgba(1, 1, 1, 0.40)
                            : Qt.rgba(0, 0, 0, 0.25)
                    }
                }

                GlassText {
                    anchors {
                        left: fieldPill.left
                        leftMargin: 13
                        verticalCenter: fieldPill.verticalCenter
                    }
                    text: "⌕"
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 18
                    style: ThemeService.isDark ? Text.Outline : Text.Normal
                    styleColor: dialog.textOutlineColor
                }

                TextInput {
                    id: searchInput
                    anchors {
                        left: fieldPill.left
                        leftMargin: 40
                        right: fieldPill.right
                        rightMargin: 14
                        verticalCenter: fieldPill.verticalCenter
                    }
                    color: ThemeService.foregroundColor
                    font {
                        family: "Noto Sans CJK SC"
                        pixelSize: 14
                    }
                    clip: true
                    selectByMouse: true
                    text: root.query
                    onTextEdited: {
                        root.query = text
                        root.selectedIndex = 0
                    }

                    Keys.onPressed: function (event) {
                        const control = (event.modifiers & Qt.ControlModifier) !== 0
                        if (event.key === Qt.Key_Down || (control && event.key === Qt.Key_N)) {
                            root.moveSelection(1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Up || (control && event.key === Qt.Key_P)) {
                            root.moveSelection(-1)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            root.activate(root.selectedIndex, false)
                            event.accepted = true
                        } else if (event.key === Qt.Key_Escape) {
                            if (root.settingsOpen) {
                                root.settingsOpen = false
                            } else if (root.query) {
                                root.query = ""
                            } else {
                                root.closeRequested()
                            }
                            event.accepted = true
                        } else if (event.key === Qt.Key_Tab) {
                            root.activeTab = root.activeTab === 0 ? 1 : 0
                            root.selectedIndex = 0
                            event.accepted = true
                        } else if (event.key === Qt.Key_Delete) {
                            root.deleteCurrentSelection()
                            event.accepted = true
                        }
                    }

                    GlassText {
                        anchors.fill: parent
                        visible: !searchInput.text
                        text: root.showingPinned ? "搜索固定内容" : "搜索剪贴板历史"
                        color: Qt.rgba(1, 1, 1, 0.50)
                        font: searchInput.font
                        verticalAlignment: Text.AlignVCenter
                        style: ThemeService.isDark ? Text.Outline : Text.Normal
                        styleColor: dialog.textOutlineColor
                    }
                }
            }

            // ================================================== 分类页签
            Row {
                width: parent.width
                height: 30
                spacing: 6

                TabPill {
                    label: "全部"
                    count: (ClipboardService.entries || []).length
                    selected: root.activeTab === 0
                    onClicked: {
                        root.activeTab = 0
                        root.selectedIndex = 0
                    }
                }
                TabPill {
                    label: "固定"
                    count: root.pinnedCount
                    selected: root.activeTab === 1
                    onClicked: {
                        root.activeTab = 1
                        root.selectedIndex = 0
                    }
                }

                Item { width: parent.width - 400; height: 1 }

                GlassText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.showingPinned ? "固定内容不会被历史轮转清掉" : "单击即粘贴到原窗口 · Ctrl+单击仅复制"
                    color: Qt.rgba(1, 1, 1, 0.42)
                    font.pixelSize: 10
                    style: ThemeService.isDark ? Text.Outline : Text.Normal
                    styleColor: dialog.textOutlineColor
                }
            }

            // ================================================== 条目列表
            Item {
                width: parent.width
                height: {
                    const count = Math.min(root.modelCount, root.maxVisibleItems)
                    // 空状态给一个固定高度的提示区，避免卡片塌成一条。
                    return count > 0 ? count * root.itemHeight : 92
                }

                ListView {
                    id: list
                    anchors.fill: parent
                    visible: root.modelCount > 0
                    clip: true
                    model: root.model
                    currentIndex: root.selectedIndex
                    spacing: 0
                    boundsBehavior: Flickable.StopAtBounds
                    keyNavigationEnabled: false
                    // 让控制台里的滚动副作用安静下来：这个列表只由键盘/滚轮驱动。
                    interactive: true

                    delegate: ClipboardItem {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: root.itemHeight
                        entry: modelData
                        selected: index === root.selectedIndex
                        pinned: root.pinIdOf(modelData) !== ""
                        onHovered: root.selectedIndex = index
                        onActivated: function (copyOnly) { root.activate(index, copyOnly) }
                        onPinToggled: root.togglePin(modelData)
                        onRemoveRequested: {
                            if (modelData.source === "pinned")
                                ClipboardService.unpinById(modelData.pinId)
                            else
                                ClipboardService.deleteEntry(modelData.record)
                        }
                    }
                }

                // 空状态
                Column {
                    anchors.centerIn: parent
                    visible: root.modelCount === 0
                    spacing: 6
                    GlassText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.query ? "没有匹配的内容" : (root.showingPinned ? "还没有固定任何内容" : "剪贴板历史为空")
                        color: Qt.rgba(1, 1, 1, 0.62)
                        font.pixelSize: 13
                        style: ThemeService.isDark ? Text.Outline : Text.Normal
                        styleColor: dialog.textOutlineColor
                    }
                    GlassText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !root.query && !root.showingPinned
                        text: "复制点东西，再按 Meta+V"
                        color: Qt.rgba(1, 1, 1, 0.38)
                        font.pixelSize: 11
                        style: ThemeService.isDark ? Text.Outline : Text.Normal
                        styleColor: dialog.textOutlineColor
                    }
                }
            }

            // ================================================== 底栏
            Item {
                width: parent.width
                height: 26

                GlassText {
                    anchors {
                        left: parent.left
                        leftMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: root.modelCount + " 项"
                        + (ClipboardService.maxItems > 0 ? " · 上限 " + ClipboardService.maxItems : "")
                    color: Qt.rgba(1, 1, 1, 0.40)
                    font.pixelSize: 10
                    style: ThemeService.isDark ? Text.Outline : Text.Normal
                    styleColor: dialog.textOutlineColor
                }

                GlassText {
                    anchors {
                        right: parent.right
                        rightMargin: 8
                        verticalCenter: parent.verticalCenter
                    }
                    text: "Tab 切换分类"
                    color: Qt.rgba(1, 1, 1, 0.34)
                    font.pixelSize: 10
                    style: ThemeService.isDark ? Text.Outline : Text.Normal
                    styleColor: dialog.textOutlineColor
                }
            }
        }

        // ==================================================== 设置弹层
        Rectangle {
            id: settingsPopover
            visible: root.settingsOpen
            z: 20
            width: 300
            height: settingsColumn.implicitHeight + 24
            radius: 18
            color: "transparent"
            anchors {
                top: dialog.top
                topMargin: 38
                right: dialog.right
                rightMargin: 8
            }

            LiquidGlassSurface {
                anchors.fill: parent
                radius: settingsPopover.radius
                baseColor: ThemeService.isDark
                    ? Qt.rgba(0.12, 0.13, 0.16, 0.96)
                    : Qt.rgba(0.96, 0.96, 0.98, 0.96)
                blurStrength: AppearanceConfigService.effectiveLauncherBlur
                liquidStrength: AppearanceConfigService.effectiveLauncherLiquid
                ambientStrength: 0.0
                border.width: 1
                border.color: ThemeService.isDark
                    ? Qt.rgba(1, 1, 1, 0.18)
                    : Qt.rgba(0, 0, 0, 0.12)
            }

            Column {
                id: settingsColumn
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 12
                }
                spacing: 10

                GlassText {
                    text: "剪贴板偏好"
                    font { pixelSize: 13; weight: Font.DemiBold; family: "Noto Sans CJK SC" }
                    color: ThemeService.foregroundColor
                    style: ThemeService.isDark ? Text.Outline : Text.Normal
                    styleColor: dialog.textOutlineColor
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
                }

                Row {
                    width: parent.width
                    Column {
                        width: parent.width - 46
                        spacing: 2
                        GlassText {
                            text: "记录图片"
                            font { pixelSize: 12; weight: Font.Medium; family: "Noto Sans CJK SC" }
                            color: ThemeService.foregroundColor
                            style: ThemeService.isDark ? Text.Outline : Text.Normal
                            styleColor: dialog.textOutlineColor
                        }
                        GlassText {
                            text: "自动记录截图与复制的图片"
                            font.pixelSize: 10
                            color: Qt.rgba(1, 1, 1, 0.55)
                            style: ThemeService.isDark ? Text.Outline : Text.Normal
                            styleColor: dialog.textOutlineColor
                        }
                    }
                    Rectangle {
                        width: 40
                        height: 22
                        radius: 11
                        anchors.verticalCenter: parent.verticalCenter
                        color: ClipboardService.watchImages
                            ? "#34c759"
                            : (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.15))
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18
                            height: 18
                            radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: ClipboardService.watchImages ? parent.width - width - 2 : 2
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: ClipboardService.setWatchImages(!ClipboardService.watchImages)
                        }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6

                    GlassText {
                        text: "历史保留数量"
                        font { pixelSize: 12; weight: Font.Medium; family: "Noto Sans CJK SC" }
                        color: ThemeService.foregroundColor
                        style: ThemeService.isDark ? Text.Outline : Text.Normal
                        styleColor: dialog.textOutlineColor
                    }

                    Row {
                        spacing: 6
                        Repeater {
                            model: [50, 100, 200, 500]
                            Rectangle {
                                width: (settingsColumn.width - 18) / 4
                                height: 26
                                radius: 6
                                color: ClipboardService.maxItems === modelData
                                    ? (ThemeService.isDark ? Qt.rgba(0.20, 0.50, 0.95, 0.40) : Qt.rgba(0.0, 0.45, 0.85, 0.20))
                                    : (limitMouse.containsMouse
                                        ? (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08))
                                        : (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)))
                                border.width: 1
                                border.color: ClipboardService.maxItems === modelData
                                    ? (ThemeService.isDark ? Qt.rgba(0.40, 0.70, 1, 0.60) : Qt.rgba(0.0, 0.45, 0.85, 0.50))
                                    : "transparent"

                                GlassText {
                                    anchors.centerIn: parent
                                    text: modelData + " 条"
                                    font.pixelSize: 11
                                    color: ClipboardService.maxItems === modelData
                                        ? (ThemeService.isDark ? "#64b5ff" : "#0066cc")
                                        : ThemeService.foregroundColor
                                    style: ThemeService.isDark ? Text.Outline : Text.Normal
                                    styleColor: dialog.textOutlineColor
                                }

                                MouseArea {
                                    id: limitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: ClipboardService.setMaxItems(modelData)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)
                }

                Rectangle {
                    width: parent.width
                    height: 30
                    radius: 8
                    color: keysMouse.containsMouse
                        ? (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08))
                        : (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04))

                    GlassText {
                        anchors {
                            left: parent.left
                            leftMargin: 10
                            verticalCenter: parent.verticalCenter
                        }
                        text: "⌨ 修改全局快捷键"
                        font { pixelSize: 11; family: "Noto Sans CJK SC" }
                        color: ThemeService.foregroundColor
                        style: ThemeService.isDark ? Text.Outline : Text.Normal
                        styleColor: dialog.textOutlineColor
                    }

                    MouseArea {
                        id: keysMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ClipboardService.openShortcutSettings()
                            root.settingsOpen = false
                        }
                    }
                }
            }
        }
    }

    // ============================================================ 组件
    // 标题栏图标按钮。
    component IconButton: Item {
        id: button
        property string glyph: ""
        property bool active: false
        property bool danger: false
        signal clicked

        width: 26
        height: 26
        opacity: enabled ? 1.0 : 0.32

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: {
                if (!button.enabled)
                    return "transparent"
                if (button.danger && hitArea.containsMouse)
                    return ThemeService.isDark ? Qt.rgba(1, 0.3, 0.3, 0.24) : Qt.rgba(0.9, 0.1, 0.1, 0.14)
                if (hitArea.containsMouse || button.active)
                    return ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.09)
                return "transparent"
            }
            Behavior on color { ColorAnimation { duration: 110 } }
        }

        GlassText {
            anchors.centerIn: parent
            text: button.glyph
            font.pixelSize: button.glyph === "⚙" ? 13 : 12
            color: {
                if (button.danger && hitArea.containsMouse)
                    return "#ff453a"
                if (button.active)
                    return ThemeService.isDark ? "#64b5ff" : "#0066cc"
                return Qt.rgba(1, 1, 1, 0.72)
            }
            style: ThemeService.isDark ? Text.Outline : Text.Normal
            styleColor: dialog.textOutlineColor
        }

        MouseArea {
            id: hitArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    // 分类页签。
    component TabPill: Rectangle {
        id: pill
        property string label: ""
        property int count: 0
        property bool selected: false
        signal clicked

        width: pillText.implicitWidth + 26
        height: 28
        radius: 8
        color: {
            if (pill.selected)
                return ThemeService.isDark ? Qt.rgba(0.30, 0.56, 0.94, 0.34) : Qt.rgba(0.0, 0.50, 0.90, 0.18)
            return pillMouse.containsMouse
                ? (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
                : "transparent"
        }
        border.width: pill.selected ? 1 : 0
        border.color: ThemeService.isDark
            ? Qt.rgba(0.66, 0.82, 1, 0.42) : Qt.rgba(0.0, 0.50, 0.90, 0.30)
        Behavior on color { ColorAnimation { duration: 120 } }

        GlassText {
            id: pillText
            anchors.centerIn: parent
            text: pill.label + (pill.count > 0 ? "  " + pill.count : "")
            font { pixelSize: 12; weight: Font.DemiBold; family: "Noto Sans CJK SC" }
            color: pill.selected
                ? (ThemeService.isDark ? Qt.rgba(0.86, 0.93, 1, 0.98) : "#0066cc")
                : ThemeService.foregroundColor
            style: ThemeService.isDark ? Text.Outline : Text.Normal
            styleColor: dialog.textOutlineColor
        }

        MouseArea {
            id: pillMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    // 单条剪贴板内容。
    component ClipboardItem: Rectangle {
        id: clip
        // 不要在这里重新声明 index / modelData：它们是 ListView delegate
        // 注入的 required 属性，重复声明会直接编译失败。
        property var entry: null
        property bool selected: false
        property bool pinned: false

        signal hovered
        signal activated(bool copyOnly)
        signal pinToggled
        signal removeRequested

        color: clip.selected
            ? (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.07))
            : (itemMouse.containsMouse
                ? (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(0, 0, 0, 0.04))
                : "transparent")
        radius: 12
        Behavior on color { ColorAnimation { duration: 100 } }

        // 选中指示条
        Rectangle {
            anchors {
                left: parent.left
                leftMargin: 3
                verticalCenter: parent.verticalCenter
            }
            width: 3
            height: clip.selected ? Math.round(parent.height * 0.46) : 0
            radius: 1.5
            color: ThemeService.isDark ? "#64b5ff" : "#0066cc"
            Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }

        // ---------------- 缩略图 / 类型图标
        Item {
            id: leading
            anchors {
                left: parent.left
                leftMargin: 14
                verticalCenter: parent.verticalCenter
            }
            width: 38
            height: 38

            Rectangle {
                anchors.fill: parent
                radius: 9
                color: clip.entry && clip.entry.isImage
                    ? Qt.rgba(0.30, 0.56, 0.94, 0.22)
                    : (ThemeService.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06))
            }

            // 图片条目的真缩略图；文本条目显示类型字形。
            Image {
                id: thumbnail
                anchors {
                    fill: parent
                    margins: 2
                }
                visible: source !== "" && status === Image.Ready
                source: {
                    ClipboardService.thumbnailRevision
                    if (!clip.entry || !clip.entry.isImage)
                        return ""
                    if (clip.entry.source === "pinned")
                        return clip.entry.pinnedThumbnail
                    return ClipboardService.thumbnailFor(clip.entry.entry)
                }
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                // 磁盘上的 thumbs/ 已经是缓存，QML 这层不必再存一份。
                cache: false
                smooth: true
            }

            GlassText {
                anchors.centerIn: parent
                visible: !clip.entry || !clip.entry.isImage || thumbnail.status !== Image.Ready
                text: (clip.entry && clip.entry.isImage) ? "🖼" : "≡"
                font.pixelSize: (clip.entry && clip.entry.isImage) ? 15 : 17
                color: Qt.rgba(1, 1, 1, 0.78)
                style: ThemeService.isDark ? Text.Outline : Text.Normal
                styleColor: dialog.textOutlineColor
            }
        }

        // ---------------- 正文
        Column {
            anchors {
                left: leading.right
                leftMargin: 12
                right: actions.left
                rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 2

            GlassText {
                width: parent.width
                text: clip.entry ? clip.entry.text : ""
                color: ThemeService.foregroundColor
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
                font {
                    family: "Noto Sans CJK SC"
                    pixelSize: 13
                }
                style: ThemeService.isDark ? Text.Outline : Text.Normal
                styleColor: dialog.textOutlineColor
            }

            GlassText {
                width: parent.width
                text: clip.entry ? clip.entry.detail : ""
                color: Qt.rgba(1, 1, 1, 0.46)
                elide: Text.ElideRight
                font.pixelSize: 10
                style: ThemeService.isDark ? Text.Outline : Text.Normal
                styleColor: dialog.textOutlineColor
            }
        }

        // ---------------- 悬停操作
        Row {
            id: actions
            anchors {
                right: parent.right
                rightMargin: 12
                verticalCenter: parent.verticalCenter
            }
            // z 必须高于下面那个铺满整条的 MouseArea，否则固定/删除按钮
            // 会被它盖住、永远点不到。同理，按钮淡出时必须一并 enabled：
            // QML 里 opacity 为 0 的 MouseArea 照样吃点击，那会让条目右侧
            // 静默失效——表现就是「点了没反应」。
            z: 2
            enabled: clip.selected || itemMouse.containsMouse
            spacing: 2
            opacity: enabled ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 110 } }

            IconButton {
                glyph: clip.pinned ? "★" : "☆"
                active: clip.pinned
                onClicked: clip.pinToggled()
            }
            IconButton {
                glyph: "✕"
                danger: true
                onClicked: clip.removeRequested()
            }
        }

        MouseArea {
            id: itemMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onEntered: clip.hovered()
            onClicked: function (mouse) {
                // Ctrl（或中键）表示「只要进剪贴板，不要往窗口里打字」。
                const copyOnly = (mouse.modifiers & Qt.ControlModifier) !== 0
                    || mouse.button === Qt.MiddleButton
                clip.activated(copyOnly)
            }
        }
    }
}
