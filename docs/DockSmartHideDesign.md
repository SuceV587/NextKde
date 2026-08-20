# Dock 显示模式（智能隐藏/持续隐藏）设计与实施规范

> 状态：待开发  
> 面向版本：Dock 配置 v3  
> 设置入口：`kos-settings`  
> 适用位置：底部、左侧、右侧  
> 文档目标：后续 AI 可直接按本文分阶段实现、测试和验收，不需要重新猜测产品行为或架构边界。

## 1. 结论

本功能提供三种互斥的 Dock 显示模式：始终显示、智能隐藏、持续隐藏：

- 始终显示：保持当前行为，Dock 一直显示并保留工作区。
- 智能隐藏：桌面空闲、窗口没有碰到 Dock 时保持显示；窗口进入 Dock 稳定占用区域时平滑收起。
- 持续隐藏：不依赖窗口碰撞；只要没有鼠标、菜单、编辑、拖拽等抑制条件，Dock 就保持收起。
- Dock 隐藏后保留一个半透明圆角小白条，作为状态提示和唤醒入口。
- 小白条沿所在屏幕边缘居中，占屏幕对应长边的 80%；指针悬停或点击后 Dock 平滑出现。
- 全屏窗口位于 Dock 所在屏幕时，Dock 隐藏，但按产品要求仍保留低干扰的小白条。
- 编辑、拖拽、右键菜单、窗口预览、音乐弹窗、App Launcher 打开期间禁止隐藏。
- 隐藏和显示只改变 Dock 内容在现有 `PanelWindow` 内的位移，不销毁窗口、不切换 `visible`、不依赖动画中的绝对 `(x, y)`。

最重要的实现约束是：**窗口碰撞判断永远使用 Dock 完全显示时的静态矩形，不使用正在动画的 Dock 坐标。** 这既能避开循环判断，也能避免此前工程中跨窗口 `mapToItem`/绝对坐标采样一类竞态。

## 2. 产品目标与非目标

### 2.1 目标

1. 在不占用应用窗口空间时保持 Dock 可见，在发生遮挡时主动避让。
2. 隐藏/显示过程连续、柔和，不出现突然消失、窗口重建闪烁或中途跳位。
3. 隐藏状态有明确但低干扰的白色 Home Indicator。
4. 三种显示模式以及底部、左侧、右侧共用同一套状态机和动画进度。
5. 多屏、虚拟桌面、最大化、全屏、窗口拖动、热插拔和不同缩放比例下行为一致。
6. `kos-settings` 是唯一用户设置入口，配置继续由 `DockConfigService` 持久化。
7. 透明窗口未绘制区域必须点击穿透，不能挡住应用的按钮、滚动条或窗口边缘操作。

### 2.2 本期不做

- 不向设置页暴露动画速度、延迟、白条尺寸等高级参数；先用经过调校的统一常量。
- 不允许智能隐藏与持续隐藏同时开启；显示策略必须是单一枚举值。
- 不实现顶部 Dock；当前工程只支持 bottom/left/right。
- 不通过轮询鼠标全局坐标、Shell 命令或定时截图判断窗口遮挡。
- 不在隐藏时销毁 `PanelWindow`，也不为白条创建第二个常驻 layer-shell 窗口。
- 不改变 Dock 当前图标、音乐、天气、拖拽排序和染色功能。

## 3. 成熟方案中采用的原则

本设计综合了以下成熟桌面行为：

