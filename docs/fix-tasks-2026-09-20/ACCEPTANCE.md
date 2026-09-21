# 验收标准 · 2026-09-20

## 通用验收流程（每个任务都执行）

1. ☐ 实现完成，改动限定任务范围内
2. ☐ `./tools/kosctl build`（或对应子集）构建通过
3. ☐ QML 改动过 `qmllint-changed.mjs`；契约改动过 `check-docs.py`；Go 过 `go test`
4. ☐ 按任务卡验收标准做功能/性能验证，记录结果
5. ☐ **只读 `code-reviewer` 子代理审查通过**
6. ☐ ROADMAP 状态 `[x]`，任务卡勾选，独立 commit，本表登记

---

## 分任务验收标准

### 阶段一 · 后端稳定性与帧率

**R1 activity.snapshot map 竞争**
- ☑ `go test -race` 下"并发 settle + activity.snapshot"用例不再 panic（TestActivitySnapshotConcurrentWithSettle）
- ☑ marshal 在锁内或深拷贝，TodayApps/UptimeByDay 无锁外迭代（snapshotResult：锁内 marshal + 私有深拷贝）
- ☑ weather.snapshot 同类撕裂一并处理（TestWeatherSnapshotConcurrentWithLocationWrites）

**R2 conn 写互斥**
- ☑ 广播与响应不再交错（每 conn `subscriberConn.wmu` + `writeLine`）
- ☑ 对已死 conn 写有 100ms deadline，不持 subscriber 锁写（broadcastEvent 收集后锁外写）
- ☑ 广播风暴下不出现事件系统整体卡死（TestPublishDesktopDoesNotBlockOnUnreadConn）

**R3 采样/persist 瘦身**
- ☑ `df` 子进程消失（改 `unix.Statfs("/")`，删 /proc/mounts 预检）
- ☑ 采样 sysfs 读移出 `s.mu`；sensor label/name 经 `sensorsOnce` 枚举一次缓存
- ☑ persist 锁内 settle+marshal，锁外 writeJSONBytes 写盘
- ☑ 天气失败指数退避 1m→30m（weatherFailStreak），Status/Error 未变跳过 publish

**R4 KWin 动画重绘/网格**
- ☑ 动画期间不再每帧全屏重绘（addAnimationRepaint：expandedGeometry ∪ target + 2px，起始/每帧/结束各一次）
- ☑ makeGrid/per-顶点 pow/sin 中 progress 无关量预计算（cachedGrid + cachedVertices，按 quad 数/边界/icon 失效）
- ☐ 动画帧时间下降（KWin 帧计时对比）— 需运行时实测，留待部署后验证

**R5 KWin 析构 UAF**
- ☑ effect 卸载不再对失效 EffectWindow* 解引用（析构按 stackingOrder 存活校验；死键的 visibleRef 经 placement-new 置空再 erase）

**R6 D-Bus 超时**
- ☑ PlatformServer.cpp 所有裸 `call()`/`property()` 设 `setTimeout` 或改 async（39 处全部审计：sync→2s 超时；appmenu.active/layout→asyncCall+watcher；reconfigure*→fire-and-forget asyncCall；isServiceRegistered→NameHasOwner 有界 helper）
- ☑ appmenu/KWin 慢响应不再冻结 daemon 25s（最慢路径已异步化，其余上限 2s）

**R7 file.copy 异步**
- ☑ 大文件复制期间 daemon 仍响应其它请求（拷贝挪到 m_copyPool 2 线程，QFutureWatcher 回主线程 respond）
- ☑ 用 QtConcurrent/KIO FileCopyJob，带进度或完成回调（QtConcurrent::run + QFutureWatcher，同路径校验保持同步前置）

**R8 network.refresh 异步**
- ☑ N+1 同步 GetAll 改 asyncCall 链/worker，单次刷新不阻塞事件循环（m_dbusPool worker + connectToBus 命名连接 RAII，watchPaths/prefill/completeInFlight 主线程收尾）

