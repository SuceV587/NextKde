# 全局外观系统开发路线图

## 目标

在 `kos-settings` 中建立独立的“显示”和“主题”页面，并让全局外观配置实时、持久地影响 Dock、Bar 和 DeskCenter 桌面组件。

外观系统包含三个互相独立的维度：

1. **配色模式**：当前由 KDE 系统色彩方案管理；后续再决定是否纳入本项目配置。
2. **形态风格**：Windows 12、macOS、Material Design。
3. **玻璃材质**：模糊强度、液态强度。

形态风格不覆盖配色模式。用户应当可以组合出“深色 macOS”“浅色 Material Design”等配置。

## 产品边界

### 显示页面

第一版只负责液态玻璃，不在这次改造中实现分辨率、缩放、刷新率或屏幕排列。

| 设置项 | 用户值 | 实际作用 |
| --- | --- | --- |
| 模糊强度 | 0–100% | 控制液态玻璃插件的内容与 Dock 模糊管线，不修改 KDE 自带模糊效果 |
| 液态强度 | 0–100% | 控制折射、高光、边缘和环境色混合的整体幅度 |
| 恢复默认 | 当前风格默认值 | 只重置玻璃参数，不重置形态、Dock 内容或布局 |

设置应用应显示即时预览卡片。拖动时预览即时更新，外部配置写入采用节流或松手提交，避免连续触发昂贵的模糊更新。

两个参数属于项目自带的液态玻璃材质；大面积背景效果同步到 `glass` 插件自己的配置，不修改 KDE 自带的 `Effect-blur`。

### 主题页面

主题页面包含形态风格；配色模式目前保留在“显示”页面。形态卡片应有缩略预览、名称、简短说明和当前选中状态。

“Windows 12”在这里是本项目定义的设计语言，不宣称复刻未正式发布的微软产品。第一轮视觉评审必须冻结三套规格后再大面积改 QML。

## 三种形态的第一版规格

| 区域 | Windows 12 | macOS | Material Design |
| --- | --- | --- | --- |
| Dock | 底部通栏任务栏形态，应用居中，低圆角、紧凑间距 | 底部悬浮 Dock，高圆角、较强放大与玻璃层次 | 悬浮 Navigation Dock，中等圆角，选中项使用 tonal indicator |
| Bar | 统一顶栏或按开关融入底部 Dock | 统一顶栏或按开关融入底部 Dock | 统一顶栏或按开关融入底部 Dock |
| 桌面组件 | 信息密度较高，低圆角，轻亚克力卡片 | 大圆角、平静色块或轻玻璃、较宽留白 | Material 卡片、tonal surface、统一 elevation 和状态层 |
| 动效 | 短、克制、强调状态变化 | 弹性和悬浮感更明显 | 标准缓动，强调容器变形与状态层 |
| 默认玻璃 | 中等透明、中高模糊 | 高透明、高模糊 | 较低透明、中等模糊；以 tonal surface 为主 |

第一版保留现有 Dock 位置、尺寸、显示方式等用户设置。切换形态只改变视觉 token 和布局策略；若某种风格有推荐布局，提供“应用推荐布局”按钮，不应静默覆盖用户原配置。

## 架构方案

### 1. 全局配置所有权

新增 `AppearanceConfigService`，放在 `desktop/modules/common/`，持久化到：

```text
Quickshell.stateDir + "/appearance/config.json"
```

当前 schema 2（已实现）：

```json
{
  "version": 2,
  "shellStyle": "macos",
  "blurStrength": 0.42,
  "liquidStrength": 1.0
}
```

约束：

- `shellStyle`: `windows12 | macos | material`
- `blurStrength`、`liquidStrength`: `0.0 ... 1.0`
- 所有输入在 service 层校验、裁剪并防抖保存。
- Dock 的固定项、位置、尺寸和自动隐藏继续由 `DockConfigService` 所有；迁移完成后仅把旧 `theme` 字段投影到全局配色配置。

### 2. 视觉 token 层

新增只读单例 `AppearanceTokens`，根据 `shellStyle`、配色和玻璃设置导出语义 token。组件禁止直接判断多个字符串并散落硬编码值。

第一版至少提供：

```text
bar.height / bar.position / bar.radius / bar.surfaceMode
dock.radius / dock.padding / dock.spacing / dock.indicatorStyle
widget.radius / widget.gap / widget.surfaceMode / widget.elevation
motion.fast / motion.normal / motion.springEnabled
glass.blurStrength / glass.liquidStrength / glass.highlightStrength
```

