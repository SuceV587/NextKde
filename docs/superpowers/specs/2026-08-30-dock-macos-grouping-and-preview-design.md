# macOS 风格 Dock 应用多窗口聚合、画中画预览与新建窗口（+）设计规范

## 1. 概述与目标

在 NextKde Dock 中实现标准的 macOS 风格应用窗口管理体验：
1. **应用聚合（App Grouping）**：同一个应用程序无论打开多少个窗口，在 Dock 上始终只显示一个图标。固定应用（Pinned）启动后常驻固定位置；未固定应用在运行区聚合展示。
2. **多窗口悬停画中画预览（Multi-Window Live Preview）**：鼠标悬停在应用图标上时，浮窗横向平铺展示该应用名下所有窗口的实时 KWin 缩略图、标题及独立的 `×` 关闭按钮。
3. **加号新建窗口（＋ New Window）**：在预览卡片右侧提供显式的 `＋` 新建窗口操作卡片，点击即可快速派生该应用的新实例。
4. **macOS 风格点击与激活**：点击未在前台的应用激活其 MRU（最近使用）窗口并置顶；点击已在前台的应用在多窗口间循环切换。
5. **配置项兼容**：在 `DockConfigService` 中提供 `windowGrouping` 配置项（默认 `"grouped"`，支持 `"separate"` 回退）。

---

## 2. 架构与组件设计

### 2.1 配置层 (`DockConfigService.qml`)
* 新增配置项：
  ```qml
  property string windowGrouping: "grouped" // "grouped" | "separate"
  ```
* 持久化到 `~/.local/state/quickshell/dock/config.json`（Schema v3 兼容字段扩充）。

### 2.2 数据模型层 (`DockModelService.qml`)
* 在 `windowGrouping === "grouped"` 模式下：
  * `_refreshPinned()`：
    * 遍历固定项时，固定图标始终保留在固定槽位（移除 `if (windows.length > 0) continue;` 的隐藏逻辑）。
    * 注入 `windows` 列表、`windowCount`、`isRunning`（`windows.length > 0`）、`isActivated`（`windows.some(w => w.toplevel.activated)`）。
  * `_refreshWindowItems()`：
    * 将未固定的所有运行窗口按 `record.identity.desktopId` 进行聚合。
    * 每个未固定应用在 `windowModel` 中仅对应一条记录，包含 `desktopId`、`name`、`icon`、`windows` 数组、`isActivated`、`isUrgent` 等。
  * 窗口与应用动作：
    * `activateApp(appId)`：
      - 0 个窗口：调用 `prepareLaunch` + `AppActionService.launch`；
      - 1 个窗口：未激活则激活，已激活则最小化；
      - 多个窗口：若该应用未激活，激活其 MRU 窗口；若该应用已激活，依次循环切换到下一个窗口。
    * `launchNewWindow(appId)`：直接调用 `AppActionService.launch(AppIdentityService.resolve(appId))`。
    * `closeWindow(windowId)`：调用 `WindowService.closeWindow(windowId)`。

### 2.3 多窗口预览浮窗 (`DockWindowPreview.qml`)
* 升级为支持单个或多个窗口的横向平铺展示：
  * **容器尺寸计算**：根据 `windows.length` 动态计算宽度 `Math.min(screenWidth * 0.85, (cardWidth + spacing) * (windows.length + 1) + padding)`。
  * **单窗口卡片（Window Card）**：
    * 实时 KWin 缩略图（`WindowService.thumbnailUrl(windowId)`）。
    * 窗口标题（单行省略，阴影描边）。
    * 右上角浮现式 `×` 关闭按钮（鼠标悬停卡片时展现，点击关闭该窗口并阻止事件冒泡）。
    * 悬停高亮动效（边缘发光、轻微抬升）。
    * 单击卡片：激活对应窗口并自动隐藏预览浮窗。
  * **新建窗口卡片（New Window '+' Card）**：
    * 玻璃材质加号按钮（带有 `＋` 图标与「新建窗口」提示）。
    * 单击卡片：调用 `DockModelService.launchNewWindow(appId)`，并隐藏浮窗。

### 2.4 Dock 图标与容器适配 (`DockIcon.qml`, `DockContainer.qml`)
* `DockIcon.qml`：
  * 悬停计时器触发时，将该应用关联的 `windows` 数组传递给 `DockWindowPreview`。
  * 运行指示灯：多窗口时指示灯常亮；
  * 右键菜单：增加「新建窗口」动作。
* `AdaptiveMath.mjs`：
  * 确保图标计数以聚合后的应用数量为准进行自适应尺寸计算。

---

## 3. 错误处理与边缘情况

1. **窗口全关闭后的浮窗行为**：当在预览浮窗中点击 `×` 关闭最后一个窗口时，浮窗检测到 `windows.length === 0` 自动快速淡出关闭。
2. **多屏幕与边界防溢出**：浮窗使用 `clamp` 确保水平中心对齐 Dock 图标的同时，左右两侧不超出屏幕边界。
3. **缩略图加载中状态**：若 KWin 缩略图尚未就绪，展示应用默认图标 + "正在获取预览…"。

---

## 4. 验证计划

1. **单元测试与静态检查**：运行 `node desktop/modules/dock/test_adaptive.mjs` 验证几何布局。
2. **多窗口行为验证**：
   - 启动多个终端或浏览器窗口，验证 Dock 上仅占 1 个图标位置。
   - 鼠标光标悬停在图标上，验证预览浮窗展示横排多张缩略图与加号。
   - 点击预览中的加号 `+`，验证成功拉起应用新窗口。
   - 点击卡片上的 `×`，验证成功关闭对应单个窗口。
   - 点击卡片自身，验证对应窗口置顶激活。
