# 启动台、Dock 与 Bar 统一模糊逻辑及独立/继承调节实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现启动台、Dock 和 Bar 共用一套液态毛玻璃与模糊逻辑，支持继承 Dock 数值或各自独立调节，并在 `AppearanceConfigService`、`AppearanceTokens`、`LiquidGlassSurface`、IPC 与 `kos-settings` 中完整落地。

**Architecture:** 
1. 在 `AppearanceConfigService` (schema v5) 中统一维护 `dockBlur/LiquidStrength`、`barBlurInheritDock`、`barBlur/LiquidStrength`、`launcherBlurInheritDock`、`launcherBlur/LiquidStrength` 及响应式 `effective*` 只读属性；
2. 在 `AppearanceTokens` 中导出统一的 semantic tokens；
3. 将 `LiquidGlassSurface`、`BarWindow` 和 `AppLauncherWindow` 接入对应的 effective 属性；
4. 在 `DesktopEnvironment.qml` (IPC)、`apps/settings/src/main.cpp` 与 `apps/settings/main.qml` 中补齐全套状态读取、切换开关与独立滑动条。

**Tech Stack:** QML (Qt Quick / Quickshell), C++ (Qt6 Core/Gui/Qml), CMake, Node.js (Unit Tests)

## Global Constraints
- Fedora KDE Plasma (Wayland) 环境，纯非特权用户调用。
- Git 输出必须传递 `-c core.quotepath=false`。
- 保留工作区现有修改，遵循向后兼容（旧版本配置 v1~v4 自动平滑升级为 v5）。

---

### Task 1: 核心外观配置模型与语义 Token (AppearanceConfigService & AppearanceTokens)

**Files:**
- Modify: `desktop/modules/common/AppearanceConfigService.qml`
- Modify: `desktop/modules/common/AppearanceTokens.qml`
- Test: `desktop/modules/common/test_appearance_config.mjs`

**Interfaces:**
- Produces:
  - `AppearanceConfigService.dockBlurStrength`: `real`
  - `AppearanceConfigService.dockLiquidStrength`: `real`
  - `AppearanceConfigService.barBlurInheritDock`: `bool`
  - `AppearanceConfigService.barBlurStrength`: `real`
  - `AppearanceConfigService.barLiquidStrength`: `real`
  - `AppearanceConfigService.launcherBlurInheritDock`: `bool`
  - `AppearanceConfigService.launcherBlurStrength`: `real`
  - `AppearanceConfigService.launcherLiquidStrength`: `real`
  - `AppearanceConfigService.effectiveDockBlur`: `real`
  - `AppearanceConfigService.effectiveDockLiquid`: `real`
  - `AppearanceConfigService.effectiveBarBlur`: `real`
  - `AppearanceConfigService.effectiveBarLiquid`: `real`
  - `AppearanceConfigService.effectiveLauncherBlur`: `real`
  - `AppearanceConfigService.effectiveLauncherLiquid`: `real`
  - `AppearanceConfigService.updateDockBlurStrength(real)`
  - `AppearanceConfigService.updateDockLiquidStrength(real)`
  - `AppearanceConfigService.updateBarBlurInherit(bool)`
  - `AppearanceConfigService.updateBarBlurStrength(real)`
  - `AppearanceConfigService.updateBarLiquidStrength(real)`
  - `AppearanceConfigService.updateLauncherBlurInherit(bool)`
  - `AppearanceConfigService.updateLauncherBlurStrength(real)`
  - `AppearanceConfigService.updateLauncherLiquidStrength(real)`

- [ ] **Step 1: 编写测试脚本验证配置升级与计算逻辑**
  创建 `desktop/modules/common/test_appearance_config.mjs` 测试 schema 升级与 effective 属性计算。

- [ ] **Step 2: 运行测试验证失败**
  `node desktop/modules/common/test_appearance_config.mjs`

- [ ] **Step 3: 实现 `AppearanceConfigService.qml` (schema v5) 与 `AppearanceTokens.qml`**
  实现字段持久化、保存、加载、有效值计算方法以及向后兼容映射。

- [ ] **Step 4: 运行测试验证通过**
  `node desktop/modules/common/test_appearance_config.mjs`
  `qmllint desktop/modules/common/AppearanceConfigService.qml desktop/modules/common/AppearanceTokens.qml`

- [ ] **Step 5: 提交代码**
  `git -c core.quotepath=false commit -m "feat(appearance): implement unified blur and inheritance configuration model"`

---

### Task 2: IPC 协议与 C++ Settings Bridge 扩展

**Files:**
- Modify: `desktop/DesktopEnvironment.qml`
- Modify: `apps/settings/src/main.cpp`
- Test: `apps/settings/build` (CMake build)