尺寸仍由现有 `iconSize`、`cellSize` 等自变量推导；token 提供比例或上下限，不回退到大量固定像素。

### 3. 设置应用 IPC

保留 `apps/settings` 与 `desktop` 的进程隔离，不允许设置应用直接 import 桌面模块。

新增 `appearance-settings` IPC target：

```text
snapshot
updateShellStyle <value>
updateBlurStrength <value>
updateLiquidStrength <value>
resetStrengths
```

`SettingsBridge` 从目前的 Dock 专用调用扩展为明确的 Dock/Appearance 两组方法。所有更新返回完整 snapshot；UI 采用乐观预览，失败时恢复服务端值并显示错误。

### 4. 玻璃链路

- `LiquidGlassSurface`、`EnhancedGlassSurface` 和 `LiquidGlassControl` 消费统一材质 token。
- 已有单独指定材质深度、环境色或可读性底层的组件继续允许局部乘数，不能重新硬编码全局透明度。
- 模糊强度同时传给 QML 局部模糊和 `glass` 插件自己的内容/Dock 模糊入口。
- 液态强度作为整体乘数作用于折射、高光、边缘和环境色，各表面仍可保留局部深度乘数。

### 5. Windows 底部布局协调

现有 Bar 和 Dock 是两个独立的 layer-shell surface。Windows 风格若让两者都占据屏幕底部，会出现排斥区、输入区和弹窗锚点冲突。

实现前先增加一个全局 chrome 布局策略：

- `macos`、`material`：Bar 在顶部，Dock 独立悬浮。
- `windows12`：由一个底部任务栏布局统一分配应用区和状态区。

第一版优先采用“统一任务栏宿主”，复用现有 Dock delegate 与 Bar 状态组件；不应把两个全宽透明窗口简单叠放。控制中心、网络、蓝牙等弹窗的锚点也必须跟随宿主迁移。

## 分阶段实施与开放

### 阶段 0：基线与视觉规格冻结

工作内容：

- 先整理或提交当前工作区中未完成的 Dock、菜单、桌面改动。
- 为当前 Dock、Bar、DeskCenter 和玻璃 popup 建立截图基线。
- 产出三种风格的 Dock、Bar、桌面组件静态稿或 QML preview。
- 确认 Windows 底部任务栏的组成和 macOS/Material 的推荐布局。

验收：三套规格矩阵获得确认；现有运行日志无新增错误；可以明确指出每个现有组件将消费哪些 token。

开放范围：不对用户开放，仅开发预览。

### 阶段 1：配置、token 与 IPC 骨架

工作内容：

- 新增 `AppearanceConfigService`、配置迁移和 `AppearanceTokens`。
- 新增 `appearance-settings` IPC 和 SettingsBridge 方法。
- 在 `kos-settings` 增加真正的“主题”页面；重做“显示”页为玻璃设置。
- 设置页提供本地预览，但暂不改变生产 Dock、Bar、桌面组件。

验收：重启后配置不丢失；非法值回退；IPC 超时/桌面未运行时有可理解错误；旧 Dock 配置不损坏。

开放范围：设置页已开放主题选择并明确提示各生产 surface 尚未接入。

### 阶段 2：全局玻璃参数

工作内容：

- 统一 `LiquidGlassSurface`、`EnhancedGlassSurface` 的透明度输入。
- 打通液态玻璃组件自身的模糊与液态强度输入。
- 接入 Dock、Bar popup、通知、启动器、搜索等已有玻璃表面。
- 为文字可读性设置最低遮罩和对比度保护。

验收：0%、50%、100% 三档在浅/深壁纸上均无透明断层、双重遮挡或不可读文字；连续拖动不造成明显卡顿。

开放范围：正式开放“显示 > 液态玻璃”。

### 阶段 3：Dock 三形态

当前状态：第一轮已完成。生产 Dock 已消费圆角、padding、spacing、状态背景、运行指示器、edge margin 与 motion Token；统一任务栏宿主已在阶段 4 实现，并改为不依赖主题的独立配置。

工作内容：

- 将 Dock 尺寸、间距、圆角、指示器、材质和动效改为 token 驱动。
- 完成 macOS、Material Design 两套独立形态。
- 建立 Windows 统一任务栏宿主，迁移 Dock 应用区。
- 保持固定、运行窗口、拖动排序、自动隐藏、窗口预览和多屏逻辑不变。

