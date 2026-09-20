# T5 审查报告：轮询 Timer 门控与事件化

## 结论

**PASS WITH NOTES**（2026-09-20 子代理审查；遗留问题经用户确认留待后续修复）

## 改动摘要

- `ControlCenterService.qml` — 新增 `_openPanelCount` 引用计数 +
  `readonly anyPanelOpen` + `notePanelOpen()`，面板打开即 `refresh()`；
  `refreshTimer` 3s（面板开）/120s（兜底），`running: PlatformClient.connected`；
  `audioApplicationsTimer` 仅面板打开时运行。
- `BarStatusArea.qml` — `_panelOpenRegistered` + `onAnyPanelOpenChanged` 向
  `ControlCenterService` 注册/释放；`Component.onDestruction` 兜底。
  （范围外文件，但它是 `anyPanelOpen` 既有定义处，是面板可见性上报的唯一
  自然归属点。）
- `NetworkService.qml` — `_panelOpen` 绑定 `ControlCenterService.anyPanelOpen`；
  `refreshTimer` 3s/60s，`running: PlatformClient.connected`。
- `WeatherService.qml` — `fallbackReload` 10s→300s，`running: DataClient.connected`
  （`weather.changed` 事件已是主驱动）。
- `MetricsService.qml`/`ActivityUsageService.qml` — 10s 间隔保留（Bar 温度、
  DeskCenter 活动卡常显，无事件通道），仅 `running: DataClient.connected`。
- `AppMenuService.qml` — 移除 500ms 轮询；改由 `WindowService.activeWindowId`
  变化驱动 + 1.5s `_settleTimer` 补偿在途请求陈旧 + `items` 为空时
  5×1.2s 有界 `_recheckTimer` + 60s `_floorTimer`（`running` 绑定 connected）。

## 验证记录

- `./tools/kosctl build` 通过；`./tools/qmllint-changed.mjs` 8 文件无错误。
- `quickshell --path shell` 实测：`Configuration Loaded`，无新告警。
- UNIX socket 中继抓包（面板全关、空闲 ~72s）：

  | 操作 | 修复前 | 修复后 |
  |---|---|---|
  | `appmenu.active` | 249 | 2 |
  | `audio.applications` | 97 | 1 |
  | `audio.get`/`bluetooth.list`/`display.brightness.get`/`nightlight.get` | 各 42 | 各 1 |
  | `network.refresh`/`network.details` | 各 42 | 各 2 |
  | `weather.snapshot` | 14 | 2 |
  | `metrics.snapshot`/`activity.snapshot` | 各 14 | 各 8（10s 保留） |

  平台 socket 空闲请求 ≈ 565→16 次/72s（-97%）。
- 空闲进程 CPU（/proc stat utime+stime，60s 窗口）：55 → 43 jiffies（-22%）。

## 审查确认点

- 引用计数无泄漏：所有面板打开路径（NetworkStatus 点击、ControlCenterToggle、
  `toggleRequested` IPC）都汇聚到 `visible`/`isOpen` 绑定统一注册；
  Loader 卸载路径经 `controlCenter`→null→`controlCenterOpen` false 释放。
- `refresh()` 的 `same address && items>0` 早退为既有语义，非本次回归；
  同地址布局不重取与旧 500ms 轮询行为一致。
- 断线时序安全：`_failAll` 先于 `transportChanged` 执行，回调中武装的
  `_recheckTimer` 随即被 disconnect 分支停止。
- 无新增红线违规、无契约变更、未触碰 documented workaround。

## 已确认的滞后语义（规格内取舍）

- 外部音量变更（媒体键/其他应用）在 DeskCenter 音量环上最多滞后 120s
  （原 3s）；托盘网络状态最多滞后 60s。若需消除需 daemon 推送
  `audio.changed`/`network.changed` 事件（跨任务建议）。
- Wi-Fi 加入对话框（`networkDialogOverlay`）打开期间不计入 `anyPanelOpen`
  ——对话框状态由自身请求驱动，功能正确，留档防误改。

## 遗留问题（用户确认延后处理）

1. `BarStatusArea.qml` 析构期间绑定重算可能使单实例 -2 释放计数
   （低概率，自愈；建议 onDestruction 释放后置 `_panelOpenRegistered=false`）。
2. `AppMenuService.qml` 慢 daemon 响应 + settle 被 `requestPending` 跳过时，
   菜单最长陈旧 ~60s（建议 `_refreshQueued` 脏标记）。
3. `ControlCenterService.qml:429-430` 注释与实际不符——`refresh()` 无条件
   调用 `refreshAudioApplications()`，120s 兜底实际也会刷新应用列表。
4. 跨任务方向：daemon 推送 `audio.changed`/`network.changed`/`metrics.changed`
   事件后可进一步放宽兜底。