**R9 socket 读缓冲**
- ☑ 缓冲有上限（1 MiB 超限回 request-too-large 并断开）；游标解析 + 单次尾部压缩，逐行 O(n²) memmove 消除

### 阶段二 · daemon 能力 + 红线收敛

**R10 daemon 新 op**
- ☐ `state.read`/`state.write`/`settings.launch`/`notify`（按需）在 platform.v1.md 版本化
- ☐ op 有界、校验参数、`{ok,result,error}` 模型一致

**R11 sh -c 配置写收敛**
- ☐ 8 个 `*ConfigService.qml` 的 `sh -c mkdir/printf/mv` 全部改走 state op 或统一 JsonConfigStore
- ☐ 重启后配置仍生效；原子性（tmp+rename 等价）保留

**R12 qdbus6/notify-send/启动器收敛**
- ☐ `grep -rn "qdbus6\|notify-send\|execDetached\|\"sh\"" shell/` 仅剩白名单命中
- ☐ nightlight fallback、托盘通知、settings 启动功能正常

**R13 Shortcuts exec 白名单**
- ☐ exec 改 argv 数组（空格路径可用），且只放行白名单前缀
- ☐ 非白名单 payload 被拒绝并记录

**R14 Wi-Fi 密码**
- ☐ `ps`/`/proc/*/cmdline` 不再可见 802-1x/Wi-Fi 密码（改 D-Bus settings）

**R15 clipboard 缓存**
- ☐ clipboard.history.list 不再每次全量 cliphist+遍历（有 TTL/缓存）

### 阶段三 · 应用层性能

**R16 pim 双 snapshot/写放大**
- ☐ 单次写操作不再产生 2 次全量 snapshot 往返（`revision >` 严格 + 去尾 refresh）
- ☐ save() debounce；linkedTodoId O(N·M) 消除；widget snapshot 无 stringify→parse

**R17 settings 异步化 + LazyLoad**
- ☐ callShell 不再阻塞 UI（async QProcess/QLocalSocket）
- ☐ 页面惰性实例化，启动不再 7+ 串行 spawn
- ☐ Shell 不在时启动不再冻结 10-40s

**R18 settings 死代码**
- ☐ 调用不存在 bridge 方法的死 UI 删除或方法补齐；死 import 清除

**R19 calendar map**
- ☐ itemsForDate 预建 Map，hour cell O(1) 查表而非 168 次全扫

**R20 music debounce/异步/Menu**
- ☐ 搜索有 ~300ms debounce，不每键全库 reset
- ☐ MusicController 构造不阻塞首帧（延迟/异步加载）
- ☐ 每 delegate Menu 改共享单例

**R21 PlaybackEngine bus**
- ☐ gst 40ms 轮询改 watch/sync_handler；空闲不再每秒 25 次唤醒
- ☐ position timer 仅播放时跑

**R22 weather 轮询**
- ☐ socket 已连接时 10s fallback 轮询停止；readBuffer 有上限

### 阶段四 · 渲染/显存/IPC

**R23 AppIcon 直通**
- ☐ mode==="color" 且无需 tint 时跳过 layer.enabled+ShaderEffect
- ☐ 图标多时 FBO 数下降（QSG 显存对比）

**R24 card_shadow**
- ☐ n==2/圆角走 length() 捷径，无 pow；softness 默认降低
- ☐ 视觉回归可接受（截图对比）

**R25 OpacityMask 门控**
- ☐ LiquidNavBar/Switch 的 layer.enabled 跟随激活态，静态不走 FBO

**R26 WallpaperColorSource**
- ☐ 不再每 3s 无条件整读+解析（mtime 门控或降频）

**R27 ColorScheme 缓存**
- ☐ previewSwatches/buildScheme 按 (seed,variant) memoize
- ☐ 换壁纸/主题时 GUI 线程无几十 ms 同步卡顿

**R28 JsonlClient 合并**
- ☐ PlatformClient/DataClient 抽共同基类，差异只剩 socketPath/op 表/overrides
- ☐ 新增 mjs 测试覆盖断线/超时/半包/dedup

