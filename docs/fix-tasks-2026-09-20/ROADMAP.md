# 修复任务路线图 · 2026-09-20

状态标记：`[ ]` 未开始 · `[~]` 进行中 · `[x]` 已完成并通过审查 · `[B]` 被依赖阻塞

> **阶段即 PR 边界**：每完成一个阶段合并一次 PR。阶段内任务可并行（无文件冲突），
> 跨阶段有依赖的任务必须串行（见 §依赖图 与 §并发分组）。

---

## 任务总览

| 任务 | 阶段 | 一句话 | 主要文件 | 依赖 | 并发组 |
|---|---|---|---|---|---|
| R1 [x] | 一 | data-service activity.snapshot map 竞争 panic | `services/data-service/main.go` | — | A |
| R2 [x] | 一 | data-service conn 写互斥 / 死锁 | `services/data-service/main.go` | R1(同文件) | A |
| R3 [x] | 一 | data-service 采样/persist 瘦身（df→statfs 等） | `services/data-service/main.go`,`weather.go` | R1,R2 | A |
| R4 [x] | 一 | KWin dock-animation 全屏重绘 + 每帧网格 | `integrations/kwin/dock-window-animation/*` | — | B |
| R5 [x] | 一 | KWin dock-animation 析构 UAF | `integrations/kwin/dock-window-animation/*` | R4(同文件) | B |
| R6 [x] | 一 | daemon 裸 D-Bus call 加超时 | `platform/src/daemon/PlatformServer.cpp` | — | C |
| R7 [x] | 一 | daemon file.copy 挪出事件循环 | `platform/src/daemon/PlatformServer.cpp` | R6(同文件) | C |
| R8 [x] | 一 | daemon network.refresh 异步化 | `platform/src/daemon/PlatformServer.cpp` | R6,R7 | C |
| R9 [x] | 一 | daemon socket 读缓冲上限 + 游标 | `platform/src/daemon/PlatformServer.cpp` | R6–R8 | C |
| R10 [x] | 二 | daemon 提供 `state.read/write`/`settings.launch`/`notify` 等 op | `PlatformServer.cpp`,`platform.v1.md` | R6–R9 | D |
| R11 [x] | 二 | 收敛 18 处 `sh -c` 配置写 → state op | 8 个 `*ConfigService.qml` | R10 | E |
| R12 [x] | 二 | 收敛 qdbus6/notify-send/sh-c 启动器 | `ControlCenterService`,`DesktopAppLauncher`,`TrayNotificationBridge`,`DeskCenterWindow` | R10 | E |
| R13 [x] | 二 | daemon Shortcuts exec 白名单 + argv | `platform/src/daemon/Shortcuts.cpp` | — | F |
| R14 [x] | 二 | daemon Wi-Fi 密码不走 argv | `PlatformServer.cpp` | R10 | D |
| R15 [x] | 二 | daemon clipboard.history.list 缓存 | `PlatformServer.cpp` | R10 | D |
| R16 | 三 | PimClient 去双 snapshot + PimStore 写放大 | `shared/pim/*`,`services/pim-service/*` | — | G |
| R17 | 三 | settings callShell 异步化 + 页面 LazyLoad | `apps/settings/src/main.cpp`,`main.qml` | — | H |
| R18 | 三 | settings 死代码/死方法清理 | `apps/settings/main.qml` | R17 | H |
| R19 | 三 | calendar itemsForDate 预建 map | `apps/calendar/qml/*` | — | I |
| R20 | 三 | music 搜索 debounce + 异步加载 + Menu 单例 | `apps/music/*` | — | J |
| R21 | 三 | PlaybackEngine bus 改 watch 驱动 | `apps/music/src/PlaybackEngine.cpp` | R20(同模块) | J |
| R22 | 三 | weather fallback 轮询门控 + buffer 上限 | `apps/weather/src/WeatherClient.cpp` | — | K |
| R23 | 四 | AppIcon 直通（mode==color 跳过 shader） | `shell/.../AppIcon.qml` 等 | — | L |
| R24 | 四 | card_shadow.frag 特判 + softness 降 | `shell/desktop/shaders/card_shadow.frag`,`KosCardShadow.qml` | — | L |
| R25 | 四 | OpacityMask 按激活态门控 | `LiquidNavBar.qml`,`LiquidGlassSwitch.qml` | — | L |
| R26 | 四 | WallpaperColorSource 轮询降频/mtime | `shared/qml/colorize/WallpaperColorSource.qml` | — | L |
| R27 | 四 | ColorScheme 结果 memoize + 异步 | `shared/qml/colorize/*.mjs`,`AppearanceTokens.qml` | R26(同目录) | L |
| R28 | 四 | 抽 JsonlClient 合并 PlatformClient/DataClient + 测试 | `shell/.../platform/*.qml` | — | M |
| R29 [x] | 五 | 零散小项（lockscreen timer、ApplicationRunner、Scanner、死命令等） | 多文件 | 视子项 | N |

---

## 阶段划分

### 阶段一 · 后端稳定性与帧率（P0 优先，先消panic/冻结/掉帧）
目标：消除必然 panic、daemon 冻结、KWin 掉帧。全部 C++/Go/ shader，不碰 QML 调用面。
- R1, R2, R3（Go 数据服务） — 同文件，**串行**
- R4, R5（KWin 动画插件） — 同文件，**串行**
- R6, R7, R8, R9（daemon PlatformServer.cpp） — 同文件，**串行**

