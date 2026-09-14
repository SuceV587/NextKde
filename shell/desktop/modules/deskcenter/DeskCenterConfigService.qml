pragma Singleton

import QtQuick
import QtCore
import Quickshell
import "WidgetLayout.mjs" as WidgetLayout

QtObject {
    id: service

    property int revision: 0
    readonly property var defaultSizes: ({
        clock: "small",
        weather: "medium",
        calendar: "medium",
        todo: "medium",
        system: "medium",
        activity: "medium",
        music: "medium"
    })
    readonly property var sizeOrder: WidgetLayout.sizeOrder

    property Settings _settings: Settings {
        location: "file://" + Quickshell.stateDir + "/deskcenter-widgets.ini"
        category: "Widgets"
        property int schemaVersion: 1
        property bool widgetsEnabled: true
        property string sizesJson: "{}"
        property string enabledJson: "{}"
    }

    // 桌面小组件总开关
    property bool widgetsEnabled: _settings.widgetsEnabled

    function parsedSizes() {
        try { return JSON.parse(_settings.sizesJson) } catch (_) { return {} }
    }

    function parsedEnabled() {
        try { return JSON.parse(_settings.enabledJson) } catch (_) { return {} }
    }

    // 检查某个组件是否处于激活显示状态（受总开关约束）
    function isWidgetEnabled(widgetId) {
        if (!widgetsEnabled)
            return false
        return isWidgetIndividualEnabled(widgetId)
    }

    // 单独检查某组件在偏好设置中是否开启
    function isWidgetIndividualEnabled(widgetId) {
        const enabledMap = parsedEnabled()
        if (enabledMap[widgetId] !== undefined)
            return Boolean(enabledMap[widgetId])
        return true
    }

    // 设置桌面小组件总开关
    function setWidgetsEnabled(enabled) {
        const next = Boolean(enabled)
        if (widgetsEnabled === next && _settings.widgetsEnabled === next)
            return false
        widgetsEnabled = next
        _settings.widgetsEnabled = next
        _settings.sync()
        revision++
        return true
    }

    // 设置单个桌面小组件开启/关闭
    function setWidgetEnabled(widgetId, enabled) {
        const enabledMap = parsedEnabled()
        const next = Boolean(enabled)
        if (enabledMap[widgetId] === next)
            return false
        enabledMap[widgetId] = next
        _settings.enabledJson = JSON.stringify(enabledMap)
        _settings.sync()
        revision++
        return true
    }

    function sizeFor(widgetId) {
        const sizes = parsedSizes()
        const value = String(sizes[widgetId] ?? defaultSizes[widgetId] ?? "medium")
        return WidgetLayout.normalizedSize(value)
    }

    function setSize(widgetId, size) {
        if (sizeOrder.indexOf(size) < 0)
            return false
        const sizes = parsedSizes()
        if (sizes[widgetId] === size)
            return false
        sizes[widgetId] = size
        _settings.sizesJson = JSON.stringify(sizes)
        _settings.sync()
        revision++
        return true
    }

    function cycleSize(widgetId) {
        const current = sizeFor(widgetId)
        const next = sizeOrder[(sizeOrder.indexOf(current) + 1) % sizeOrder.length]
        setSize(widgetId, next)
        return next
    }

    function spanFor(widgetId) {
        return WidgetLayout.spanFor(widgetId, sizeFor(widgetId))
    }

    readonly property var widgetMeta: [
        { id: "clock", name: "时钟与计时", desc: "时钟表盘、多时区与快捷倒计时", icon: "🕒" },
        { id: "weather", name: "天气预报", desc: "实时气温、天气状况与趋势预测", icon: "🌤" },
        { id: "calendar", name: "日历日程", desc: "月历视图与节假日农历信息", icon: "📅" },
        { id: "todo", name: "待办清单", desc: "个人待办任务便签与快速标记", icon: "☑" },
        { id: "system", name: "系统监视", desc: "CPU、内存占用与系统状态监控", icon: "📊" },
        { id: "activity", name: "使用统计", desc: "屏幕使用时间与活动应用统计", icon: "⌛" },
        { id: "music", name: "媒体播放", desc: "MPRIS 媒体控制与专辑卡片", icon: "🎵" }
    ]

    function allWidgetsStatus() {
        const result = []
        for (let i = 0; i < widgetMeta.length; i++) {
            const meta = widgetMeta[i]
            result.push({
                id: meta.id,
                name: meta.name,
                desc: meta.desc,
                icon: meta.icon,
                enabled: isWidgetIndividualEnabled(meta.id),
                size: sizeFor(meta.id)
            })
        }
        return result
    }
}
