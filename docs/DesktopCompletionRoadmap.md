# 完整桌面路线图

本文定义 Quickshell 项目从现有的视觉 Shell 走向可长期日用桌面的
剩余工作、优先级与边界。它是产品和架构路线图；新增功能前应先判断其
属于哪一项，避免重复造数据接口或跳过基础能力直接堆叠组件。

## 当前基础

项目已经具备以下主要能力：

- Dock：固定应用、运行窗口、窗口预览（KWin bridge + ScreenShot2 缩略图）、右键操作、回收站（含 `hasItems` 状态徽章）、MPRIS 播放器（完整 seek + 元数据 + 封面取色）。Dock 的 folder 功能已移除。
- Bar 与控制中心：托盘、系统指标、网络状态、蓝牙、音量、截图、注销、
  勿扰模式、天气。Wi-Fi 连接/断开/忘记/802.1X（PEAP+TTLS）已实现。
- 应用启动与搜索：应用启动器（网格 + 文件夹 + 拖入建组）、应用分组/排序、快速搜索、剪贴板历史（cliphist 适配，含图片）。
- DeskCenter：时钟、天气、日历、系统信息、活动记录、播放器和桌面文件。桌面文件支持排序（名称/类型/修改时间）、框选、重命名、回收站、文件夹投放（hold-to-drop）、多选拖动、新建文件/文件夹、外部 URL 拖入、cut/copy 语义。
- 通知：Wayland/DBus 通知横幅与勿扰策略。
- 玻璃表面：两路并行--compositor blur 路线（`LiquidGlassSurface` + `RoundedBlurRegion`，用于 Dock/启动器/搜索/天气/通知/预览）与无 blur 路线（`EnhancedGlassSurface`，用于控制中心/蓝牙/网络 popup）。KWin glass effect（Dual Kawase + Snell 折射）已编译安装。
- 数据服务：`tools/shell-data-service` 已提供持久快照、桌面目录 inotify
  监听和本地 socket 通知；内存/温度/活动/在线时长已采样，CPU/磁盘/频率尚未实现。

现阶段的主要缺口不是新的小组件，而是数据边界、系统级入口、窗口管理和
跨应用文件操作的完整闭环。

## P0：完整桌面的基础能力

### 1. 数据层收口到 shell-data-service

将跨 Surface、需持久化或有历史聚合的数据全部迁入 Go 服务：

- **尚未迁移**：CPU、磁盘、频率的当前值与趋势。CPU/磁盘/频率目前在 QML 侧采样（`bar/CpuTemperature.qml` 10s 轮询 `/sys`、`/proc`、`df` 并写 `usage-history.json`）；Go 服务的 `readCPU` 是 `return 0` 的空壳，`Disk`/`Frequency` 字段从未赋值，需补全。
- **已在 Go 服务但 UI 未消费**：内存、温度、活动、在线时长已由 `main.go` 采样（`readMem`/`readTemp`/`settle`），但 UI 仍读 QML 缓存而非服务快照，需切换消费来源。
- **需迁移的 QML 账本**：`deskcenter/ActivityUsageService.qml` 是独立 QML 活动账本（直接读 `journalctl --list-boots`、写 `activity-usage.json`），与 Go 服务的 `settle`/`UptimeByDay` 重复，应移除并改读服务。

QML 仅负责呈现、格式化与局部交互。应移除 DeskCenter 内的独立活动账本，
以及 Bar 写缓存、DeskCenter 再读缓存的旧交接方式。服务负责原子快照和
变更通知，保证 Quickshell 重载后数据不丢失、不同 Surface 不出现数值漂移。

相关约定见 [ShellDataService.md](ShellDataService.md)。

### 2. 全局快捷键和 Shell 入口

建立唯一的全局快捷键注册与配置层，而不是让各窗口各自监听按键。

- 应用启动器、快速搜索、控制中心、通知历史、窗口切换器均从此层打开。
- 支持用户配置与冲突检测。
- 桌面文件的局部快捷键只在桌面获得焦点后生效，不能抢占应用快捷键。

### 3. Alt+Tab 窗口切换器

基于 `WindowService.records` 实现 MRU（最近使用）窗口切换：

- 显示窗口缩略图、应用图标和标题。
- 支持同应用多窗口，确认后激活目标窗口。
- 不使用 Dock 的视觉排序或固定应用顺序作为窗口顺序。

