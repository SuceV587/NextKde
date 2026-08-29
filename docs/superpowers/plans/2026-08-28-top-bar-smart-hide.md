# 顶部状态栏智能隐藏功能实施计划 (Top Bar Smart Hide Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 NextKde 顶部状态栏（Bar）实现三档显示与智能隐藏模式（始终显示 / 智能隐藏 / 持续隐藏），包含触顶隐形呼出、防抖动滞后计算、交互抑制器保护以及在设置中心（kos-settings）中的可视化配置。

**Architecture:** 
1. 扩展 `DockAutoHideMath.mjs` 算法支持顶部区域碰撞计算与 8px/16px 进退滞后回差。
2. 新建 `desktop/modules/bar/BarAutoHideController.qml` 状态机控制器，管理生命周期阶段、延迟定时器与单值 `revealProgress` 驱动的位移与渐变。
3. 重构 `BarWindow.qml`：在智能/持续隐藏模式下动态管理 `exclusiveZone = 0`，加入顶部 2px 触顶感应带与 Wayland input mask 裁切。
4. 在 `AppearanceConfigService`、`DesktopEnvironment` IPC 与 `kos-settings` 增加 `barVisibilityMode` 配置持久化与界面控制。

**Tech Stack:** Quickshell v0.3.0, Qt 6 QML/JavaScript, C++ (SettingsBridge), Node.js (test harness).

## Global Constraints

- Exclusively use `pnpm` for Node/JS and `uv` for Python if package managers are needed.
- Always use `git -c core.quotepath=false` for git operations.
- Do not elevate unprivileged inspection commands.
- Adhere to `PROJECT_CONTEXT.md` design rules: no raw window objects in UI, avoid hardcoded sizes, respect Wayland layer-shell rules.

---

### Task 1: 扩展碰撞与数学模型并增加测试 (`DockAutoHideMath.mjs` & `test_autohide.mjs`)

**Files:**
- Modify: `desktop/modules/dock/DockAutoHideMath.mjs:13-39`
- Modify: `desktop/modules/dock/test_autohide.mjs:20-40`

**Interfaces:**
- Consumes: `screenRect`, `position`, `dockWidth`, `dockHeight`, `edgeMargin`
- Produces: `visibleDockRect(screenRect, position, dockWidth, dockHeight, edgeMargin)` supporting `position === "top"`.

- [ ] **Step 1: 在 `test_autohide.mjs` 中添加针对顶部 Bar 的测试用例**