**Interfaces:**
- Consumes: Task 1 的 `AppearanceConfigService` 接口
- Produces:
  - `IpcHandler` 目标 `"appearance-settings"` 导出新接口
  - C++ `SettingsBridge::appearanceSnapshot()` 包含新字段
  - C++ `SettingsBridge` 提供 `updateDockBlurStrength`, `updateDockLiquidStrength`, `updateBarBlurInherit`, `updateBarBlurStrength`, `updateBarLiquidStrength`, `updateLauncherBlurInherit`, `updateLauncherBlurStrength`, `updateLauncherLiquidStrength`

- [ ] **Step 1: 扩展 `desktop/DesktopEnvironment.qml` 中的 `appearance-settings` IpcHandler**
  增加全套参数 snapshot 与更新函数。

- [ ] **Step 2: 扩展 `apps/settings/src/main.cpp` C++ 桥接层**
  在 `appearanceSnapshotFromReply` 中解析新字段并添加调用方法。

- [ ] **Step 3: 编译验证 C++ 设置应用**
  `cmake --build apps/settings/build`

- [ ] **Step 4: 提交代码**
  `git -c core.quotepath=false commit -m "feat(settings): extend IPC endpoint and C++ bridge for blur inheritance"`

---

### Task 3: 表面材质与窗口渲染对接 (LiquidGlassSurface, Bar, Launcher)

**Files:**
- Modify: `desktop/modules/common/LiquidGlassSurface.qml`
- Modify: `desktop/modules/bar/BarWindow.qml`
- Modify: `desktop/modules/applauncher/AppLauncherWindow.qml`

**Interfaces:**
- Consumes: Task 1 的 `AppearanceConfigService` effective 属性
- Produces:
  - `LiquidGlassSurface.qml` 默认使用 `AppearanceConfigService.effectiveDockLiquid`
  - `BarWindow.qml` 绑定 `effectiveBarLiquid` 与 `effectiveBarBlur`
  - `AppLauncherWindow.qml` 绑定 `effectiveLauncherLiquid` 与 `effectiveLauncherBlur`

- [ ] **Step 1: 更新 `LiquidGlassSurface.qml`**
  将 `liquidStrength` 默认绑定优化，支持外部显式绑定与全局 effectiveDockLiquid 回退。

- [ ] **Step 2: 更新 `BarWindow.qml`**
  为 `barGlassBackground` 绑定 `AppearanceConfigService.effectiveBarLiquid`。

- [ ] **Step 3: 更新 `AppLauncherWindow.qml`**
  将启动台大卡片背景及搜索框使用 `LiquidGlassSurface` 并绑定 `AppearanceConfigService.effectiveLauncherLiquid`。

- [ ] **Step 4: 静态检查与运行时校验**
  `qmllint desktop/modules/common/LiquidGlassSurface.qml desktop/modules/bar/BarWindow.qml desktop/modules/applauncher/AppLauncherWindow.qml`
  `timeout 3 quickshell --path /home/deadalux/Projects/NextKde --no-color`

- [ ] **Step 5: 提交代码**
  `git -c core.quotepath=false commit -m "feat(surfaces): connect Dock, Bar and AppLauncher to unified blur engine"`

---

### Task 4: 设置中心 UI 交互实现 (kos-settings)

**Files:**
- Modify: `apps/settings/main.qml`

**Interfaces:**
- Consumes: Task 2 的 `settingsBridge` 接口

- [ ] **Step 1: 在“显示 / 主题”页面完善 Dock 主控与 Bar 继承/独立切换卡片**
  - Dock 模糊与液态强度滑动条；
  - Bar 区域的“跟随 Dock 模糊效果”开关及展开的独立滑动条。

- [ ] **Step 2: 在“启动台”页面新增“外观与模糊效果”卡片**
  - “跟随 Dock 模糊效果”开关；
  - 关闭时展开独立的启动台模糊与液态强度滑动条。

- [ ] **Step 3: 语法校验与运行验证**
  `qmllint apps/settings/main.qml`

- [ ] **Step 4: 提交代码**
  `git -c core.quotepath=false commit -m "feat(settings-ui): add inheritance switches and independent sliders for Bar and Launcher"`

---

### Task 5: 综合验证与回归测试 (Full Regression & Verification)

- [ ] **Step 1: 运行所有单元测试**
  `node desktop/modules/dock/test_adaptive.mjs && node desktop/modules/dock/test_autohide.mjs && node desktop/modules/common/test_appearance_config.mjs`

- [ ] **Step 2: 运行所有 QML 文件的语法检查**
  `qmllint desktop/modules/common/AppearanceConfigService.qml desktop/modules/bar/BarWindow.qml desktop/modules/applauncher/AppLauncherWindow.qml apps/settings/main.qml`

- [ ] **Step 3: 运行 Quickshell 运行时无崩溃加载测试**
  `timeout 3 quickshell --path /home/deadalux/Projects/NextKde --no-color`

- [ ] **Step 4: 检查 git 变更完整性**
  `git -c core.quotepath=false status`
