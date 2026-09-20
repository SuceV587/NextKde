# T4 审查报告 — 无界 map / 缓存修剪

**审查人**：只读子代理一轮 + 父代理复审修复
**结论**：PASS（首轮 0 major / 2 minor / 3 nit，minor 与相关 nit 已修复）

## 修复范围

- `shell/desktop/modules/quicksearch/ClipboardService.qml` —
  `_readList` 末尾 `_pruneThumbnails()`：以存活 `entries[].record` 重建
  `thumbnails`（有淘汰才替换并 bump `thumbnailRevision`），就地清理
  `_thumbFailed`/`_thumbPending`；`clearAll` 顺带清 `_thumbPending`。
- `shell/desktop/modules/dock/WindowService.qml` — `_rebuild` 末尾按存活
  `handleId` 重建 `_thumbnailUrlsByHandle`/`_thumbnailPendingByHandle`；
  `thumbnail` 事件入口增加存活校验，迟到事件不再复活死 handle；
  transport 断开清空两 map（T1 已实现，本次复核确认闭环）。
- `shell/desktop/modules/bar/TrayNotificationBridge.qml` — 60s 周期
  `_dedupeSweep` 删除超过 `dedupeIntervalMs` 的 `_lastSent` 键。
- `platform/src/kwin/KWinBridge.cpp` — `Enqueue` 入队后 cap 256，丢最旧。
- `services/data-service/main.go` — `Activity` 新增 `todayAppsDay` 字段；
  `rollDay(now)` 在 `settle`（每秒）与 `newService`（启动）执行：日界
  变化时重置 `TodayApps`（保留仍前台 app 的 Name/Icon），`UptimeByDay`
  按 ISO 键字典序裁剪保留最新 90 天；`addInterval` 删除死代码 appID
  分支（调用点从未传非空值）。
- `services/data-service/main_test.go` — 新增 3 个 `rollDay` 测试
  （跨日重置、同日保留、90 天裁剪 newest 存活/oldest 删除）。

## 审查发现与处理

| 级别 | 问题 | 处理 |
|---|---|---|
| minor | WindowService `!changed`/placement-only 早退跳过 prune：迟到的死 handle `thumbnail` 事件会复活 URL 直到下次 presentation 变化 | 已修：thumbnail 事件写入前 `records.some(handleId === event.id)` 存活校验 |
| minor | 跨午夜 rollDay 重置后，持续前台 app 的 TodayApps 条目丢 Name/Icon 直至下次焦点切换 | 已修：rollDay 重置时 carry 前台 app 的 Name/Icon（Seconds 归零） |
| nit | `addInterval` 的 `appID != ""` 分支为死代码且绕过日界校验 | 已修：删除参数与分支 |
| nit | `clearAll` 不清 `_thumbPending` | 已修 |
| nit | 旧 state.json 升级即清空 `TodayApps` | 接受：旧数据本就跨日混合，属设计取舍 |

## 已核验项

- **不误删存活条目**：pinned 剪贴板行走 `item.thumbnailPath` 不经
  `thumbnails` map；窗口 prune 以 `record.handleId` 为准，foreign
  provider（handleId=""）不进入 live 集合。
- **响应式**：`thumbnails`/`_thumbnailUrlsByHandle` 均为整体替换 +
  `thumbnailRevision++`；`_thumbPending`/`_thumbFailed`/`_lastSent`
  无绑定依赖，就地 delete 安全。
- **时序**：in-flight `clipboard.thumb`/`kwin thumbnail` 回调对已 prune
  key 的写入有界——剪贴板下次 `_readList` 再清，窗口事件入口直接拦截。
- **加锁**：`rollDay` 生产调用点均在 `s.mu` 下（persist/settleTick/
  active-app 经 settle）；`newService` 无锁调用发生在 goroutine 启动前。
- **兼容**：`todayAppsDay` 为 omitempty 增量字段，`{ok,result,error}`
  契约不变；`activity.snapshot` 消费方只读 `todayApps`/`uptimeByDay`。
- **约束**：无新增 QML 系统命令执行；改动限定 T4 声明范围；未动
  "已核实无问题"清单项。

## 验证

- `./tools/kosctl build`：通过（kos-platform 编译链接、data-service 构建）。
- `node tools/qmllint-changed.mjs`：4 个改动 QML 文件无真实语法错误。
- `go test ./services/data-service`：全部通过（含 3 个新测试）。
- `gofmt -l`：改动文件干净（weather_test.go 为存量未格式化，未触碰）。

验收条目对应：剪贴板三 map 随每次 `_readList` 收敛到存活 record 数
（≤maxItems）；窗口 map 随 `_rebuild` 收敛到存活 handle 数；daemon 重启
由 T1 断开清空 + 事件存活校验保证 pending 不卡死；`UptimeByDay` 恒 ≤90。
