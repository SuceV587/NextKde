# 启动台、Dock 与 Bar 统一模糊逻辑及独立/继承调节设计规范

- **日期**: 2026-08-29
- **状态**: Approved
- **作者**: Antigravity Pair Programming Assistant

---

## 1. 目标与背景 (Goals & Context)

当前 NextKde 系统的模糊与液态玻璃材质（`LiquidGlassSurface` 与 KWin `Effect-blurplus` / `glass` 特效）在视觉风格上已趋于统一，但各组件的参数控制较为分散：
- Dock 拥有基准的模糊与折射表现；
- Bar 顶部栏在智能隐藏聚焦与独立显示时，未完全联动统一的外观调节；
- 启动台（AppLauncher）的卡片背景使用固定透明度参数，无法跟随或独立调整模糊与液态折射感；
- 设置中心（`kos-settings`）缺少对各表面独立配置与继承关系的控制。

**本设计旨在**：
1. 统一启动台、Dock 和 Bar 的底层毛玻璃与液态折射渲染逻辑；
2. 提供「继承 Dock（默认）」与「独立调节」的双模配置体系；
3. 在桌面环境核心服务与 `kos-settings` 中提供完整的 IPC、持久化存储以及直观友好的 UI 交互。

---

## 2. 架构设计与数据流 (Architecture & Data Flow)

```
                     ┌───────────────────────────────┐
                     │    AppearanceConfigService    │
                     │  (schema v5 in config.json)   │
                     └──────────────┬────────────────┘
                                    │
         ┌──────────────────────────┼──────────────────────────┐
         ▼                          ▼                          ▼
   [Dock Surface]            [Bar Surface]            [Launcher Surface]
  - effectiveDockBlur       - effectiveBarBlur        - effectiveLauncherBlur
  - effectiveDockLiquid     - effectiveBarLiquid      - effectiveLauncherLiquid
  (Master Baseline)         (Inherit or Custom)       (Inherit or Custom)
         │                          │                          │
         └──────────────────────────┼──────────────────────────┘
                                    ▼
                         ┌────────────────────┐
                         │ LiquidGlassSurface │
                         │ + KWin Glass Sync  │
                         └────────────────────┘
```

---

## 3. 详细设计 (Detailed Specifications)

### 3.1 外观配置模型 (`AppearanceConfigService.qml`)

版本升级至 `schema: 5`，支持以下配置属性：

* **Dock 主控基准属性**：
  - `dockBlurStrength`: `real` (默认 `0.42`，范围 `[0.0, 1.0]`)
  - `dockLiquidStrength`: `real` (默认 `1.0`，范围 `[0.0, 1.0]`)
* **Bar 顶部栏属性**：
  - `barBlurInheritDock`: `bool` (默认 `true`)
  - `barBlurStrength`: `real` (默认 `0.42`，范围 `[0.0, 1.0]`)
  - `barLiquidStrength`: `real` (默认 `1.0`，范围 `[0.0, 1.0]`)
* **启动台属性**：
  - `launcherBlurInheritDock`: `bool` (默认 `true`)
  - `launcherBlurStrength`: `real` (默认 `0.42`，范围 `[0.0, 1.0]`)
  - `launcherLiquidStrength`: `real` (默认 `1.0`，范围 `[0.0, 1.0]`)
* **有效计算属性 (Readonly Effective Properties)**：
  - `effectiveDockBlur`: `dockBlurStrength`
  - `effectiveDockLiquid`: `dockLiquidStrength`
  - `effectiveBarBlur`: `barBlurInheritDock ? dockBlurStrength : barBlurStrength`
  - `effectiveBarLiquid`: `barBlurInheritDock ? dockLiquidStrength : barLiquidStrength`
  - `effectiveLauncherBlur`: `launcherBlurInheritDock ? dockBlurStrength : launcherBlurStrength`
  - `effectiveLauncherLiquid`: `launcherBlurInheritDock ? dockLiquidStrength : launcherLiquidStrength`
* **向后兼容性 (Backward Compatibility)**：
  - 旧版 `blurStrength` 与 `liquidStrength` 自动映射至 `dockBlurStrength` 与 `dockLiquidStrength`；
  - 缺失 `barBlurInheritDock` 或 `launcherBlurInheritDock` 时自动初始化为 `true`。

### 3.2 语义 Token 规范 (`AppearanceTokens.qml`)

在 `AppearanceTokens.glass` 中开放语义化只读属性：
- `dockBlur`, `dockLiquid`
- `barBlur`, `barLiquid`
- `launcherBlur`, `launcherLiquid`
- 保留 `blurStrength` 与 `liquidStrength` 作为 Dock 基础值的向后兼容别名。

### 3.3 表面材质对接 (`LiquidGlassSurface` 与各模块)

1. **`LiquidGlassSurface.qml`**：
   - 允许显式传入 `liquidStrength`，默认绑定 `AppearanceConfigService.effectiveDockLiquid`。
2. **`BarWindow.qml`**：
   - `barGlassBackground` 的 `liquidStrength` 绑定 `AppearanceConfigService.effectiveBarLiquid`。
3. **`AppLauncherWindow.qml`**：
   - 启动台大卡片背景与搜索框药丸使用 `LiquidGlassSurface`，绑定 `AppearanceConfigService.effectiveLauncherLiquid`。

### 3.4 IPC 协议与设置中心 (`DesktopEnvironment.qml` & `kos-settings`)

1. **`appearance-settings` IPC 端点扩展**：
   - `snapshot()` 返回包含三组件的完整状态 JSON。
   - 新增方法：
     - `updateDockBlurStrength(value: real)`
     - `updateDockLiquidStrength(value: real)`
     - `updateBarBlurInherit(inherit: bool)`
     - `updateBarBlurStrength(value: real)`
     - `updateBarLiquidStrength(value: real)`
     - `updateLauncherBlurInherit(inherit: bool)`
     - `updateLauncherBlurStrength(value: real)`
     - `updateLauncherLiquidStrength(value: real)`
2. **C++ Bridge (`apps/settings/src/main.cpp`)**：
   - 解析并暴露上述所有字段至 QML `settingsBridge`。
3. **Settings UI (`apps/settings/main.qml`)**：
   - **“显示 / 主题” 页**：
     - Dock 模糊与液化主控调节；
     - Bar 区域包含「跟随 Dock 模糊效果」开关（关闭时展开独立的 Bar 模糊与液化调节滑块）。
   - **“启动台” 页**：
     - 新增外观卡片，包含「跟随 Dock 模糊效果」开关（关闭时展开独立的启动台模糊与液化调节滑块）。

---

## 4. 验证计划 (Verification Plan)

1. **语法与静态分析**：
   - 运行 `qmllint` 检查所有修改的 QML 文件。
2. **C++ 构建检查**：
   - 使用 `cmake --build apps/settings/build` 编译验证 `kos-settings`。
3. **单元与回归测试**：
   - 运行 `node desktop/modules/dock/test_adaptive.mjs && node desktop/modules/dock/test_autohide.mjs`。
4. **运行时载入检查**：
   - 运行 `timeout 3 quickshell --path /home/deadalux/Projects/NextKde --no-color` 验证无报错加载。