验收：三种形态可热切换；无应用模型重建或顺序丢失；底部/侧边、三种显示方式和多屏组合通过；Windows 模式没有 Bar/Dock 覆盖。

开放范围：主题页已标记 Dock 支持；Windows 12 暂为独立 Dock 形态预览。

### 阶段 4：Bar 统一宿主

当前状态：已完成。Bar 不再随主题分叉；新增独立的 `barIntegratedWithDock` 开关。底部 Dock 开启融合时成为唯一宿主：时间加入音乐/天气信息轮播，macOS 时间页使用“液态秒钟 + 普通日期”双排布局，系统状态区成为右侧附件；侧边 Dock 自动回退顶部 Bar。融合宿主中的托盘、网络、蓝牙、电池、温度和控制中心弹窗统一向上展开。

验收：弹窗锚点正确；排斥区和最大化窗口工作区正确；睡眠/唤醒及屏幕热插拔后 Bar 恢复；融合模式只有一个底部 chrome 区域。

开放范围：主题页提供“Bar 融入 Dock”开关。

### 阶段 5：DeskCenter 三形态

工作内容：

- 将桌面网格 gap、卡片圆角、表面、elevation 和内容边距改为 token 驱动。
- 保持组件数据与业务逻辑不变，仅替换容器和视觉呈现。
- 根据形态决定色块、轻玻璃或 tonal surface；高透明玻璃仍需保证文字对比度。
- 验证桌面文件区与侧边 Dock 的安全区域。

验收：短屏、多屏、侧边 Dock 下布局不重叠；天气、日历、系统、活动、音乐等卡片内容不裁切；交互区域与视觉区域一致。

开放范围：三种主题完整开放，移除实验标记。

### 阶段 6：收口与迁移

工作内容：

- 清理旧的散落颜色、圆角和动画常量。
- 将旧 Dock `theme` 安全迁移到 `colorScheme`，保留未知字段并提供版本升级函数。
- 增加“恢复此主题默认值”，明确不会清空 Dock 应用和桌面数据。
- 更新架构文档、README 和故障排查说明。

验收：全量重启、配置升级、损坏配置恢复、多屏和缩放测试通过；没有遗留的内部 `legacy` 开关。

## 每阶段统一验证门槛

每个阶段独立提交，提交前至少执行：

```text
qmllint（本阶段修改的 QML）
node desktop/modules/dock/test_adaptive.mjs
node desktop/modules/dock/test_autohide.mjs
git diff --check
独立 Quickshell 实例启动与日志检查
kos-settings 构建和启动检查（涉及设置应用时）
```

视觉阶段还需保存三种形态、浅/深配色和至少两类壁纸的对比截图。不能用“QML 可加载”代替视觉验收。

## 提交拆分建议

```text
feat(appearance): add global appearance configuration contract
feat(settings): add appearance and glass settings pages
feat(glass): apply global blur and liquid strength controls
feat(dock): add shell style variants
feat(bar): add shell style variants
feat(deskcenter): add shell style variants
docs(appearance): finalize migration and verification guide
```

每次只让一个主要 surface 开始消费新 token。这样某一阶段出现问题时，可以回退该 surface，而不影响已经稳定的配置和其他组件。

## 当前实现状态（2026-08-24）

- 阶段 1、Dock 形态第一轮和 Bar 统一宿主均已完成：`AppearanceConfigService` schema 3、`AppearanceTokens` v3、主题选择、Bar 融合开关以及生产 Dock Token 消费均已落地。详细契约见 [AppearanceArchitecture.md](AppearanceArchitecture.md)。
- “显示”页面已有 KDE 系统明暗切换、模糊强度和液态强度；“主题”页面负责独立的 Shell 形态。
- `DockConfigService.theme` 当前只表示 `light | dark | system`，不能直接扩展成三种形态枚举。
- Dock、Bar、DeskCenter 已经是独立 surface，适合逐个迁移，但 Windows 底部任务栏需要显式协调 Bar 与 Dock。
- `LiquidGlassSurface`、`EnhancedGlassSurface` 与 `LiquidGlassControl` 已形成可复用材质层，是统一液态和模糊强度的正确入口。
- 模糊和液态强度会同步到项目自带的 `glass` KWin effect，但不修改 KDE 自带的 `Effect-blur`。
- 当前工作区存在未提交的 Dock、菜单和桌面相关修改；阶段 0 必须先隔离这些变更。