> 三个串行链 A/B/C 之间**互相可并行**（不同文件树）。
> 阶段一合并一个 PR：`fix/2026-09-20-phase1-backend-stability`

### 阶段二 · daemon 能力补齐 + QML 红线收敛
目标：先在 daemon 补齐能力（R10），再把 QML 的 `sh -c`/`qdbus6`/`notify-send` 收敛过去。
- R10（daemon 新增 op）— **必须先做**，R11/R12/R14/R15 都依赖它
- R11, R12（QML 收敛）— 依赖 R10；彼此不同文件可并行
- R13（Shortcuts exec 白名单）— 独立文件，可并行
- R14, R15 — 依赖 R10 同文件，排在 R10 后

> 阶段二依赖阶段一的 PlatformServer.cpp 已稳定。等阶段一 PR 合并后从 `origin/main` 拉。
> PR：`fix/2026-09-20-phase2-daemon-ops-redline`

### 阶段三 · 应用层性能（独立进程，互不冲突）
目标：pim/settings/calendar/music/weather 各应用层卡顿。
- R16（pim）— 独立文件树
- R17,R18（settings）— 同文件，串行
- R19（calendar）— 独立
- R20,R21（music）— 同模块，串行
- R22（weather）— 独立

> G/H/I/J/K 五条链互相可并行。不依赖前两阶段，但为降低 rebase 噪声排在后端稳定后。
> PR：`fix/2026-09-20-phase3-app-performance`

### 阶段四 · 渲染/显存与 IPC 客户端
目标：GPU 收敛（FBO/shader）、颜色计算缓存、IPC 客户端合并与测试。
- R23,R24,R25（GPU/shader/控件）— 不同文件，可并行
- R26,R27（colorize）— 同目录，串行
- R28（JsonlClient 合并 + 测试）— 独立，可并行

> L 内部 R23–R25 并行、R26–R27 串行、R28 独立。
> PR：`fix/2026-09-20-phase4-render-ipc`

### 阶段五 · 收尾零散项
- R29：把 P2 里小而独立的项打包（lockscreen timer 门控、ApplicationRunner 停轮询、
  data-service Scanner buffer、pim 1Hz 轮询、kosctl 死命令、sddm 死配置、settings 拆文件建议等）。
> PR：`fix/2026-09-20-phase5-cleanup`

---

## 依赖图（硬依赖，必须串行）

```
R1 → R2 → R3                    (同 main.go)
R4 → R5                         (同 dockwindowanimationeffect.cpp)
R6 → R7 → R8 → R9 → R10 → R14   (同 PlatformServer.cpp)
                  R10 → R15
                  R10 → R11, R12(QML 收敛需 daemon 先有 op)
R17 → R18                       (同 settings/main.qml)
R20 → R21                       (同 music 模块)
R26 → R27                       (同 colorize 目录)
阶段一 → 阶段二                  (PlatformServer.cpp 需先稳定)
```

## 并发分组（同批可并行，组内文件不重叠）

- **组 A**：R1→R2→R3 串行链（data-service）｜整链与 B/C/D… 并行
- **组 B**：R4→R5（dock-window-animation）
- **组 C**：R6→R7→R8→R9（PlatformServer.cpp 阶段一）
- **组 D**：R10→R14,R15（PlatformServer.cpp 阶段二）
- **组 E**：R11 ∥ R12（不同 QML 文件）
- **组 F**：R13（Shortcuts.cpp 独立）
- **组 G**：R16（pim）｜**组 H**：R17→R18｜**组 I**：R19｜**组 J**：R20→R21｜**组 K**：R22
- **组 L**：R23 ∥ R24 ∥ R25；R26→R27｜**组 M**：R28｜**组 N**：R29

> **冲突红线**：PlatformServer.cpp 被 R6–R10,R14,R15 独占——它们必须串行，
> 任何两个不得同批并发改它。main.go 同理 R1–R3 串行。

---

## 已核实无问题 / 勿再查（本轮沿用上一轮结论 + 新确认）

- socket 权限 0600、`cleanPath` 校验、wl-paste 2s 监督、bluetooth 3s watchdog——上一轮已确认。
- `AppLauncher` 常驻窗口是 Qt 6.11 workaround，**不要改**。
- Liquid Glass 控件**无真实背景采样折射**（全是渐变矩形），勿再查"玻璃折射 GPU"。
- `icon_effect.frag` 本身极便宜，问题在 per-icon 的 layer FBO，不在 shader 算法。
- `KosPageCache` LRU 有界，无泄漏。
- `ArtworkColorSource` 的 `rescaleSize:48` 量化已正确。
- lockscreen/sddm greeter 是质量最高代码，改动保持其 Loader 故障隔离模式。

## 暂缓 / 待运行时确认

- qs 进程 303MB 匿名映射构成（heaptrack/QSG_VISUALIZE 复核后再定）。
- `vendor/kwin-effects-glass` dynamicCorners 全屏重绘（条件触发，低优先，且 vendor 代码）。
- settings/main.qml 4367 行单文件拆分为 `pages/*.qml`（工作量大，R29 给建议不强拆）。