- macOS：隐藏后通过指针到 Dock 所在屏幕边缘重新显示；设置层只提供清晰的自动隐藏开关，不把大量技术参数暴露给普通用户。[Apple Desktop & Dock 设置](https://support.apple.com/en-au/guide/mac-help/-mchlp1119/mac)
- KDE Plasma：区分“始终显示”和“自动隐藏”，自动隐藏通过屏幕边缘恢复；历史上的 Latte Dock 还区分 Dodge Active、Dodge Fullscreen、Dodge Windows 等避让策略。[KDE Plasma Panels](https://userbase.kde.org/Plasma/Panels/en)、[KDE Latte Dock](https://userbase.kde.org/LatteDock/en)
- GNOME Dash to Dock：智能隐藏基于窗口范围，具有显示/隐藏延迟、边缘压力、全屏和紧急通知等策略；其默认动画时间约 200ms，说明桌面 Dock 的隐藏动画应短而明确。[Dash to Dock 配置定义](https://github.com/micheleg/dash-to-dock/blob/master/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml)
- Dash to Dock 的实际缺陷修复也证明：碰撞区域必须按“Dock 完全显示时的位置”计算，不能读取正在滑动的 transformed position，否则不同边缘会误判或循环切换。[相关修复说明](https://github.com/micheleg/dash-to-dock/pull/2511)

本工程借鉴这些原则，但保留自己的视觉特征：液态玻璃 Dock、居中胶囊形态，以及隐藏后的 iOS 风格 Home Indicator。

## 4. 当前工程基线与问题约束

### 4.1 当前结构

| 责任 | 当前文件 | 本功能需要的变化 |
|---|---|---|
| 屏幕选择、位置切换 | `desktop/modules/dock/Dock.qml` | 原则上不改行为；继续通过重建组件切换 layer-shell anchors |
| Wayland Dock 窗口 | `desktop/modules/dock/DockWindow.qml` | 承载控制器、位移动画、白条、输入 mask、exclusive zone 策略 |
| Dock 内容与交互 | `desktop/modules/dock/DockContainer.qml` | 暴露 pointer/edit/drag/popup 抑制状态 |
| 动画常量 | `desktop/modules/dock/DockAnimation.qml` | 增加隐藏模式动画和延迟常量 |
| 配置持久化 | `desktop/modules/dock/DockConfigService.qml` | 增加 `visibilityMode`，配置升级到 v3 |
| 窗口数据 | `desktop/modules/dock/WindowService.qml` | 增加稳定几何、屏幕、最大化和 provider-ready 字段 |
| KWin 数据桥 | `helpers/kwin-window-bridge/kwin/contents/code/main.js` | 发布窗口 frame geometry/output，并监听几何变化 |
| Shell IPC | `desktop/DesktopEnvironment.qml` | snapshot/update 增加显示模式字段 |
| Settings IPC 桥 | `apps/settings/src/main.cpp` | bool 字段解析与更新方法 |
| 设置 UI | `apps/settings/main.qml` | 新增独立“Dock 显示”Section 和三模式选择器 |

### 4.2 已确认可复用的 Quickshell 能力

- 当前 Dock 已经是绑定屏幕边缘的 `PanelWindow`，适合在同一 surface 内做内容位移。[Quickshell PanelWindow](https://quickshell.org/docs/types/Quickshell/PanelWindow)
- Quickshell 的 `QsWindow.mask` 可把窗口输入范围限制到指定 `Region`，其余透明区域点击穿透；工程中的 `NotificationWindow.qml` 已有可复用实践。[Quickshell QsWindow mask](https://quickshell.org/docs/v0.3.0/types/Quickshell/QsWindow/)
- `ShellScreen` 提供逻辑像素坐标 `x/y/width/height`，可与 KWin 的窗口 frame geometry 建立统一的全局逻辑坐标系。[Quickshell ShellScreen](https://quickshell.org/docs/v0.3.0/types/Quickshell/ShellScreen/)
- KWin 6 脚本接口提供 `frameGeometry`、`frameGeometryChanged`、`outputChanged`、`fullScreen`、`maximizedChanged` 等信息，不需要猜测窗口位置。[KWin Scripting API](https://develop.kde.org/docs/plasma/kwin/api/)

## 5. 用户可见行为

### 5.1 始终显示模式

- 行为与当前版本完全一致。
- Dock 始终显示。
- `exclusiveZone` 继续保留 Dock 所需空间。
- 不显示小白条，不启动碰撞判断和隐藏计时器。

### 5.2 智能隐藏模式且没有窗口冲突

- Dock 保持完整显示。
- Dock 不永久占用工作区：`exclusiveZone = 0`，允许窗口移动到 Dock 区域；一旦相交，由智能隐藏接管。
- 桌面空白、所有窗口最小化、窗口位于其他虚拟桌面或其他屏幕时都属于“无冲突”。

### 5.3 智能隐藏模式下窗口进入 Dock 区域

1. 窗口几何进入 `dockAvoidanceRect`。
2. 等待 320ms 隐藏延迟，过滤拖动过程中的短暂擦边。
3. 如果指针不在 Dock 内、没有弹窗/编辑/拖拽抑制，则执行 220ms 隐藏动画。
4. Dock 基本离开屏幕后，小白条交叉淡入。
5. 应用窗口不会因每次隐藏/显示反复调整大小。

### 5.4 持续隐藏模式

- 不读取窗口碰撞结果；即使是空桌面、全部窗口最小化或没有打开任何应用，也保持隐藏。
- 从小白条唤醒后，只要指针仍位于 Dock 或存在 inhibitor，Dock 就保持显示。
- 指针离开 Dock 且 inhibitor 全部解除后等待 520ms，再执行隐藏动画。
- 从始终显示/智能隐藏切换到持续隐藏时，提供 700ms 模式切换宽限期，让用户看到设置已生效，然后收起。
- Quickshell 启动且已保存为持续隐藏时，初始直接进入 `Hidden`，不先闪出完整 Dock。
- 持续隐藏仍允许紧急窗口、快捷入口等显式 `requestReveal()` 临时显示，hold 结束后重新收起。

### 5.5 从小白条唤醒

- 底部白条视觉尺寸：`screen.width × 0.80` × `4` 逻辑像素。
- 左右侧白条视觉尺寸：`4` × `screen.height × 0.80` 逻辑像素。
- 白条沿对应屏幕边缘居中，屏幕尺寸变化时实时重新计算。
- 命中区域与白条长边相同，短边扩展到 14px：底部为 `80% 屏宽 × 14`，侧边为 `14 × 80% 屏高`。
- 指针进入命中区域后等待 90ms；仍在区域内则显示 Dock。
- 单击白条立即显示，不等待 90ms。
- 显示动画期间白条先淡出，Dock 再从边缘滑出。
- 指针进入 Dock 后一直保持显示。
- 指针离开 Dock 后：智能隐藏仅在窗口冲突仍存在时再次隐藏；持续隐藏则无条件再次隐藏。

### 5.6 全屏与最大化

- 同一屏幕的全屏窗口始终视为冲突。
- 最大化窗口由实际 `frameGeometry` 是否覆盖 `dockAvoidanceRect` 决定，不使用“只要有最大化窗口就隐藏”的粗略规则。
- 按当前产品要求，全屏时仍保留低透明度小白条；本期不自动彻底隐藏白条。
- 其他屏幕上的全屏或最大化窗口不能影响本屏 Dock。

### 5.7 编辑、菜单和弹窗

以下任一条件为真时，Dock 必须保持完整显示：

- 指针位于 Dock 内容内。
- `DockContainer.isEditing` 为真。
- 正在拖拽固定图标。
- `DockModelService.activeDockPopup !== null`。
- `AppLauncherService.open` 为真。
- Trash 菜单、窗口预览、音乐弹窗等已通过 `activeDockPopup` 协调器打开。
- Dock 正在处理外部拖放。
- 显示模式刚刚切换，正在进行安全过渡。

抑制条件解除后不立即消失，重新走 520ms 离开延迟。

### 5.8 紧急窗口

- 非全屏场景中，窗口从普通状态变为 `isUrgent` 时临时显示 Dock 2200ms，并保留原有图标提醒动画。
- 2200ms 后重新按当前显示模式计算是否隐藏。
- 全屏场景不强制把完整 Dock 盖在视频或游戏上，只让白条做一次轻微亮度脉冲。

## 6. 视觉与动画规范

### 6.1 单一动画进度

控制器只维护一个 `revealProgress`：

- `0.0`：Dock 完全隐藏。
- `1.0`：Dock 完全显示。
- 中间值：隐藏/显示动画进行中。

禁止分别给 `x`、`y`、`opacity`、`scale` 放置互相独立的 `Behavior`。所有视觉值必须由同一个 progress 派生，避免反向动画时不同步。

### 6.2 动画参数

| 参数 | 默认值 | 曲线 | 说明 |
|---|---:|---|---|
| 首次窗口冲突隐藏延迟 | 320ms | - | 过滤短暂擦边 |
| 切换到持续隐藏的宽限期 | 700ms | - | 让用户确认模式已生效 |
| 指针离开后隐藏延迟 | 520ms | - | 给用户返回 Dock 的余量 |
| 白条悬停显示延迟 | 90ms | - | 防止误触 |
| 隐藏动画 | 220ms | `Easing.InCubic` | 离场由慢到快 |
| 显示动画 | 260ms | `Easing.OutCubic` | 入场快速响应、柔和停稳 |
| 白条交叉淡入/淡出 | 140ms 等效区间 | progress 派生 | 不单独启动动画 |
| 启动数据等待上限 | 450ms | - | 等待配置与 KWin 初始快照 |

以上常量统一放入 `DockAnimation.qml`，不得散落在 UI 组件中。

### 6.3 位移公式

设 `p = revealProgress`，`hidden = 1 - p`：

```text
bottom: translateX = 0
        translateY = hidden * (dockHeight + edgeMargin + 2)

left:   translateX = -hidden * (dockWidth + edgeMargin + 2)
        translateY = 0

right:  translateX =  hidden * (dockWidth + edgeMargin + 2)
        translateY = 0
```

辅助视觉值：

```text
dockOpacity = 0.30 + 0.70 * p
dockScale   = 0.985 + 0.015 * p
handleOpacity = clamp((0.42 - p) / 0.24, 0, 1)
```

- `dockScale` 的 transform origin 必须靠近对应屏幕边缘；底部为 Bottom，左侧为 Left，右侧为 Right。
- Dock 主要靠裁剪和位移离场，opacity 只负责柔化边缘，不能用纯淡出替代位移。
- 动画中断时，从当前 `revealProgress` 继续反向，不重置到 0 或 1。

### 6.4 小白条

视觉规格：

```text
底部：round(screen.width × 0.80) × 4，radius 2，距物理屏幕边缘 6
侧边：4 × round(screen.height × 0.80)，radius 2，距物理屏幕边缘 6
颜色：rgba(255, 255, 255, 0.72)
悬停：rgba(255, 255, 255, 0.94)，scale 1.08
阴影：黑色 18% / 4px blur / 0,1 offset
```

- 白条长边严格取当前目标屏幕对应尺寸的 80%，不使用固定最小值或最大值。
- 白条与屏幕长边中心对齐；Dock 当前也是居中布局，两者中心一致。
- 白色是固定产品视觉，不跟随 Dock 图标染色。
- 在浅色壁纸上依靠细阴影保持可见，不增加不透明深色底板。
- 白条只负责显示和唤醒，不承载菜单、拖拽或滚轮操作。

## 7. 智能隐藏判定

### 7.1 稳定 Dock 矩形

必须用屏幕和 Dock 的静态尺寸直接计算完全显示时的矩形。禁止从 `dockWrapper.x/y`、动画 transform 或 `mapToItem` 采样。

```js
function visibleDockRect(screen, position, dockWidth, dockHeight, edgeMargin) {
    if (position === "bottom") {
        return {
            x: screen.x + (screen.width - dockWidth) / 2,
            y: screen.y + screen.height - edgeMargin - dockHeight,
            width: dockWidth,
            height: dockHeight
        }
    }
    if (position === "left") {
        return {
            x: screen.x + edgeMargin,
            y: screen.y + (screen.height - dockHeight) / 2,
            width: dockWidth,
            height: dockHeight
        }
    }
    return {
        x: screen.x + screen.width - edgeMargin - dockWidth,
        y: screen.y + (screen.height - dockHeight) / 2,
        width: dockWidth,
        height: dockHeight
    }
}
```

`dockAvoidanceRect` 是上述矩形向四周扩展 8px 后与当前屏幕矩形的交集。8px 容差可让窗口尚未直接压到玻璃边缘时就开始避让。

### 7.2 参与判定的窗口

窗口同时满足以下条件才参与碰撞：

1. 是普通可管理窗口；KWin bridge 当前 `includeWindow()` 过滤逻辑继续作为第一层。
2. 未最小化。
3. 位于当前虚拟桌面，或 `onAllDesktops === true`。
4. 位于 Dock 的目标屏幕，或其 `frameGeometry` 与目标屏幕相交。
5. 不是本 Shell 的 Dock、通知、Launcher、Settings 等特殊窗口。
6. `frameGeometry` 有效，宽高均大于 0。

全屏窗口只要与目标屏幕相交就强制视为冲突。

### 7.3 防抖与迟滞

- KWin 几何变化先由已有 snapshot 机制合并，控制器再以 80ms 的 reevaluate timer 合并连续变化。
- 进入冲突时使用扩展 8px 的 avoidance rect。
- 离开冲突时使用向外再扩展 16px 的 release rect，避免窗口边缘停在临界像素时 Dock 抖动。
- 状态没有实际变化时不得重启动画、不得重新赋值 models、不得写配置。

### 7.4 Provider 降级

本工程运行在 KDE/KWin 时，以 KWin bridge 的几何为权威。若未来在其他 compositor 上只拿到 foreign-toplevel 而没有 geometry：

- 全屏窗口仍可按 `fullscreen + screens` 判断。
- 普通窗口不得猜测绝对位置。
- 降级策略为“仅同屏全屏时隐藏”，并记录一次 warning。
- 不允许用 active window 是否存在代替碰撞判断，否则桌面上任意小窗口都会错误隐藏 Dock。

## 8. 状态机

### 8.1 状态

```text
Bootstrapping  等待配置；智能模式还等待窗口初始快照，不播放错误的首次动画
Shown          完整显示
HidePending    当前显示策略要求隐藏，等待隐藏延迟
Hiding         revealProgress 正在趋近 0
Hidden         只显示小白条
RevealPending  指针位于白条，等待显示延迟
Showing        revealProgress 正在趋近 1
Held           存在编辑/弹窗/拖拽/Launcher 等抑制条件
```

### 8.2 核心派生值

```js
hasConflict = WindowService 与 dockAvoidanceRect 的判定结果
policyWantsHidden = visibilityMode === "persistent"
    || (visibilityMode === "smart" && hasConflict)
hasInhibitor = pointerInsideDock
    || isEditing
    || isDragging
    || activeDockPopup
    || appLauncherOpen
    || temporaryRevealHold

shouldBeVisible = visibilityMode === "always"
    || !policyWantsHidden
    || hasInhibitor
```

`hasConflict` 只影响 smart 模式；persistent 模式不得因为窗口消失、最小化或桌面变空而显示 Dock。

### 8.3 主要转换

| 当前状态 | 事件 | 新状态/动作 |
|---|---|---|
| Bootstrapping | mode=always | `Shown`，直接 p=1，不播放动画 |
| Bootstrapping | mode=smart 且无冲突 | `Showing`，p 从 0 到 1 |
| Bootstrapping | mode=smart 且有冲突 | `Hidden`，p=0，显示白条 |
| Bootstrapping | mode=persistent | `Hidden`，p=0，显示白条，不先闪出 Dock |
| Shown | `policyWantsHidden` 且无 inhibitor | `HidePending` |
| HidePending | policy 不再要求隐藏或 inhibitor 出现 | 取消 timer，回 `Shown/Held` |
| HidePending | timer 到期 | `Hiding` |
| Hiding | inhibitor 出现或 policy 不再要求隐藏 | 从当前 p 反向进入 `Showing` |
| Hiding | p 到 0 | `Hidden` |
| Hidden | 白条 hover | `RevealPending` |
| Hidden | 白条 click | 立即 `Showing` |
| RevealPending | hover 离开 | 回 `Hidden` |
| RevealPending | 90ms 到期 | `Showing` |
| Showing | p 到 1 且 inhibitor 存在 | `Held` |
| Showing | p 到 1 且 policy 要求隐藏 | `HidePending`，使用 520ms 延迟 |
| Held | inhibitor 全部解除 | `Shown` 后重新评估当前 mode |
| 任意状态 | mode 切到 always | 强制显示；显示完成后恢复 exclusive zone |
| 任意状态 | mode 切到 persistent | 取消碰撞依赖；700ms 后进入 `Hiding` |

### 8.4 反向动画要求

使用一个显式 `NumberAnimation` 驱动 progress：

```js
function animateTo(target) {
    progressAnimation.stop()
    progressAnimation.from = revealProgress
    progressAnimation.to = target
    progressAnimation.duration = scaledDurationForRemainingDistance(target)
    progressAnimation.easing.type = target > revealProgress
        ? DockAnimation.smartHideRevealEasing
        : DockAnimation.smartHideHideEasing
    progressAnimation.start()
}
```

动画剩余时长按剩余距离缩放，最低 70ms，防止快速来回时突然慢动作。

## 9. Wayland/Quickshell 窗口策略

### 9.1 surface 生命周期

- `DockWindow` 在智能隐藏和持续隐藏过程中始终 mapped。
- 不设置 `root.visible = false`。
- 不切换 `sourceComponent`。
- 不改变 anchors。
- Dock 位置设置仍沿用 `Dock.qml` 当前“每个边缘一个 Component，切换时重建 surface”的可靠方案。

### 9.2 surface 布局调整

当前 `edgeMargin` 放在 layer-shell `margins` 上。为了让白条真正靠近屏幕物理边缘，同时让 Dock 仍保留 5px 浮动距离，应改成：

- layer-shell 对应边缘 `margins = 0`。
- PanelWindow 的横向/纵向厚度包含 `dockThickness + edgeMargin`。
- `dockWrapper` 在 surface 内使用 5px 内边距靠近对应边缘。
- `DockRevealHandle` 单独在同一 surface 内距屏幕边缘 6px。

该调整不能通过绝对窗口坐标实现，只使用 anchors、margins 和局部 transform。

### 9.3 exclusive zone

```text
visibilityMode = "always":
    保持现有 exclusiveZone = dockThickness + edgeMargin

visibilityMode = "smart" 或 "persistent":
    exclusiveZone = 0
```

任一隐藏模式开启后，exclusive zone 在 Shown/Hidden 间保持 0，不能随动画逐帧变化。否则每次 Dock 出入都会让最大化窗口重新布局，产生明显跳动。

关闭设置时的顺序：

1. 停止隐藏计时器。
2. 把 Dock 动画显示到 p=1。
3. 动画完成后恢复原 exclusive zone。

### 9.4 输入 mask

`DockWindow.mask` 使用两个区域的并集：

1. 与 `dockWrapper` 共用同一局部 offset 的 `dockHitRegion`。
2. smart/persistent 模式激活时的 `revealHitTarget`。

`dockHitRegion` 是无视觉的 Item，其 `x/y/width/height` 只由 surface 内的静态停靠位置和 controller offset 算出，不做任何全局坐标映射。它与视觉 wrapper 使用相同的 offset，因此 Region 不需要理解 QML transform。隐藏后它已移出 surface，可点击范围自然只剩白条命中区；surface 其余透明部分全部点击穿透。mode 为 `always` 时，白条 hit target 的宽高必须为 0。

伪结构：

```qml
mask: Region {
    Region { item: dockHitRegion }
    Region { item: revealHitTarget }
}
```

如果运行中的 Quickshell 版本对动态 Item geometry 更新不及时，监听 `revealProgress` 并显式触发 Region 的 `changed()`；禁止退回全窗口输入区域。

## 10. 新组件设计

### 10.1 `DockAutoHideController.qml`

这是普通可实例化组件，不是 Singleton。原因是隐藏状态属于具体 screen + position 的 Dock surface；未来多屏每屏 Dock 时必须各自独立。

输入：

```qml
property string mode             // "always" | "smart" | "persistent"
property bool configReady
property bool windowDataReady
property string position
property var targetScreen
property real dockWidth
property real dockHeight
property real edgeMargin
property bool pointerInsideDock
property bool editing
property bool dragging
property bool popupOpen
property bool launcherOpen
```

输出：

```qml
readonly property string phase
property real revealProgress
readonly property bool hidden
readonly property bool handleActive
readonly property bool hasWindowConflict
readonly property real offsetX
readonly property real offsetY
readonly property real dockOpacity
readonly property real dockScale
readonly property real handleOpacity
```

方法：

```qml
function requestReveal(reason, holdMs)
function requestHideEvaluation(reason)
function handleEntered()
function handleExited()
function handleClicked()
function resetForScreenChange()
```

控制器负责状态、timer 和 progress；不得持久化配置，不得创建窗口，不得直接操作图标。

### 10.2 `DockRevealHandle.qml`

纯视觉与指针输入组件：

- 接收 `position`、`opacity`、`active`、`screenWidth`、`screenHeight`。
- bottom 模式派生 `visualWidth = round(screenWidth * 0.80)`、`visualHeight = 4`；side 模式派生 `visualWidth = 4`、`visualHeight = round(screenHeight * 0.80)`。
- 对外暴露只读的 `hitTarget` Item，供 `DockWindow.mask` 组合输入 Region；命中区域短边为 14px，长边与 visual 完全一致。
- 暴露 `entered()`、`exited()`、`clicked()` 信号。
- 内部分离 visual bar 与较大的透明 hit target。
- 不读取 `WindowService`、`ConfigService` 或 `DockModelService`。

### 10.3 `DockAutoHideMath.mjs`

存放可单元测试的纯函数：

```js
visibleDockRect(screenRect, position, dockSize, edgeMargin)
expandRect(rect, amount)
intersects(a, b)
windowEligible(window, screenName, currentDesktopId)
hasConflict(windows, avoidanceRect, releaseRect, previousConflict)
```

几何与策略不要直接散写在 QML property binding 中。

## 11. 窗口数据契约

### 11.1 KWin snapshot 新字段

每个窗口新增：

```json
{
  "geometry": { "x": 0, "y": 0, "width": 1920, "height": 1080 },
  "outputName": "DP-1",
  "maximized": true,
  "visible": true
}
```

采集来源：

- `geometry`：`window.frameGeometry`
- `outputName`：`window.output.name`，若 API 版本无该字段则为空字符串
- `maximized`：横向和纵向均最大化；需要兼容当前 KWin 暴露的 maximize 属性形态
- `visible`：优先 `window.visible`，缺失时由 minimized/desktop 状态派生

`watchWindow()` 新增监听：

```js
window.frameGeometryChanged.connect(scheduleSnapshot)
window.outputChanged.connect(scheduleSnapshot)
window.maximizedChanged.connect(scheduleSnapshot)
window.desktopsChanged.connect(scheduleSnapshot)
```

每个连接继续保持 defensive try/catch，不能因为某个旧 API 缺少信号导致整个 KWin bridge 停止。

### 11.2 `WindowService` 规范化记录

provider-neutral record 增加：

```js
geometry: { x, y, width, height } | null
screenName: string
isMaximized: bool
isVisible: bool
```

`_recordsEqual()` 必须比较这些字段，否则窗口移动时 `revision` 不会更新。公开：

```qml
readonly property bool providerReady
```

KWin 模式在收到首个 snapshot 后 ready；foreign 模式在首次 toplevel 收集完成后 ready。控制器只依赖规范化字段，不读取 `_kwinWindows` 或 KWin 原始对象。

## 12. 配置与迁移

### 12.1 配置字段

`DockConfigService.qml` 新增：

```qml
property string visibilityMode: "always"

function isValidVisibilityMode(value) {
    return value === "always" || value === "smart" || value === "persistent"
}

function updateVisibilityMode(rawMode) {
    const next = String(rawMode)
    if (!isValidVisibilityMode(next) || visibilityMode === next)
        return false
    visibilityMode = next
    scheduleSave()
    return true
}
```

JSON：

```json
{
  "version": 3,
  "visibilityMode": "always"
}
```

默认 `always`，确保升级后现有用户行为不突然改变。不得同时持久化多个 bool 开关，否则会产生“智能隐藏和持续隐藏同时为真”的非法状态。

### 12.2 迁移

- 若 v1/v2 配置没有该字段，使用 `always`。
- 若历史实验配置存在 `smartHideEnabled: true`，迁移为 `smart`。
- 若只有历史字段 `autoHide: true`，按传统 auto-hide 语义迁移为 `persistent`。
- `smartHideEnabled` 和 `autoHide` 同时为 true 时优先迁移为 `smart`，并输出一次 migration log。
- 非法字符串按 `always` 处理并输出一次 warning。
- 增加 `property bool ready: false`；无论读取成功、文件不存在或解析失败，load 流程结束时都设为 true。

## 13. `kos-settings` 设计

### 13.1 页面布局

在 Dock 页面新增一个完全独立的 Section。它不能并入现有“大小和位置”卡片，也不能并入“图标风格”卡片。建议放在“大小和位置”之后、“图标风格”之前：

```text
DOCK 显示
┌──────────────────────────────────────────────────────────┐
│  [图标]  显示方式   [始终显示 | 智能隐藏 | 持续隐藏]    │
├──────────────────────────────────────────────────────────┤
│          智能隐藏：仅在窗口占用 Dock 区域时收起          │
└──────────────────────────────────────────────────────────┘
```

选择“持续隐藏”后，说明文字切换为：

```text
持续隐藏：不使用 Dock 时始终收起
```

三种说明文字必须随当前模式切换：

```text
始终显示：Dock 始终显示并为应用窗口保留空间
智能隐藏：仅在窗口占用 Dock 区域时收起
持续隐藏：不使用 Dock 时始终收起
```

视觉要求：

- Section 标题、上下间距沿用现有“大小和位置”“图标风格”的样式，但必须拥有自己的标题和卡片边界。
- 卡片 radius、背景、左右 margin 与现有 Dock 设置卡片一致；模式行高 54px，说明行高 36px。
- 标题 14px，说明文字 11px。
- 图标使用蓝色 `#0a84ff`，active 颜色与 Dock 位置设置一致，不使用紫色。
- 直接复用已有的 `LiquidControls.LiquidNavBar`，三个互斥选项 id 分别为 `always`、`smart`、`persistent`，`accentColor: "#0a84ff"`。
- 不使用两个独立 Switch 表示 smart/persistent，避免产生冲突组合。
- 小白条是两种隐藏模式的固定组成部分，不提供关闭或尺寸选项。

### 13.2 IPC

Shell snapshot 增加：

```json
{ "visibilityMode": "smart" }
```

Shell IPC 增加：

```qml
function updateVisibilityMode(mode: string): string {
    ConfigService.updateVisibilityMode(mode)
    return snapshot()
}
```

C++ `SettingsBridge` 增加：

```cpp
Q_INVOKABLE QVariantMap updateDockVisibilityMode(const QString &mode);
```

调用参数只能是 `always`、`smart`、`persistent`。snapshot 解析为 QString，并在 C++ 与 QML 两端再次验证。设置页先等待 IPC 返回再用完整 snapshot 校正状态；失败时恢复服务端状态并显示现有错误提示。

## 14. 与现有交互的集成

### 14.1 Dock hover

在 `DockContainer` 根部增加 passive `HoverHandler`，公开：

```qml
readonly property bool pointerInside: dockHover.hovered
```

使用 passive handler，避免抢夺 `DockIcon`、音乐控件、拖拽和 MouseArea 的事件。

### 14.2 Popup 协调

继续以 `DockModelService.activeDockPopup` 为唯一临时 Dock surface 所有者。不要分别监听每个 popup 的 visible。这样未来新增 popup 自动获得隐藏抑制行为。

若发现某个 popup 未进入该协调器，应先修复 popup 生命周期，而不是在 AutoHideController 中增加组件名称特判。

### 14.3 App Launcher

- `AppLauncherService.open` 为真时强制显示 Dock。
- Launcher 从 Dock 唤起前，控制器应已处于 Shown/Held。
- Launcher 关闭后重新走离开延迟。
- Dock 的 `setDockPresentation()` 继续发布完整显示时的宽高，不能发布动画中被裁剪的尺寸。

### 14.4 位置切换

用户在 Settings 将 bottom 切换到 left/right 时：

1. `Dock.qml` 按现有机制销毁旧位置 surface、创建新位置 surface。
2. 新 controller 进入 Bootstrapping。
3. 用新位置的静态矩形重新计算冲突。
4. 不继承旧位置动画中的 progress。

## 15. 多屏、缩放和桌面切换

- Dock 仍沿用当前目标屏幕策略；智能隐藏不自行重新选择 screen。
- 所有尺寸使用 Qt/Quickshell 逻辑像素；不要乘 `devicePixelRatio` 后再与 KWin geometry 比较。
- `screen.x/y` 可以为负数，任何公式都不能假定主屏左上角是整个桌面的 `(0,0)`。
- 相邻屏幕可能让目标边缘不是真正的物理边界，因此白条必须可点击，不能只依赖“鼠标压力到边缘”。
- 屏幕移除时旧 `ShellScreen` 会失效；跟随 `Dock.qml` 的 Variants 生命周期销毁 controller。
- 屏幕新增、移除、分辨率或缩放变化后重新计算静态矩形，先停止动画，再按新屏状态恢复。
- 虚拟桌面切换后等待 KWin snapshot 稳定，再重新判断；其他桌面窗口不参与碰撞。

## 16. 性能与稳定性要求

1. 不增加高频全局轮询 timer。
2. 窗口几何变化走 KWin signal → snapshot debounce → WindowService revision → controller 80ms debounce。
3. 动画只更新一个 real progress，不在每帧遍历窗口列表；碰撞结果在动画开始前已经计算完成。
4. `BackgroundEffect.blurRegion` 继续绑定 `dockWrapper`，随 wrapper 位移；隐藏后不保留整块离屏 blur。
5. 不因隐藏/显示重新 publish App Launcher 几何。
6. 不因 progress 变化写 JSON、重建 model 或输出逐帧 debug 日志。
7. 日志只记录状态转换，例如：

```text
[DockAutoHide] Shown -> HidePending reason=window-overlap
[DockAutoHide] HidePending -> Hiding
[DockAutoHide] Hidden -> Showing reason=handle-hover
```

## 17. 开发顺序

### Phase 1：数据契约与纯逻辑

1. 扩展 KWin snapshot 几何字段和信号。
2. 扩展 `WindowService` 规范化记录和 `providerReady`。
3. 新增 `DockAutoHideMath.mjs` 与单元测试。
4. 验证 bottom/left/right 的静态 rect 和负坐标屏幕。

完成标准：不改 UI，测试可证明窗口过滤与碰撞判断正确。

### Phase 2：Dock 状态机与动画

1. 新增 `DockAutoHideController.qml`。
2. 新增 `DockRevealHandle.qml`。
3. 调整 `DockWindow` 内边距、surface 厚度、mask、exclusive zone。
4. `DockContainer` 暴露 hover/edit/drag 状态。
5. 接入 popup 与 launcher inhibitor。

完成标准：可在 QML 临时常量开启功能，三种位置行为正确且无点击遮挡。

### Phase 3：配置与 Settings

1. 配置升级 v3 和 legacy 迁移。
2. Shell IPC 增加 snapshot/update。
3. C++ SettingsBridge 增加字符串枚举 API。
4. `kos-settings` 新增独立“Dock 显示”Section 和三模式选择器。

完成标准：模式切换即时生效、重启保持、失败可回滚，smart/persistent 不会同时成立。

### Phase 4：抛光与回归

1. 紧急窗口临时显示。
2. 启动阶段无闪现。
3. 多屏、虚拟桌面、全屏、热插拔测试。
4. 运行 Quickshell live verification 和 crash log 检查。

## 18. 文件改动清单

### 新增

```text
desktop/modules/dock/DockAutoHideController.qml
desktop/modules/dock/DockRevealHandle.qml
desktop/modules/dock/DockAutoHideMath.mjs
desktop/modules/dock/test_autohide.mjs
```

### 修改

```text
desktop/modules/dock/qmldir
desktop/modules/dock/DockWindow.qml
desktop/modules/dock/DockContainer.qml
desktop/modules/dock/DockAnimation.qml
desktop/modules/dock/DockConfigService.qml
desktop/modules/dock/WindowService.qml
helpers/kwin-window-bridge/kwin/contents/code/main.js
desktop/DesktopEnvironment.qml
apps/settings/src/main.cpp
apps/settings/main.qml
```

原则上不修改：

```text
desktop/modules/dock/Dock.qml
desktop/modules/dock/DockIcon.qml
desktop/modules/dock/AdaptiveMath.mjs
desktop/modules/applauncher/AppLauncherWindow.qml
```

如开发时必须修改这些文件，应在提交说明中解释为什么现有接口不足，避免把隐藏逻辑扩散进图标或 Launcher 视觉组件。

## 19. 测试矩阵

### 19.1 自动化测试

`test_autohide.mjs` 至少覆盖：

- bottom/left/right 三种静态矩形。
- 主屏 `(0,0)`、左侧负 x 屏、上方负 y 屏。
- 100%、125%、150% 缩放下仍使用相同逻辑坐标规则。
- 窗口刚好接触、相交 1px、离开 release rect。
- 最小化窗口、其他桌面窗口、其他屏幕窗口被过滤。
- 全屏窗口强制冲突。
- geometry 缺失时不误判普通窗口。
- `always/smart/persistent` 三种 policy 的 `shouldBeVisible` 真值组合。
- bottom 白条宽度为屏宽 80%，side 白条高度为屏高 80%。

### 19.2 手工行为测试

| 场景 | 预期 |
|---|---|
| mode=always | 行为与当前 Dock 一致，保留工作区，不显示白条 |
| mode=smart，空桌面 | Dock 保持显示 |
| 小窗口不接触 Dock | Dock 保持显示 |
| 拖动窗口轻擦 Dock 后马上离开 | 320ms 防抖，不隐藏 |
| 窗口覆盖 Dock 区域 | 平滑隐藏，白条出现 |
| mode=persistent，空桌面 | 宽限期后仍然隐藏 |
| mode=persistent，全部窗口最小化 | 继续隐藏，不受碰撞状态影响 |
| persistent 从白条唤醒后移开指针 | 520ms 后再次隐藏 |
| hover 白条 | 90ms 后平滑显示 |
| 点击白条 | 立即平滑显示 |
| 指针停在 Dock | 不隐藏 |
| 右键菜单/窗口预览/音乐弹窗 | 整个交互期间不隐藏 |
| App Launcher 打开 | 不隐藏；关闭后重新判断 |
| 图标编辑/拖拽 | 不隐藏，不中断拖拽 |
| 最大化窗口 | 当前屏 Dock 隐藏 |
| 全屏视频/游戏 | Dock 隐藏，白条保持低干扰可见 |
| mode=smart，最小化全部窗口 | Dock 自动显示 |
| mode=smart，切换虚拟桌面 | 只按新桌面窗口判断 |
| mode=smart，另一屏最大化 | 不影响 Dock 所在屏 |
| bottom/left/right 切换 | 方向正确，无反向飞入 |
| 快速来回 hover 白条 | 动画从当前进度反向，无跳帧 |
| 重启时已有最大化窗口 | 不先闪出完整 Dock |
| 断开/接回目标屏幕 | 无 dangling screen 错误，状态恢复 |

### 19.3 点击穿透测试

使用最大化应用验证：

- Dock 隐藏时，除底部 `80% 屏宽 × 14` 或侧边 `14 × 80% 屏高` 的白条命中区外，原 Dock surface 范围均可点击应用。
- 右侧 Dock 隐藏后，不阻挡应用垂直滚动条。
- 底部 Dock 隐藏后，不阻挡播放器进度条、浏览器底部控件或窗口 resize edge。
- 左侧 Dock 隐藏后，不阻挡窗口左侧 resize edge。

## 20. 验收标准

以下条件全部满足才算功能完成：

1. `kos-settings` 中有独立的“Dock 显示”Section，可选择始终显示、智能隐藏、持续隐藏，默认始终显示，重启后保持。
2. 三种模式是互斥枚举，不存在 smart/persistent 同时开启的状态。
3. 智能隐藏是窗口碰撞驱动，而不是“有任意窗口就隐藏”；空桌面或不相交窗口时显示，相交、最大化覆盖、全屏时隐藏。
4. 持续隐藏不依赖窗口碰撞；没有窗口、全部最小化或桌面空闲时仍保持隐藏。
5. 三种 Dock 位置动画方向和静态碰撞矩形正确。
6. 底部白条宽度始终为目标屏幕宽度 80%，侧边白条高度始终为目标屏幕高度 80%，厚度均为 4px，并可 hover/click 唤醒。
7. 隐藏 220ms、显示 260ms 左右，动画可随时从当前进度反向，无跳变。
8. hide/show 不创建或销毁 Dock surface，不触发 Quickshell reload。
9. smart/persistent 模式期间 `exclusiveZone` 恒为 0；hide/show 不导致应用窗口反复 reflow。
10. 透明区域点击穿透，仅 Dock 可见部分和白条命中区拦截输入。
11. 编辑、拖拽、Popup、App Launcher 期间 Dock 不隐藏。
12. 碰撞判断使用完全显示时的静态矩形，不读取动画 transform 后的位置。
13. 其他屏幕、其他虚拟桌面、最小化窗口不误触发智能模式；持续模式不依赖这些窗口状态。
14. 没有新增持续高频轮询，没有逐帧日志，没有明显 CPU/GPU 空闲开销增长。
15. 连续切换模式 30 次、连续唤醒/隐藏 100 次、快速切换三种位置后 Quickshell 不崩溃。

## 21. 禁止实现清单

后续 AI 开发时不得采用以下捷径：

- `DockWindow.visible = !hidden`。
- 隐藏时把 `implicitHeight/implicitWidth` 缩成白条尺寸。
- 每次隐藏创建一个白条窗口、显示时销毁该窗口。
- 用 `mapToGlobal()`/`mapToItem()` 读取动画中 Dock 坐标作为碰撞目标。
- 每帧或每 16ms 遍历所有 KWin 窗口。
- 在 `DockIcon.qml` 内分别维护隐藏状态。
- Popup 打开后靠固定延迟猜测何时关闭。
- hide/show 时动态切换 layer-shell anchors 或不断修改 exclusive zone。
- geometry 不可用时用“存在活动窗口”冒充智能碰撞。
- 为 bottom/left/right 复制三套状态机。

这些做法会重新引入 surface 重建、绝对坐标、输入遮挡、窗口跳动或多状态竞态问题，与本设计目标相违背。
