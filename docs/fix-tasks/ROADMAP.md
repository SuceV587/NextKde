# 修复任务路线图

状态标记：`[ ]` 未开始 / `[~]` 进行中 / `[x]` 已完成并通过审查

> 顺序即推荐执行顺序：先修放大器（T1），再修用户可见问题（T2），
> 然后按守护进程 → 内存 → CPU → 正确性 → 红线的顺序推进。

---

## T1 [x] IPC 客户端断线语义（最高优先级，放大器）

**范围**：`shell/desktop/modules/platform/PlatformClient.qml`、`DataClient.qml`，
以及依赖 in-flight 标志的服务。

**问题**：断线时请求无条件入队，`_queue`/`_pending` 无上限无超时；daemon 停机
1 小时积压 6000+ 条；重连后风暴式重放（断线时的写操作被批量补执行）；
所有 in-flight 标志因回调永不到达而永久卡死（Wi-Fi 面板、剪贴板、回收站、
关机按钮、appmenu）。

**修复内容**：
- 幂等读请求按 operation 去重（队列中同 op 只保留最新，callback 合并）；
- `_queue` 上限（~200），超限丢弃最旧幂等读；写操作断线时直接失败回调；
- 请求超时（~30s）后以 `{ok:false}` 回调并清出 `_pending`；
- `connectedChanged(false)` 时清空队列 + 失败化所有 pending + 复位各服务
  in-flight 标志（NetworkService 4 个、ClipboardService 2 个、
  DockTrashService.emptying、ControlCenterService.sessionActionInProgress、
  AppMenuService.requestPending、NetworkTraffic._samplePending、
  WindowService._thumbnailPendingByHandle）。

## T2 [x] 托盘右键菜单黑角（用户可见 bug）

**范围**：`SysTray.qml` 的 `QsMenuAnchor` 路径；Quickshell 0.3.1 源码补丁。

**根因**：Quickshell `PlatformMenuEntry::display()` 在 Breeze `polish()` 设置
`WA_TranslucentBackground` 之前调用 `createWinId()`，surface 以无 alpha
创建并提交全量 opaque region → 圆角外像素合成黑色（KDE bug 385311 同款）。

**已选定方案 B**（2026-09-19 用户确认）：自绘 `ContextMenu` 承接托盘菜单——
`QsMenuOpener` 读 `modelData.menu` children → ContextMenu items，顺带统一
liquid-glass 视觉（Dock 已全自绘，先例见 `DockContainer.qml:319`）。

备选方案（不执行，留档）：
- A. Quickshell 补丁：`display()` 中 `createWinId()` 前 `ensurePolished()`，
  `PlatformMenuQMenu` 构造时 `setAttribute(Qt::WA_TranslucentBackground)`；
  补丁接入 `tools/build-quickshell-0.3.sh`。若 B 遇到 `QsMenuHandle` 能力
  缺口（图标、勾选态、radio 分组）无法解决再回退此方案。
- C. 临时规避：`QT_STYLE_OVERRIDE=Fusion`（仅验证用，不提交）。

## T3 [x] kos-platform 子进程风暴 + runCommand 超时

**范围**：`platform/src/daemon/PlatformServer.cpp`。

**问题**：每 3s 轮询驱动 ~5-7 个子进程（wpctl/bluetoothctl×2/nmcli×2-4/pactl）
+ 十几次阻塞 D-Bus 往返，每分钟 ~140-180 次 fork/exec；`runCommand`
（`:1105-1142`）无超时，对端卡顿时进程堆积。

**修复内容**：
- `runCommand`/`runCliphist*`/`runWlCopy` 统一 watchdog 超时 kill（5-8s）；
- `network.refresh`/`network.details` 合并 + TTL 缓存 + NM `PropertiesChanged`
  信号订阅替代轮询；
- `audio.get`/`audio.applications`/`bluetooth.list`/`display.brightness.get`/
  `nightlight.get` 同样改事件驱动或缓存；`nightlight.get` 缓存 kwinrc 解析；
- 周期 op 加 per-op in-flight 去重。

## T4 [x] 无界 map / 缓存修剪（内存慢性泄漏）

**范围**：
- `ClipboardService.qml:34-36` — `thumbnails`/`_thumbFailed`/`_thumbPending`
  随历史轮转不修剪 → `_readList` 后按存活 record 修剪；
- `WindowService.qml:580-594` — `_thumbnailUrlsByHandle`/`_thumbnailPendingByHandle`
  关窗不清理、daemon 重启后 pending 卡死 → `_rebuild` 后按 `handles` 修剪 +
  transport 断开清空；
- `TrayNotificationBridge.qml:19-36` — `_lastSent` 定期清空或 LRU；
- `KWinBridge.cpp:409` — `m_commands` cap ~256；
- `data-service/main.go:822-843` — `TodayApps` 跨日重置、`UptimeByDay` 裁剪 90 天。

## T5 [x] 轮询 Timer 门控与事件化（空闲 CPU）

**范围**：`AppMenuService.qml:55-60`(500ms)、`ControlCenterService.qml:411-422`
(3s+1.8s)、`NetworkService.qml:210-215`(3s)、`WeatherService.qml:153-159`(10s)、
`MetricsService`/`ActivityUsageService`(10s)。

**修复内容**：
- 面板未打开时暂停：`ControlCenterService` 挂 `anyPanelOpen`；
- 有事件通道的（network/audio/weather）降级为 60-300s 兜底轮询；
- 所有轮询 `running` 绑定 `PlatformClient.socket.connected` 等连接状态；
- `AppMenuService` 500ms 轮询改为活动窗口/菜单变化驱动。

