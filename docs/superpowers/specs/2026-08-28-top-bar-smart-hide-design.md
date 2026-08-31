# 顶部状态栏智能隐藏功能设计规范 (Top Bar Smart Hide Spec)

- **创建日期**: 2026-08-28
- **状态**: 已确认 (Approved)
- **目标**: 为 NextKde 顶部状态栏（Bar）增加与 Dock 对齐的三档显示与智能隐藏功能（始终显示 / 智能隐藏 / 持续隐藏），提升全屏与大窗口使用时的桌面利用率与沉浸感。

---

## 1. 概述与核心功能

为顶部 Bar 引入与 Dock 架构一致的自适应显示控制器（Auto-Hide Controller），实现：
1. **三种显示模式**：
   - `always` (始终显示)：独占屏幕顶部 35px 区域（`exclusiveZone = 35`），最大化窗口不遮挡。
   - `smart` (智能隐藏)：在桌面无冲突窗口时保持常驻；当有窗口靠近/重叠顶部状态栏区域或窗口全屏时，平滑向上收起隐藏；`exclusiveZone = 0`，最大化窗口扩展至屏幕顶端。
   - `persistent` (持续隐藏)：默认向上收起隐藏，仅在鼠标触顶或交互时呼出。
2. **隐形触顶感应**：
   - 隐藏状态下，顶部保留极窄感应区（y ≤ 2px），鼠标移至最顶端停留（100ms）后平滑展开，移出后延时 300ms 收起。
3. **交互保护机制（Inhibitors）**：
   - 鼠标悬停在 Bar 内、打开控制中心/网络/蓝牙面板、或唤起全局搜索与启动器时，Bar 强制保持展开，禁止自动收起。
4. **Wayland Input Mask 穿透**：
   - 隐藏时精确裁剪 Wayland input mask，全屏窗口顶部的标签栏与标题栏可正常点击交互。
5. **设置中心（kos-settings）集成**：
   - 在「主题」页面「BAR 布局」中提供 `[ 始终显示 | 智能隐藏 | 持续隐藏 ]` 分段切换，即时生效并持久化存储。

---

## 2. 架构与模块设计

### 2.1 碰撞与数学模型 (`shell/desktop/modules/dock/DockAutoHideMath.mjs` / `shell/desktop/modules/bar/BarAutoHideMath.mjs`)
- **静态完全可见包围盒 (`visibleBarRect`)**：
  ```js
  visibleBarRect(screenRect, barHeight, edgeMargin) = {
      x: screenRect.x + edgeMargin,
      y: screenRect.y,
      width: screenRect.width - edgeMargin * 2,
      height: barHeight
  }
  ```
- **滞后回差算法 (Hysteresis)**：
  - `avoidanceRect`：向外扩展 8px，窗口进入时触发冲突（`hasConflict = true`）。
  - `releaseRect`：向外扩展 16px，已处于冲突状态时，窗口需彻底离开 16px 外才清除冲突（`hasConflict = false`）。
- **窗口资格过滤 (`windowEligible`)**：
  - 过滤最小化窗口、非当前工作区窗口及尺寸为 0 的异常窗口。
  - 当前屏幕全屏窗口（`isFullscreen`）无条件触发冲突。

### 2.2 状态机控制器 (`shell/desktop/modules/bar/BarAutoHideController.qml`)
- **生命周期阶段**：
  - `Bootstrapping` -> `Shown` / `Hidden`（启动静默判断，避免开机闪烁）
  - `Shown` -> `HidePending` (延时 300ms) -> `Hiding` (动画向上平移) -> `Hidden`
  - `Hidden` -> `RevealPending` (触顶悬停 100ms) -> `Showing` (动画向下滑出) -> `Shown`
  - `Held` (有抑制器时锁定展开)
- **单值动画派生**：
  - 由唯一的 `revealProgress` (0.0 ~ 1.0) 派生 `offsetY = -(1 - revealProgress) * (barHeight + 2)`、`opacity = 0.2 + 0.8 * revealProgress`。

### 2.3 窗口层与输入裁切 (`shell/desktop/modules/bar/BarWindow.qml`)
- **Exclusive Zone**：
  - `exclusiveZone = (mode === "always" && barEnabled) ? barHeight : 0`
- **触顶隐形热区**：
  - 顶部 2px 高度的透明感应区域，捕获鼠标悬停信号 `onEntered` / `onExited`。
- **Mask 遮罩**：
  - 仅将 `barContentRegion` 与 `topHoverRegion` 纳入 Wayland Mask，透明空白区穿透至底层客户端窗口。

### 2.4 配置持久化与 IPC (`shell/desktop/modules/common/AppearanceConfigService.qml` & `DesktopEnvironment.qml`)
- `AppearanceConfigService` 新增 `barVisibilityMode: "always" | "smart" | "persistent"`，默认 `"always"`。
- 保存至 `$XDG_STATE_HOME/quickshell/appearance/config.json`。
- `appearance-settings` IPC 新增 `updateBarVisibilityMode(mode: string)` 与快照字段。

### 2.5 设置应用联动 (`apps/settings`)
- `apps/settings/src/main.cpp` 中 `SettingsBridge` 新增 `updateBarVisibilityMode` 接口。
- `apps/settings/main.qml` 在「主题」页面「BAR 布局」添加 `SettingsNavBar` 分段选项卡。

---

## 3. 测试与验证计划

1. **单元测试**：
   - 扩展 `test_autohide.mjs`，增加顶部 Bar 区域碰撞计算、入场/退场回差测试用例。
   - 运行 `node shell/desktop/modules/dock/test_autohide.mjs` 确保全部用例通过。
2. **QML 语法与静态检查**：
   - 运行 `git diff --check` 和 `qmllint` 验证无语法及属性绑定问题。
3. **集成与运行时验证 (Verify Skill)**：
   - 启动 Quickshell 实例观察 Bar 加载日志。
   - 打开最大化/全屏窗口，验证 Bar 智能避让与收起。
   - 鼠标移至顶部 y ≤ 2px，验证 Bar 平滑呼出；移出后延时收起。
   - 打开控制中心与网络面板，验证 Bar 锁定不收起。
   - 打开 `kos-settings` 切换显示方式，验证即时响应与配置持久化保存。