现有 `WindowService`、`AppGroupService`、KWin bridge 和预览架构可复用；
身份与持久化约定见 [DockArchitecture.md](DockArchitecture.md)。

### 4. 控制中心的真实系统控制

完善已存在的控制中心，而不是增加平行入口：

- **Wi-Fi**：连接/断开/忘记/802.1X（PEAP+TTLS）**已实现**（`NetworkService.qml`），需审计 `NetworkService` 文档与实现的一致性，清理 `NetworkService.qml` 内声称「未实现」的过期注释，并补全连接失败的用户反馈。
- **亮度**：接入真实亮度后端，并处理无亮度设备时的降级状态（当前 `ControlCenterPanel.qml` 显示静态 48% + 「未检测到后端」）。
- 保持音量、蓝牙、勿扰、截图等操作有明确的进行中/失败状态。

## P1：日用完整性

### 5. 桌面文件操作稳定化

内部排序、框选、重命名、回收站、文件夹投放、多选拖动、新建文件已实现，
需在使用中保持稳定，不要为追求新交互破坏现有手势（尤其 hold-to-drop
文件夹投放与多选拖动的时序）。

跨应用剪贴板由 Go `shell-data-service` 管理生命周期，并通过最小的无窗口
Qt helper 同时发布 URI、KDE cut marker 和 GNOME 兼容格式。Dolphin 与桌面间
的 Ctrl+C/Ctrl+X/Ctrl+V 因此能保留复制/移动语义；该桥接只负责剪贴板 MIME，
不能接管或破坏桌面内部原生拖拽、排序和文件夹合并算法。跨窗口拖放移动仍需
单独验证 Wayland DnD action 协商。

### 6. 通知历史中心

当前通知横幅是即时的。补充可打开的历史中心：

- 保存勿扰期间和已过期通知的会话历史。
- 按应用分组、单条关闭、全部清空。
- 在平台支持时执行通知 action；不支持时保持明确降级。

### 7. 会话与电源

补齐锁屏、休眠、重启、关机和用户切换入口，并为低电量、无权限、操作失败
提供状态反馈。该能力属于控制中心/会话层，不应散落在桌面小组件中。

### 8. 多显示器与每屏布局

将以下配置按显示器持久化：

- DeskCenter 小组件布局与桌面文件图标布局。
- Dock 的显示规则和位置。
- 壁纸、颜色取样与每屏视觉主题。

分辨率、缩放或显示器重新连接后应保持可预测的布局，而不是依赖当前窗口尺寸。

## P2：产品完善与扩展

### 9. 设置中心

建立统一设置入口，集中管理 Dock、Bar、DeskCenter、壁纸、透明度、圆角、
动画强度、快捷键和桌面文件显示方式。设置 UI 只写各模块已定义的配置边界，
不直接修改运行时窗口模型。

### 10. 工作区概览 / Stage Manager

待 Alt+Tab 稳定后，使用 `AppGroupService` 和可选的 KWin 工作区适配器实现。
工作区 ID 属于运行时提供者元数据，不能进入应用 canonical ID 或 Dock 持久化
记录。

### 11. 可访问性与键盘导航

完善焦点顺序、屏幕阅读器语义、高对比度、减少动画与全键盘操作。桌面文件
键盘导航可在基础指针交互稳定后再进入范围。

## 推荐开发顺序

1. 数据服务收口。
2. 全局快捷键与 Alt+Tab。
3. 控制中心亮度后端接入与 Wi-Fi 文档对齐。
4. 通知历史、会话与电源。
5. 多显示器布局。
6. 跨应用文件移动桥接。
7. 设置中心与 Stage Manager。

## 不应优先做的事项

- 不继续添加与已有时钟、天气、日历、系统信息、活动记录和播放器重复的桌面
  小组件。
- 不在 QML 中增加新的长期采样、历史数据或跨 Surface 数据源（含 CPU/磁盘/频率采样，应迁入 Go 服务而非在 QML 新增）。
- 不为了跨应用拖放而改动桌面内部排序/文件夹投放的稳定交互。
- 不混用玻璃面：需 compositor blur 的表面用 `LiquidGlassSurface` + `RoundedBlurRegion`，无 blur 依赖的 popup 用 `EnhancedGlassSurface`，不要给后者再叠加 `blurRegion`。