```javascript
// visibleDockRect: top position
{
    const r = visibleDockRect(S, "top", 1920 - 30, 35, 15);
    ok(nearly(r.x, 15), "top x = edgeMargin");
    ok(nearly(r.y, 0), "top y = screen top");
    ok(nearly(r.width, 1920 - 30) && nearly(r.height, 35), "top size");
}
// Top avoidance and conflict test
{
    const topBase = visibleDockRect(S, "top", 1920 - 30, 35, 15);
    const topAv = avoidanceRect(topBase);
    const topRel = releaseRect(topBase);
    const winNearTop = win({ geometry: { x: 100, y: 10, width: 400, height: 300 } });
    ok(hasConflict([winNearTop], S, topAv, topRel, false, "d1"), "window near top conflicts with top bar");
    const winFarBottom = win({ geometry: { x: 100, y: 300, width: 400, height: 300 } });
    ok(!hasConflict([winFarBottom], S, topAv, topRel, false, "d1"), "window at bottom does not conflict with top bar");
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `node desktop/modules/dock/test_autohide.mjs`
Expected: FAIL on `top position`

- [ ] **Step 3: 在 `DockAutoHideMath.mjs` 中实现 `position === "top"` 逻辑**

```javascript
export function visibleDockRect(screenRect, position, dockWidth, dockHeight, edgeMargin) {
    if (position === "top") {
        return {
            x: screenRect.x + edgeMargin,
            y: screenRect.y,
            width: dockWidth,
            height: dockHeight
        };
    }
    if (position === "bottom") {
        return {
            x: screenRect.x + (screenRect.width - dockWidth) / 2,
            y: screenRect.y + screenRect.height - edgeMargin - dockHeight,
            width: dockWidth,
            height: dockHeight
        };
    }
    if (position === "left") {
        return {
            x: screenRect.x + edgeMargin,
            y: screenRect.y + (screenRect.height - dockHeight) / 2,
            width: dockWidth,
            height: dockHeight
        };
    }
    // right
    return {
        x: screenRect.x + screenRect.width - edgeMargin - dockWidth,
        y: screenRect.y + (screenRect.height - dockHeight) / 2,
        width: dockWidth,
        height: dockHeight
    };
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `node desktop/modules/dock/test_autohide.mjs`
Expected: `ALL PASS`

- [ ] **Step 5: 提交更改**

```bash
git -c core.quotepath=false add desktop/modules/dock/DockAutoHideMath.mjs desktop/modules/dock/test_autohide.mjs
git -c core.quotepath=false commit -m "feat(dock): support top edge in DockAutoHideMath and add unit tests"
```

---

### Task 2: 在 `AppearanceConfigService` 与 `DesktopEnvironment` 中扩展配置与 IPC

**Files:**
- Modify: `desktop/modules/common/AppearanceConfigService.qml`
- Modify: `desktop/DesktopEnvironment.qml`

**Interfaces:**
- Consumes: Config directory path, IPC messages from Settings app
- Produces: `AppearanceConfigService.barVisibilityMode`, `updateBarVisibilityMode(mode)`

- [ ] **Step 1: 在 `AppearanceConfigService.qml` 中添加 `barVisibilityMode` 属性与持久化逻辑**

```qml
    property string barVisibilityMode: "always" // "always" | "smart" | "persistent"

    function isValidBarVisibilityMode(value) {
        return value === "always" || value === "smart" || value === "persistent"
    }

    function updateBarVisibilityMode(rawMode) {
        const mode = String(rawMode)
        if (!isValidBarVisibilityMode(mode) || barVisibilityMode === mode)
            return false
        barVisibilityMode = mode
        saveTimer.restart()
        return true
    }
```
并在 `_save()` 的 JSON payload 中加入 `barVisibilityMode: service.barVisibilityMode`，并在 `_load()` 中解析 `barVisibilityMode`，保持向下兼容。

- [ ] **Step 2: 在 `DesktopEnvironment.qml` 的 `appearance-settings` IpcHandler 中暴露接口**

```qml
    IpcHandler {
        target: "appearance-settings"

        function snapshot(): string {
            return JSON.stringify({
                blurStrength: AppearanceConfigService.blurStrength,
                liquidStrength: AppearanceConfigService.liquidStrength,
                shellStyle: AppearanceConfigService.shellStyle,
                barIntegratedWithDock: AppearanceConfigService.barIntegratedWithDock,
                barVisibilityMode: AppearanceConfigService.barVisibilityMode,
                tokenVersion: AppearanceTokens.version,
            })
        }
        function updateBarVisibilityMode(mode: string): string {
            AppearanceConfigService.updateBarVisibilityMode(mode)
            return snapshot()
        }
    }
```

- [ ] **Step 3: 运行语法检查并提交**

```bash
git -c core.quotepath=false add desktop/modules/common/AppearanceConfigService.qml desktop/DesktopEnvironment.qml
git -c core.quotepath=false commit -m "feat(config): add barVisibilityMode to AppearanceConfigService and IPC endpoint"
```

---

### Task 3: 实现顶栏状态控制器 (`BarAutoHideController.qml`)

**Files:**
- Create: `desktop/modules/bar/BarAutoHideController.qml`
- Modify: `desktop/modules/bar/qmldir`

**Interfaces:**
- Consumes: `mode`, `configReady`, `windowDataReady`, `targetScreen`, `barHeight`, `edgeMargin`, `pointerInsideBar`, `popupOpen`, `launcherOpen`
- Produces: `revealProgress`, `hidden`, `offsetY`, `barOpacity`, `handleEntered()`, `handleExited()`, `handleClicked()`, `requestReveal(reason, holdMs)`

- [ ] **Step 1: 创建 `desktop/modules/bar/BarAutoHideController.qml`**

实现完整状态机（`Bootstrapping`, `Shown`, `HidePending`, `Hiding`, `Hidden`, `RevealPending`, `Showing`, `Held`），复用 `DockAnimation` 的延迟时长和缓动曲线，单值驱动 `revealProgress`。

- [ ] **Step 2: 在 `desktop/modules/bar/qmldir` 中注册 `BarAutoHideController`**

```
BarAutoHideController 1.0 BarAutoHideController.qml
```

- [ ] **Step 3: 提交控制器组件**

```bash
git -c core.quotepath=false add desktop/modules/bar/BarAutoHideController.qml desktop/modules/bar/qmldir
git -c core.quotepath=false commit -m "feat(bar): add BarAutoHideController state machine"
```

---

### Task 4: 组装 `BarWindow.qml` 与 `BarStatusArea.qml` 交互集成

**Files:**
- Modify: `desktop/modules/bar/BarWindow.qml`
- Modify: `desktop/modules/bar/BarStatusArea.qml`

**Interfaces:**
- Consumes: `BarAutoHideController`, `AppearanceConfigService.barVisibilityMode`
- Produces: 动态 `exclusiveZone`、顶部隐形感应带、`dockWrapper` 平滑上移、Wayland input mask。

- [ ] **Step 1: 在 `BarStatusArea.qml` 中导出弹出面板状态**

添加只读属性 `readonly property bool anyPanelOpen: networkPanel.visible || bluetoothPanel.visible || root.controlCenterOpen`。

- [ ] **Step 2: 在 `BarWindow.qml` 中引入 `BarAutoHideController` 并设置动画、感应区与遮罩**

```qml
    BarAutoHideController {
        id: hide
        mode: AppearanceConfigService.barVisibilityMode
        configReady: AppearanceConfigService.ready
        windowDataReady: WindowService.providerReady
        targetScreen: root.screen
        barHeight: ConfigService.barHeight
        edgeMargin: 15
        pointerInsideBar: contentHoverHandler.hovered
        popupOpen: barStatusArea?.anyPanelOpen ?? false
        launcherOpen: AppLauncherService.open
    }
```
- `exclusiveZone: (AppearanceConfigService.barVisibilityMode === "always" && root.barEnabled) ? ConfigService.barHeight : 0`
- 顶层 `barContent` 的 `y: hide.offsetY` 与 `opacity: hide.barOpacity`。
- 顶部 2px `topTriggerRegion`（当 `hide.handleActive` 时捕获鼠标触顶 hover）。
- Wayland `mask: Region { Region { item: barContentHitRegion } Region { item: topTriggerHitRegion } }`。

- [ ] **Step 3: 检查语法并提交**

```bash
git -c core.quotepath=false add desktop/modules/bar/BarWindow.qml desktop/modules/bar/BarStatusArea.qml
git -c core.quotepath=false commit -m "feat(bar): integrate auto-hide controller, touch-top trigger and input masking into BarWindow"
```

---

### Task 5: 在设置中心（`apps/settings`）中增加 Bar 显示模式配置

**Files:**
- Modify: `apps/settings/src/main.cpp`
- Modify: `apps/settings/main.qml`

**Interfaces:**
- Consumes: `SettingsBridge.updateBarVisibilityMode(mode)`
- Produces: `ThemeSettingsPage` 中「BAR 布局」区域的「Bar 显示方式」`SettingsNavBar`。

- [ ] **Step 1: 在 `apps/settings/src/main.cpp` 中添加 `updateBarVisibilityMode` 接口**

```cpp
    Q_INVOKABLE QVariantMap updateBarVisibilityMode(const QString &mode) {
        return appearanceSnapshotFromReply(callAppearance({
            QStringLiteral("updateBarVisibilityMode"), mode}));
    }
```
在 `appearanceSnapshotFromReply` 中解析 `barVisibilityMode`。

- [ ] **Step 2: 在 `apps/settings/main.qml` 的 `ThemeSettingsPage` 中添加切换控件**

```qml
    Item {
        width: parent.width
        height: 54
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            SettingIcon { symbol: "◉"; tint: "#ff9f0a" }
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
                currentIndex: themePage.barVisibilityModeIndex
                onSelectionChanged: function(index) {
                    themePage.saveBarVisibilityMode(index)
                }
            }
        }
    }
```

- [ ] **Step 3: 编译检查 `apps/settings` 并提交**

```bash
git -c core.quotepath=false add apps/settings/src/main.cpp apps/settings/main.qml
git -c core.quotepath=false commit -m "feat(settings): add Bar visibility mode selector in Theme page"
```

---

### Task 6: 完整验证与系统测试

**Files:**
- Test: `desktop/modules/dock/test_autohide.mjs`

- [ ] **Step 1: 运行全量单元测试**
Run: `node desktop/modules/dock/test_autohide.mjs`
Expected: `ALL PASS`

- [ ] **Step 2: 运行代码规范与 git 检查**
Run: `git diff --check`

- [ ] **Step 3: 运行 Quickshell 验证实例检查 QML 日志与交互**
Run: 启动 Quickshell 验证实例，验证窗口靠近时 Bar 隐藏、触顶呼出、设置中心切换等交互。
