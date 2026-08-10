# 通知系统升级方案

## 目标

在现有单条通知弹窗的基础上,升级为完整的通知系统:

1. **分组叠加 + 展开**:同一 `desktopEntry` 的多条通知叠成一张卡片,点击展开
2. **操作按钮(actions)**:通知上显示可点击的 action 按钮
3. **内联回复(inline reply)**:聊天类通知直接输入文字回复
4. **紧急通知特殊样式**:Critical 级别用红色高亮
5. **通知中心历史记录**:ControlCenter 里保留通知历史列表

## 现状

### 数据模型

- `NotificationCenter.qml` 的 `NotificationServer.trackedNotifications` 是 Quickshell 的 `UntypedObjectModel`(只读、append-only、不可排序/过滤/分组)
- 每个 `Notification` 对象属性(全 readonly,除 `tracked`):
  - `id` (uint, constant) — 稳定标识,适合做分组 key
  - `appName`, `appIcon`, `summary`, `body`, `image`, `desktopEntry`, `expireTimeout`
  - `urgency` (enum: Low=0, Normal=1, Critical=2)
  - `actions` (QList<NotificationAction*>,每个有 `identifier`/`text`/`invoke()`)
  - `hasInlineReply`, `inlineReplyPlaceholder`, `sendInlineReply(replyText)`
  - `tracked` (bool, 读写), `expire()`, `dismiss()`
- 当前 `Repeater` 直接绑 `trackedNotifications`,手写 y 定位做 newest-on-top
- **无法在 Repeater 层做分组**:模型不可改

### 当前能力开关

`NotificationCenter.qml:14-28`:
```
actionsSupported: false       // 需改为 true
inlineReplySupported: 未设置   // 需设为 true
```

### 当前 UI

`NotificationWindow.qml`:
- 右上角 `PanelWindow`,350px 宽,固定高度(屏幕高度 - 60)
- `Repeater` + 手写 y 定位,newest-on-top
- 自渲染卡片(深色半透明 + 渐变高光 + 描边),radius 28
- 入场:opacity(0->1) + x(120->0),200ms InCubic
- 出场:x(0->width+44),200ms InCubic
- 无 actions UI,无 inline reply UI,无 urgency 样式区分
- 不使用 WallpaperPaletteService / ThemeService(硬编码颜色)

### ControlCenter 现状

- 只有 DND 开关(`ControlCenterService.doNotDisturbEnabled` + `ControlCenterPanel.qml:389-431` 的 dndButton)
- 无通知历史列表,无 `trackedNotifications` 引用

---

## 架构设计

### 分层

```
NotificationServer (Quickshell, 只读)
    │ trackedNotifications
    ▼
NotificationGroupService (新建,分组模型层)
    │ 按桌面项分组 + 维护展开状态 + 维护历史
    ▼
NotificationWindow (弹窗,重构为 ListView)
NotificationHistoryPanel (新建,ControlCenter 内的通知历史)
```

### 新建:NotificationGroupService.qml

位置:`modules/notifications/NotificationGroupService.qml`
注册:`modules/notifications/qmldir` 加 `NotificationGroupService 1.0`

**职责**:监听 `trackedNotifications`,按 `desktopEntry`(fallback `appName`)分组,输出一个 `ListModel` 供 UI 消费。

**数据结构**(ListModel 每行 = 一个分组):
```js
{
    groupKey: "org.kde.konsole.desktop",     // desktopEntry || appName
    appName: "Konsole",
    appIcon: "utilities-terminal",
    notifications: [<Notification 对象引用>, ...],  // 该组所有通知,最新在前
    count: 3,
    collapsed: true,                          // 是否折叠(叠加显示)
    latestSummary: "构建完成",                 // 最新一条的 summary(折叠态预览)
    latestBody: "...",
    latestUrgency: 1,                         // 最新一条的 urgency
    hasActions: false,                        // 最新一条是否有 actions
    hasInlineReply: false,
    expandedHeight: 0,                        // 展开后的预估高度(可选,供布局用)
}
```

**核心逻辑**:
- 用隐藏 `Repeater`(参考 `WindowService.qml` / `DockMprisService.qml` 的先例)监听 `trackedNotifications` 的增删
- 新通知到达:找对应 `groupKey` 的行 -> 存在则 `append` 到 `notifications` 并更新预览;不存在则新建一行
- 通知移除:从对应行的 `notifications` 数组移除;数组空了则移除该行
- 分组排序:按最新通知到达时间倒序(最新组在最上)
- 展开状态:`collapsed` 由 UI 点击切换,Service 只存状态