## T6 [ ] 不可见渲染收敛（空闲 CPU/GPU/内存）

**范围**：
- `DockInfoCarousel.qml:128-178` — 4 页按当前页门控 `visible`/Loader，
  marquee 与 live ShaderEffectSource 随页停；
- `DockIcon.qml:717-782` — ContextMenu/DockWindowPreview 改 Loader 懒加载
  或 Dock 级共享单例；预览 Image 加 `sourceSize`、去掉 `cache:false`；
- `DeskCenterWindow.qml` — 卡片 Loader `active` 追加 `card.visible`，
  musicNotes/marquee 跟随卡片可见性；
- `OverviewWindow.qml:394-402` — `previewImg` 加 `asynchronous: true`，
  缩略图请求限并发，去掉点击后多余 request。

## T7 [ ] KWin 快照链路性能

**范围**：`platform/src/kwin/KWinBridge.cpp`、`platform/kwin/window-bridge.js`。

**修复内容**：
- appId→iconName 解析正负缓存；fallback 目录全盘扫描移出主线程
  （QtConcurrent 或限定 hicolor 子目录）；
- `captureThumbnail`（`:185-336`）改 `QDBusPendingCall` 异步 + 全局并发上限，
  窗口关闭时清理 `m_thumbnailPaths` 与 PNG；
- 拖动期间几何快照降频或增量下发；
- `ensureDesktopIndex` 后台预热。

## T8 [ ] kos-data-service 修复

**范围**：`services/data-service/main.go`。

**修复内容**：
- `persist()` 降频（30-60s）或拆分高频 uptime 与冷数据，`snapshot.json`
  仅结构变化时写（当前估算写放大 ~1-2GB/天）；
- `sample()` 把 `exec df`、sysfs glob 移出锁外；`df` 改 `unix.Statfs`；
- `bufio.Scanner` 设 buffer 上限（1MB）+ 检查 `scanner.Err()`；
- 5s 全目录 reconcile 放宽到 30-60s。

## T9 [ ] kos-pim-service 写放大

**范围**：`services/pim-service/src/PimStore.cpp`。

**修复内容**：`changed`→widget snapshot 加 ~1s debounce；
`snapshot`/`eventsForRange` 直接构造 `QJsonObject` 去掉 stringify→parse 往返；
`save()` 可 debounce。

## T10 [ ] 红线违规收敛（QML 不得执行系统命令）

**范围**（PROJECT_CONTEXT.md code-review gate）：
- `ControlCenterPanel.qml:105-109` — `kcmshell6` → `settings.open` IPC（已存在）；
- `ControlCenterService.qml:404-405` — 移除 `qdbus6` fallback，daemon 内实现；
- `DesktopAppLauncher.qml:13-31` — `sh -c` → 固定 argv 或平台 IPC；
- `AppActionService.qml:33-43,101-107` — `execDetached`/`entry.execute()` →
  `application.launch` 扩展 deep-link 参数 + daemon 白名单；
- `TrayNotificationBridge.qml:21-60`、`DeskCenterWindow.qml:169-179` —
  `notify-send` → 内部 NotificationServer 或平台通知 op；TrayNotificationBridge
  `_sender` 复用改队列化；
- 8+ 个 `*ConfigService.qml` 的 `sh -c` JSON 持久化模板 → 共享
  `JsonConfigStore`（参考 `DeskCenterConfigService.qml` 的 QtCore `Settings` 先例）；
- `WallpaperColorSource.qml:77-98`、`ArtworkColorSource.qml:110-135` —
  `sh -c`+`find/awk`/`curl` → 受控服务；下载加大小上限与取消。

## T11 [ ] 零散正确性 bug

**范围**：
- `platform/src/daemon/Shortcuts.cpp:183-188` — `sh -c` 路径未加引号 →
  改 argv 数组 `startDetached(program, args)`（修空格路径失效+注入面）；
- `DesktopFilesService.qml:276-286` — `decodeURIComponent` try/catch +
  拒绝带 authority 的 file URL；
- `ScreenLifecycle.qml`、`WallpaperColorSource.qml:69-70` — `screens[1]`
  硬编码主屏 → 按平台下发 outputName 匹配；
- `QuickSearch.qml:119-138` — 粘贴超时分支校验 `activeWindowId ===
  _focusReturnId`，否则放弃注入；
- `AppMenuService.qml:30-52` — layout 回调校验 service/path 未变；
- `NetworkService.qml:71-86` — `_refreshDetails` 回调校验 device 未变；
- `data-service/main.go:1008` — scanner.Err() 检查（并入 T8 亦可）；
- `WallpaperColorSource.qml:78-84` — gawk 三参 match() 可移植性（并入 T10）。

---

## 已核实无问题（勿再查）

- NetworkTraffic 1s Timer 有 `running: visible` 门控；
- clipboard history ≤200、notification history ≤50、metrics history 固定 360；
- bluetooth 3s watchdog、wl-paste 2s 监督重启；
- socket 权限 0600、platform `cleanPath` symlink/穿越校验充分；
- `clipboard.set` 只写元数据不读文件内容；
- context-menu-input 仅 spy pointer press、D-Bus send() 无回复不阻塞；
- vendor blur texture 按尺寸缓存复用；
- AppLauncher 常驻窗口是 Qt 6.11 输出切换崩溃 workaround，**不要改**。

## 暂缓/待运行时确认

- qs 进程 303MB 匿名映射的具体构成（heaptrack/QSG_VISUALIZE 复核后
  再决定是否专项处理）；
- vendor/kwin-effects-glass `dynamicCorners` 全屏重绘（条件触发，低优先）。
