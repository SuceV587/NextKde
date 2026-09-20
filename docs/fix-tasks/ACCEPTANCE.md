# 验收标准

## 通用验收流程（每个任务都执行）

1. ☐ 实现完成，改动限定在任务范围内
2. ☐ `./tools/kosctl build`（或对应子集）构建通过
3. ☐ QML 改动过 `qmllint-changed.mjs`；契约改动过 `check-docs.py`
4. ☐ 按任务验收标准做功能/性能验证，记录结果
5. ☐ **子代理审查通过**，报告存 `reviews/T<n>-review.md`
6. ☐ ROADMAP 状态更新为 `[x]`，独立 commit

## 分任务验收标准

### T1 IPC 断线语义
- ☑ daemon 停止 5 分钟期间，`_queue`/`_pending` 不持续增长（有上限/去重）
- ☑ 断线期间的写操作（清空回收站等）不在重连后重放
- ☑ daemon 重启后：Wi-Fi 面板按钮、剪贴板历史、回收站、关机按钮、
  appmenu 全部恢复可用（无 in-flight 卡死）
- ☑ 请求超时时回调收到失败而非永远悬挂
- ☑ 正常（daemon 在线）请求路径行为不变

验证记录见 `reviews/T1-review.md`。

### T2 托盘菜单黑角
- ☐ 右键托盘图标，菜单四个角**无黑色方块**（圆角处正确透明）
- ☐ 菜单项点击/悬停/子菜单/勾选态工作正常
- ☐ 菜单定位仍锚定图标（各 dock 边/bar 边不错位）
- ☐ 若采用方案 A：补丁接入构建脚本，重装后验证；若方案 B：菜单为
  liquid-glass 风格且 `QsMenuAnchor` 路径无遗留使用者
- ☐ 托盘图标悬停高亮与菜单可见态联动正常

### T3 kos-platform 进程风暴
- ☐ 稳定状态下每分钟 fork/exec 数从 ~140-180 降到 <20（用
  `perf trace -e execve -p <pid>` 或 bpftrace 统计）
- ☐ wpctl/nmcli 等子进程卡死时（模拟）8s 内被 kill，不堆积
- ☐ 控制中心面板数据仍正确刷新（音量/蓝牙/亮度/夜灯/网络）

### T4 无界 map 修剪
- ☐ 剪贴板历史轮转淘汰后，三个 map 键数不随历史增长
- ☐ 窗口关闭后 `_thumbnailUrlsByHandle`/`_thumbnailPendingByHandle` 键被清
- ☐ daemon 重启后窗口缩略图仍可重新请求
- ☐ data-service 跨日后 `TodayApps` 重置、`UptimeByDay` ≤90 键

### T5 轮询门控
- ☐ 控制中心未打开时无周期性 audio/bluetooth/brightness 请求
- ☐ daemon 断开期间无持续入队（配合 T1）
- ☐ 面板打开时数据仍在合理时间内刷新

### T6 不可见渲染收敛
- ☐ DockInfoCarousel 非当前页 marquee/live 采样停止（QSG 帧时间对比）
- ☐ DockIcon 不右键/不悬停时不存在其 popup 的 QWindow
- ☐ 预览缩略图不再全尺寸解码（内存峰值对比）
- ☐ DeskCenter 卡片隐藏时其动画停止

### T7 KWin 快照链路
- ☐ 拖动窗口期间 daemon CPU 下降、无每窗口 O(N) 图标重扫
- ☐ 新 appId 首次出现不再主线程扫图标目录（无数百 ms stall）
- ☐ 缩略图捕获不阻塞 daemon 其他请求（并发请求仍响应）
- ☐ 窗口关闭后 thumbnail PNG 被清理

### T8 data-service
- ☐ persist 写盘字节数显著下降（`pidstat -d` 前后对比）
- ☐ df 子进程消失，采样不持锁
- ☐ 超大行输入不再静默断连（有 buffer 上限 + 错误日志）

### T9 pim-service
- ☐ 连续批量编辑 N 条时写文件次数从 N×3 降到 ~3（debounce）
- ☐ snapshot/eventsForRange 无 stringify→parse 往返

### T10 红线收敛
- ☐ `grep -rn "execDetached\|\"sh\"\|qdbus6\|kcmshell6\|notify-send" shell/ shared/`
  仅剩白名单内命中（无则全清）
- ☐ settings 打开、nightlight 切换、托盘通知、深链启动功能正常
- ☐ 配置持久化全部走统一路径，重启后配置仍生效

### T11 零散 bug
- ☐ 含空格路径下全局快捷键可用
- ☐ 拖入含非法 % 的 URL 不再静默失败
- ☐ 粘贴超时后焦点窗口变化时不再注入剪贴板
- ☐ 快速切换应用时全局菜单不串台

## 验收记录

| 任务 | 验收日期 | 结果 | 备注 |
|---|---|---|---|
