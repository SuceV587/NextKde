# T3 审查报告 — kos-platform 子进程风暴 + runCommand 超时

**审查人**：只读子代理（两轮）+ 运行时实测
**结论**：PASS（首轮发现 2 项 major + 4 项 minor，均已修复并复审确认）

## 修复范围

`platform/src/daemon/PlatformServer.cpp` / `PlatformServer.h`

- `runCommand` 统一 watchdog（默认 8s，`0` 为交互式工具显式豁免）+
  `cacheKey`/`cacheTtlMs` 回复缓存 + per-key in-flight 去重（排队 socket 共享
  单次抓取结果）。
- 所有裸 `QProcess` 站点挂 `armProcessWatchdog` + `errorOccurred`
  （`disconnect(finished)` 防止 crash 双应答）；`QProcess::execute` 全部移除
  （`theme.sync-glass` 改 watchdog 异步链，`theme.sync-dock-animation` 走
  `runCommand`）。
- `network.refresh`/`network.details` → NM D-Bus `GetAll` +
  `PropertiesChanged` 订阅失效；`network.scan` 保留 nmcli（watchdog 25s）。
- `bluetooth.list` → BlueZ `ObjectManager` `GetManagedObjects` +
  `InterfacesAdded/Removed`/`PropertiesChanged`；无控制器时不启动
  bluetoothctl。
- `audio.get`/`audio.applications` → 缓存 `runCommand`（TTL 30s）+ 常驻
  `pactl subscribe` watcher 失效 `audio.*`。
- `display.brightness.get` → KDE 亮度 D-Bus + `brightnessctl` 兜底；
  `nightlight.get` 缓存 kwinrc/KWin 状态。
- TTL：失败 5s、network 15s、bluetooth 20s、audio 30s、brightness/nightlight
  10s；所有写操作在执行前失效本域缓存。

## 首轮发现与修复

| 级别 | 问题 | 处理 |
|---|---|---|
| major | 异步 lambda 捕获裸 `QLocalSocket*`，`clientDisconnected` 的 `deleteLater` 后 `respond` 解引用悬垂指针 | 全部改 `QPointer<QLocalSocket>` + `respond(guardedSocket.data(), …)` |
| major | `theme.sync-glass`/`theme.sync-dock-animation` 用 `QProcess::execute`（`waitForFinished(-1)`）冻结事件循环 | 前者改 watchdog 异步链，后者改 `runCommand(10s)` |
| minor | BlueZ 缺席时早退未武装 ObjectManager watch | `hasHardware` 即 `watchBluezManager()` |
| minor | watch 集合单调增长 | `InterfacesRemoved` 中 prune `m_bluezWatchedPaths` |
| minor | manager GetAll 瞬时失败误报 `wifiEnabled:false` | 空 map → 可重试 `network-unavailable` |
| minor | `pactl subscribe` 缺 `errorOccurred` 重启路径 | 与 `finished` 共享退避重启 lambda |
| minor | `theme.sync-glass` step 链 shared_ptr 自循环泄漏 | 改 `weak_ptr` 捕获 |

已接受并留档：串行同步 D-Bus 扇出（每调用 ≤2s 上限）；`timeoutMs==0`
交互式进程在客户端断开时留存（xdg-open/dolphin/screenshot 有意豁免）。

## 已核验项

- **契约形状**：`{version,requestId,ok,result|error:{code,message,retryable}}`
  不变；socket 0600 不变；协议版本 1；无新增 operation；结果字段均为增量。
- **watchdog 覆盖**：全部 `new QProcess` 有 `armProcessWatchdog`，例外仅两个
  有意常驻 watcher（wl-paste×2、pactl subscribe）与交互式 opt-out。
- **watchdog 行为**：kill → `errorOccurred(Crashed)` 先于 `finished`，
  `timedOut` 先置位 → 正确产出 `command-timeout`；双应答由共享 `replied`
  或 `disconnect(finished)` 阻断。
- **in-flight 去重**：所有终态路径恰清一次；QPointer socket 使断开客户端
  安全跳过。
- **D-Bus 解组**：GetAll `a{sv}` → QVariantMap；`AddressData` `aa{sv}` 显式
  QDBusArgument；`GetManagedObjects` `a{oa{sa{sv}}}` 嵌套 QMap；SLOT() 签名
  与 NM/BlueZ/KWin 一致。
- **安全**：全部 argv 数组（SSID/密码/UUID 不经 shell）；device/uuid 正则
  校验保留；socket 权限不变。

## 运行时实测

- 稳态 3s 轮询 30s 采样（100ms 粒度）：daemon 子进程仅 3 个常驻 watcher，
  **0 个短生命周期 fork**（原 ~140-180/min → ≈0/min，缓存未命中时 ≤2/min）。
- 假 `wpctl`（sleep 300）测试：`audio.get` 8.1s 后返回 `command-timeout`，
  子进程被 kill，无残留；5 并发 `audio.get` 只产生 1 个子进程、统一应答。
- 写失效：`audio.set-mute` 后下一次 `audio.get` 立即返回新状态；
  `nmcli radio wifi off/on` 经 `PropertiesChanged` 即刻失效缓存。
- 面板数据正确性：network.refresh/details（ipv4/ssid/信号）、bluetooth.list
  （powered）、audio、brightness、nightlight 均与真实状态一致。
- daemon 多次重启期间运行中的 shell 无卡死（T1 断线语义生效）。

已知噪音：Qt6 对收到消息的数组 demarshal 会打印 `QDBusArgument: write from
a read-only object`（良性 Qt 警告，仅缓存未命中时出现）。
