# T1 审查报告 — IPC 客户端断线语义

## 结论：PASS（第二轮审查通过）

## 范围

- `shell/desktop/modules/platform/PlatformClient.qml`
- `shell/desktop/modules/platform/DataClient.qml`
- 依赖 in-flight 标志的服务：
  `NetworkService`、`ClipboardService`、`DockTrashService`、
  `ControlCenterService`、`AppMenuService`、`NetworkTraffic`、
  `WindowService`、`AppearanceConfigService`、
  `ActivityUsageService`、`ShortcutsService`、
  `AppActionService`、`DesktopEnvironment`

预先存在的 `DockIcon.qml` 改动与本任务无关，未纳入审查与提交。

## 审查轮次

### 第一轮：FAIL（6 项问题，全部修复）

1. `PlatformClient.socket` / `DataClient.socket` 在惰性创建期间可为
   `null`，外部 `socket.connected` 直接解引用产生 TypeError。
   → 两个客户端新增受保护的 `connected` 只读属性，
   `AppActionService`/`DesktopEnvironment` 已迁移；`shell/` 下已无
   `Client.socket` 外部解引用。
2. 30s 默认超时对长操作过短（截图、大文件复制、Wi-Fi/蓝牙关联）。
   → `PlatformClient` 新增 `requestTimeoutOverrides` 表：
   关联类 90s，交互截图与文件传输 0（禁用超时）。
3. `ClipboardService` 对传输层失败也置 `_thumbFailed`，永久阻止缩略图
   重试。 → 仅 daemon 侧真实失败才标记；`disconnected`/`timeout`/
   `queue-overflow` 保持可重试。
4. `theme.sync-glass` / `theme.sync-dock-animation` 写操作断线丢失且
   不重发。 → `AppearanceConfigService` 重连时重启两个同步定时器。
5. `activity.active-app` 写操作断线丢失。 → `ActivityUsageService`
   重连时重发当前前台应用。
6. 旧 socket 延迟销毁期间其信号仍可能驱动客户端状态。
   → 初版用 `client.socket !== socketInstance` 身份检查，运行时发现
   QLocalSocket 在 `createObject()` 内部同步发出 `connected()`（早于
   `socket` 属性赋值），导致身份检查吞掉所有真实 connect 事件、
   `transportChanged(true)` 从未发出。最终方案：替换前给旧 socket 置
   `stale`，处理器检查 `socketInstance.stale`；组件内 `connected: false`，
   由 `onSocketChanged`/`onEnabledChanged` 在赋值完成后再置
   `socket.connected = enabled`。

### 第二轮：PASS（5 项非阻塞建议，其中 3 项已顺手修复）

已修复：

- `file.open-with` 实为幂等查询，已加入 `readOperations`；
- 断线写操作的快速失败回调改经 `_invokeCallbacks`，与其他失败路径
  一样受 try/catch 保护；
- 超时/被逐出的队列项现在同时从 `_queue` 摘除（`_dropQueued`），
  不会在重连时把死消息写向 daemon。

保留为已知限制（记录即可，不阻塞）：

- `_reconnectTimer` 每 2s 重建 socket，理论上可中断一次仍在进行的
  connect；本地 socket 连接近乎瞬时，实际无影响；
- `DataClient` 未设超时覆盖表：当前所有 data 操作均为快速本地操作，
  30s 足够。

## 关键正确性核验

- 每条 pending 记录经由响应/超时/溢出/断线恰好一条终态路径移除；
- 去重仅作用于排队中的读请求，同 key 保留最新并合并 callbacks；
- `_queuedByKey` 在被取代/发送/失败/断线各路径一致清理；
- `_failAll` 先快照再回调，回调内可安全重入 `request()`；
- 断线写操作经 `Qt.callLater` 异步失败，保持回调时序一致；
- 服务侧 in-flight 标志在 `transportChanged(false)` 全部复位
  （ControlCenter 11 项 + `_bluetoothPollTimer`、NetworkService 5 项、
  Clipboard 2 项、DockTrash 2 项、AppMenu `requestPending`、
  NetworkTraffic `_samplePending`、WindowService KWin 订阅/缩略图/
  快照状态）。

## 验证记录

- `node tools/qmllint-changed.mjs`：无真实语法错误（15 文件）。
- `./tools/kosctl build`：通过（ninja no-op + ts/mo 生成）。
- 运行时（Quickshell 独立实例 + fake daemon，
  `KOS_PLATFORM_SOCKET`/`KOS_DATA_SOCKET` 指向测试套接字）：
  - 正常路径请求/响应/事件正常；
  - 杀 daemon → `platformConnected:false`，写操作快速失败
    （日志可见 `shortcuts.apply` 等报 `platform daemon unavailable`）；
    读请求排队去重，30s 超时后 flag 释放（`appmenu.active`、
    `audio.applications` 以 ~35s 周期恢复重试而非卡死）；
  - daemon 静默（不应答）场景确认超时回调释放 in-flight 标志；
  - 重启 daemon → ~2s 内重连，`transportChanged(true)` 触发全部
    重发（`kwin.subscribe`、`clipboard.history.*`、`file.trash-state`、
    `shortcuts.apply`、`theme.sync-*` 各恰好一次），首个 6s 窗口内
    无写操作重放风暴；
  - 仅出现预期的 `PeerClosedError`/`ServerNotFoundError` socket 告警，
    无 QML TypeError/ReferenceError。