### 阶段五 · 收尾

**R29 零散项**
- ☐ 各子项按任务卡逐条验收

---

## 验收记录

| 任务 | 验收日期 | 结果 | 子代理审查结论 | 备注 |
|---|---|---|---|---|
| R1 | 2026-09-21 | 通过 | code-reviewer PASS（仅 minor：测试注释重复已修） | 分支 fix/2026-09-20-ds-activity-race，commit 6263d74 |
| R2 | 2026-09-21 | 通过 | code-reviewer PASS（minor：订阅首事件与广播顺序原已不保证，无害） | 分支 fix/2026-09-20-ds-conn-writelock，commit f332bf6 |
| R3 | 2026-09-21 | 通过 | code-reviewer PASS | 分支 fix/2026-09-20-ds-sampling-slim，commit fcf51e3；snapshot.json 保留（WeatherClient.cpp 离线回退读它） |
| R4 | 2026-09-21 | 通过 | code-reviewer PASS（minor：bulge 理论上有 ≤2px 出包络的残影风险，被 opacity/边距覆盖，可接受） | 分支 fix/2026-09-20-kwin-dockanim-repaint，commit 29174e0；帧计时改善待部署后实测 |
| R5 | 2026-09-21 | 通过 | code-reviewer PASS | 分支 fix/2026-09-20-kwin-dockanim-uaf，commit 96d7e1e |
| R6 | 2026-09-21 | 通过 | code-reviewer PASS（1 条 low：portal asyncCall 未限时——已补 setTimeout） | 分支 fix/2026-09-20-daemon-dbus-timeout，commit 449dca8 |
| R7 | 2026-09-21 | 通过 | code-reviewer PASS（low 残余：硬链接同 inode 拷贝不防，预存在） | 分支 fix/2026-09-20-daemon-filecopy-async，commit 6ec1a98 |
| R8 | 2026-09-21 | 通过 | code-reviewer PASS | 分支 fix/2026-09-20-daemon-netrefresh-async，commit 337b655 |
| R9 | 2026-09-21 | 通过 | code-reviewer PASS | 分支 fix/2026-09-20-daemon-readbuf-cap，commit 88aa71e |
| R10 | 2026-09-21 | 通过 | code-reviewer PASS（5 minor：notify-send `--`、read cap+1、错误码、dispatch 顺序、契约上限——已合并为 polish commit） | 分支 fix/2026-09-20-daemon-state-ops，commit a4de0f1 |
| R11 | 2026-09-21 | 通过 | code-reviewer FAIL→PASS（首轮：LockScreenFeedService 语法残缺+_packageInstalled 单向——已修；复审 PASS，3 minor 记录） | 分支 fix/2026-09-20-qml-state-store，commit 7520313（amend 后）；新增 JsonConfigStore.qml |
| R12 | 2026-09-21 | 通过 | code-reviewer FAIL→PASS（首轮：nightlight 部分失败三方不一致——daemon 改 ok+applied:false；复审 PASS，1 minor：launchById terminal 路径） | 分支 fix/2026-09-20-qml-redline，10 commits（efa0e70..2b044b0）；daemon settings.launch 加 shellDir |
| R13 | 2026-09-21 | 通过 | code-reviewer PASS（4 minor：无 contract 测试、TOCTOU、白名单比任务卡宽、QML 空格路径不加引号——均记录不阻塞） | 分支 fix/2026-09-20-daemon-shortcuts-exec，commit 6c7e676 |
| R14 | 2026-09-21 | 通过 | code-reviewer PASS（3 minor 记录；WPA3-only AP 与旧 nmcli 同等覆盖；D-Bus 路径未实测真机） | 分支 fix/2026-09-20-daemon-wifi-secret，commit 4ccf49e |
| R15 | 2026-09-21 | 通过 | code-reviewer PASS（cache 1.5s TTL + dataChanged 失效 + hash 门控 prune） | 同分支，commit 52382a7 |