**分组依据**:优先 `desktopEntry`;为空时 fallback 到 `appName`;都为空用一个固定 key `"unknown"`。这样比纯 appName 精确(同一 .desktop 文件才算同 app),又能处理不提供 desktopEntry 的通知。

**历史记录**:Service 额外维护一个 `historyModel`(ListModel),每条通知 dismiss/expire 时,先把它的快照(不是对象引用,因为对象会被销毁)push 进 historyModel,保留最近 N 条(如 50)。ControlCenter 的历史面板消费这个 model。

### 重构:NotificationWindow.qml

从 `Repeater` 迁移到 `ListView`:

```qml
ListView {
    id: notificationList
    model: NotificationGroupService.groupsModel   // 分组后的 ListModel
    spacing: 10
    orientation: ListView.Vertical

    // 入场:分组新增时淡入 + 轻微下滑
    add: Transition { ... }
    // 出场:分组移除时滑出
    remove: Transition { ... }
    // 重排:展开/折叠时下方分组平滑位移(关键!)
    displaced: Transition {
        NumberAnimation { properties: "y"; duration: 200; easing.type: Easing.InOutCubic }
    }
}
```

**delegate(分组卡片)**:
- **折叠态**:显示 app 图标 + appName + 最新一条 summary/body + `"(3)"` 计数角标
- **展开态**:顶部仍是 app 头,下方列出该组所有通知(内层 `ListView` 或 `Column`)
- 点击卡片头部切换 `collapsed`
- 每条通知(展开态)下方渲染 action 按钮(如有)
- 每条通知(展开态)渲染 inline reply 输入框(如 `hasInlineReply`)

**动画**:
- 入场:opacity(0->1) + x(120->0),200ms InCubic(沿用已验证的方案)
- 出场:x(0->width+44),200ms InCubic(沿用)
- 展开/折叠:`displaced` Transition 处理下方卡片位移;内层通知用 `add`/`remove` Transition 淡入淡出
- 入场动画期间窗口高度恒定(已解决,保留固定 `implicitHeight`)

### 新建:NotificationHistoryPanel.qml

位置:`modules/notifications/NotificationHistoryPanel.qml`(或直接嵌入 ControlCenterPanel)
注册:`modules/notifications/qmldir`

**职责**:在 ControlCenter 里显示通知历史列表。
- 消费 `NotificationGroupService.historyModel`
- 每条显示 app 图标 + appName + summary + 时间戳
- 点击可重新触发(如果支持)或仅查看
- 清空按钮

### 修改:NotificationCenter.qml

```qml
NotificationServer {
    id: server
    actionsSupported: true          // was false
    inlineReplySupported: true      // was unset
    // ...其余不变
}
```

---

## 功能详细设计

### 1. 分组叠加 + 展开

**折叠态显示**:
- app 图标 + appName
- 最新一条的 summary(标题)+ body(正文,最多 2 行)
- 右上角计数角标 `count`(count > 1 时显示)
- 整张卡片可点击切换展开

**展开态显示**:
- 顶部:app 图标 + appName + 折叠按钮(向上箭头)
- 下方:该组所有通知,每条独立显示(图标可选、summary、body、时间)
- 最新一条在最上
- 每条可有独立的 action 按钮 / inline reply

**动画**:
- 展开:内层通知从 0 高度增长 + 淡入;下方分组通过 `displaced` Transition 平滑下移
- 折叠:反向

**边界**:
- 单条通知(count=1)也走分组模型,但折叠态和展开态视觉一致(不显示计数角标,不可折叠或折叠无意义)
- 不同 app 的通知永远分属不同分组,不跨 app 合并

### 2. 操作按钮(actions)

**显示条件**:`notification.actions.length > 0`
**渲染**:在每条通知底部,横向排列按钮(参考 macOS 通知)
**样式**:半透明圆角按钮,文字居中,hover 高亮
**点击**:`action.invoke()` -> 通知自动 dismiss(取决于 notification.resident)
**`hasActionIcons`**:如果为 true,用图标按钮代替文字(用 action.identifier 映射图标名);先实现文字版,图标版作为后续增强

### 3. 内联回复(inline reply)

**显示条件**:`notification.hasInlineReply == true`
**渲染**:在通知底部(actions 下方或替代 actions)放一个 `TextField`
- placeholder 用 `notification.inlineReplyPlaceholder`
- 回车提交:`notification.sendInlineReply(text)` -> 清空输入框 -> dismiss 通知
- 提交后通知是否消失取决于 `notification.resident`;默认消失
**样式**:半透明背景圆角输入框,白色文字

### 4. 紧急通知特殊样式

**Critical 级别**(`notification.urgency == NotificationUrgency.Critical`):
- 卡片左侧加一条 3px 红色竖条(`#ff453a`,参考 ControlCenterPanel logout 确认按钮的红色)
- 或:卡片底色偏红(`Qt.rgba(0.20, 0.08, 0.08, 0.62)`)
- app 名/标题可加微弱红色 tint
**Low 级别**:可降低不透明度(0.85),视觉弱化
**Normal**:当前样式不变

**分组态**:分组卡片的 urgency 取最新一条;展开后每条独立显示自己的 urgency 样式

### 5. 通知中心历史记录

**数据源**:`NotificationGroupService.historyModel`
**存储**:dismiss/expire 时把通知快照(id, appName, appIcon, summary, body, urgency, timestamp)存入 historyModel;保留最近 50 条;超出则移除最旧
**UI**(嵌入 ControlCenterPanel 或独立面板):
- 标题"通知历史" + 清空按钮
- ListView 列出历史通知:app 图标 + appName + summary + 相对时间("3分钟前")
- 点击展开看 body
- 不支持重新触发(快照无对象引用);仅查看
**持久化**(可选增强):用 QML `LocalStorage` 或写文件,跨重启保留。先做内存版。

---

## 实施计划(分阶段)

### 阶段 1:分组模型层(基础设施)

- 新建 `NotificationGroupService.qml`:监听 `trackedNotifications` -> 分组 ListModel
- 新建 qmldir 注册
- **此阶段不改 UI**:`NotificationWindow` 仍用 Repeater,但改绑 `NotificationGroupService` 输出的扁平列表(分组但全部 collapsed=false,视觉上和现在一致)
- 验证:热重载,通知正常显示,分组逻辑正确

### 阶段 2:Repeater -> ListView 迁移

- `NotificationWindow` 从 Repeater 迁到 ListView
- 加 `add`/`remove`/`displaced` Transition
- 删手写 y 绑定,改用 ListView 内置布局
- 验证:入场/出场/重排动画流畅,多卡布局正确

### 阶段 3:分组叠加 + 展开 UI

- delegate 实现折叠态/展开态切换
- 计数角标
- 展开/折叠动画
- 验证:同 app 多条通知正确叠加,点击展开,展开/折叠动画流畅

### 阶段 4:操作按钮 + 内联回复

- `NotificationCenter.qml` 开启 `actionsSupported`/`inlineReplySupported`
- delegate 渲染 action 按钮
- delegate 渲染 inline reply TextField
- 验证:发一条带 actions 的测试通知,按钮可点击;发一条带 inline reply 的测试通知,可回复

### 阶段 5:紧急通知样式 + 历史记录

- urgency 样式区分(Critical 红色竖条)
- `NotificationGroupService` 加 historyModel
- ControlCenterPanel 嵌入通知历史面板
- 验证:Critical 通知红色高亮;dismiss 后出现在历史列表;清空按钮可用

---

## 风险与注意事项

1. **分组模型正确性**:隐藏 Repeater 监听 `trackedNotifications` 的增删信号必须可靠;Dock 的 `WindowService`/`DockMprisService` 是成熟先例,但仍需仔细处理"通知对象属性变化"(如 body 更新)的场景。
2. **ListView displaced 动画与分组展开冲突**:展开一个分组时,`displaced` 会让下方分组下移;如果展开动画本身也在改高度,两者可能打架。需要让高度变化通过 `Behavior on height` 或内层 `ListView` 的 `add`/`remove` Transition 驱动,而非直接跳变。
3. **inline reply 的键盘焦点**:TextField 在 `PanelWindow`(非 focusable)里可能拿不到键盘焦点。可能需要设 `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive` 或 `OnDemand`。这是 Wayland 层面的约束,需要验证。
4. **历史记录内存占用**:通知快照(尤其带 image 的)占内存;限制 50 条 + 不存 image(只存 icon 路径)可控制。
5. **性能**:分组模型每次有通知增删都要 diff 更新 ListModel;参考 `DockModelService._setWindowItems` 的 in-place diff 模式,避免全量重建。
6. **向后兼容**:阶段 1 完成前 UI 不变;每个阶段都可独立验证和回退。

---

## 不改动

- `NotificationServer` 的 DND 逻辑(`NotificationCenter.qml:23-27`)
- 屏幕选择逻辑(`NotificationCenter.qml:11-13`,screen index 1)
- 现有的入场/出场动画参数(opacity+x 入场,x 出场,200ms InCubic)— 已验证流畅,沿用
- 自渲染卡片背景方案(深色半透明 + 渐变 + 描边)— 已验证无锯齿,沿用
- dock / applauncher / 其他面板 — 不动
