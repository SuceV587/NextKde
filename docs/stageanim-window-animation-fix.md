# stageanim 窗口收放动画修复（v90）

**症状**：台前调度窗口的收起/展开动画时有时无——典型表现为
「KWin 重载特效后第一次收放有动画，之后的收放全部瞬移」；有时还伴随
动画抽搐、不丝滑。

## 根因（两层，各自独立）

### ① KWin 对同值 `setMinimized` 短路 → 无 minimizedChanged

`Window::setMinimized()`（KWin 6.7 `src/window.cpp`）在
`m_minimized == effectiveSet` 时直接 return，不发 `minimizedChanged`；
而 stageanim 的收/放动画**只**寄生在该信号上。编排侧的快照滞后
（50–200ms）、重复批次、undo 竞态会写出同值 → 静默 no-op → 窗口瞬现
/瞬消、没有动画。

**已修（shell 侧）**：
- `kwin/window-bridge.js`：新增 `restoreWithAnimation()`——展开方向
  状态感知翻转注入（`forceAnim` 命令限定；同 tick `true→false` 产生
  完整"从卡片展开"动画；动画中两次 toggle 净零无干扰）。
- `shell/desktop/modules/dock/WindowService.qml`：`activateGroup` 增加
  `forceAnim` 参数；`engageSwap` 恒带 `forceAnim: true`。
- `shell/desktop/modules/stage/StageSidebarWindow.qml`：
  `_activateGroupGuarded` 传 `forceAnim=true`；`_deskUndoWatchTimer`
  增加"落地核对"（迟到的最小化从未落地时跳过还原，避免给无辜窗口抢
  焦点 + 播错误的展开动画）。

### ② 残留的已完成时间线被复用 → 新动画一帧即完成（特效层）

`StageAnimEffect::slotWindowMinimized/Unminimized` 旧实现：

```cpp
if (animation.timeLine.running()) {
    animation.timeLine.toggleDirection();   // 续播
} else {
    animation.timeLine.setDirection(...);   // 在【旧】时间线上重设
    animation.timeLine.setDuration(m_duration);
}
```

KWin `TimeLine` 的 `done` **一旦置位没有复位路径**：`setDirection` 仅在
`sourceRedirectMode == Relaxed` 时清 done（默认 **Strict**）；
`setDuration` 只在命中 `elapsed == duration` 时置位、从不清回 false。
`m_animations[w]` 条目在"动画完成但未及清理"的窗口期被下一次收放复用
时，`running()` 返回 false（elapsed == duration）→ 走 else 分支 →
`setDirection/setDuration` 都无法清 done → 时间线保持 done=true →
`postPaintScreen` 立即 erase → **新动画一帧都不播**。
实机复现：同一 KWin 会话内 `unloadEffect/loadEffect` 之后第一次收放
正常、之后全部消失（`activeEffects` 查询同步确认 stageanim13 不再
active）。

**已修（特效侧，`kwin/kwin-effects-stageanim/src/stageanim.cpp`）**：
- 引入"时间线健康判定"：只有 `running() ∧ ¬done ∧ value∈[0,1]` 才走
  `toggleDirection()` 续播；否则**整条替换为全新 `TimeLine(m_duration)`**
  （不在地雷时间线上 setDirection/setDuration）。
- 两条 slot 都加了诊断日志（`slot-min`/`slot-unmin` 打印 healthy/
  elapsed/dur/value/done；`postPaintScreen` 打印 `anim done-erase`）。
  正常路径行为不变（新条目/在途动画的走向与旧实现等价）。

### ③ 抽搐、不丝滑：magiclamp 与 stageanim 同时抢窗口动画

`kwinrc [Plugins] magiclampEnabled=true`（"魔法灯"最小化动画）开着时，
同一个 minimize 事件会同时驱动 magiclamp 与 stageanim 两套动画，窗口
被两套 transform 拉扯 → 抽搐。**两者语义互斥**（台前调度收进卡片 vs
魔法灯吸到任务栏），使用 stageanim 时应保持 magiclamp 关闭。

## 安装（需要 sudo）

编译产物：`NextKde/.build/stageanim-diag/src/stageanim13.so`
（或直接 `./tools/kosctl install` 全量构建部署）

```bash
# 备份旧版（已有 ~/stageanim13.so.bak-20261009）
sudo cp /usr/lib64/qt6/plugins/kwin/effects/plugins/stageanim13.so \
        ~/stageanim13.so.rollback

# 安装新版
sudo cp /home/purn/pr2/NextKde/.build/stageanim-diag/src/stageanim13.so \
        /usr/lib64/qt6/plugins/kwin/effects/plugins/stageanim13.so
```

### ⚠️ KWin/Qt 插件缓存坑（2026-10-09 实测记录）

**同一路径替换 .so 后 unload/load，KWin 可能仍运行旧映射**——表现为
load 返回 true 且 isEffectLoaded=true，但特效不播放动画、新代码的日志
不出现（多次实测：同路径替换后重载，2 次里 1 次拿到旧代码；换新文件
名则 100% 加载新代码）。metadata.json 的 `Id` 字段不能改变这一点
（实测 pluginId 仍随文件名派生）。

**当前已部署状态（本机）**：
- `/usr/.../stageanim13.so` = 修复版（标准名，kwinrc/shell/kosctl
  的 "stageanim13" id 对应它；**下次 KWin 启动即会话重启后加载**）
- `/usr/.../stageanim13_kos.so` = 同一修复版（**当前会话运行的实例**
  是从这个文件加载的——唯一能绕过缓存的方式）
- 旧版备份：`~/stageanim13.so.bak-20261009`

**下次会话（注销/重登）后**可删除 `stageanim13_kos.so`（只剩标准名，
最干净）；`kosctl install` 之后也建议检查该文件是否还在。

**本会话注意**：不要切换台前调度总开关（控制中心/Meta+Y）——shell
的 effectId（"stageanim13"）与当前运行实例（pluginId
"stageanim13_kos"）错位，切换会留下混乱状态；注销重登即完全归位。

### 生效方式（标准流程，供其他机器参考）

**方式 A：热重载（立即生效，KWin 官方特效开发流程）**

```bash
# 先卸载（确认旧 .so 完全退出映射）→ 再替换文件 → 最后加载
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect stageanim13
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded stageanim13   # 期望 false
sudo cp <新 .so> /usr/lib64/qt6/plugins/kwin/effects/plugins/stageanim13.so
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect stageanim13
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded stageanim13   # 期望 true
# ⚠️ 若重载后无新代码日志（诊断日志见下），说明命中缓存——
#    改用新文件名（loadEffect 用新文件名）或等会话重启
```

⚠️ 风险提示：本项目曾记录"替换运行中的特效 .so 后热加载导致 KWin 崩溃"
（`tools/kosctl` 的 `reload_kwin_effects` 注释）。上面序列刻意采用
**先卸载再替换**（替换时文件不在任何映射中），是对该风险的规避；但仍
建议在无未保存工作时执行。崩溃后重新登录即可恢复（用的是备份回滚）。

**方式 B：只安装，下次登录生效（最稳，推荐）**

替换文件后不做热重载，退出登录/重启 KWin 后自动加载新版。

### 安装后验证

```bash
# 触发一次点卡展开，动画进行中（约 0.2-0.4s 内）查询：
qs -c kos ipc call stage-sidebar debugEngageIndex 0
qdbus6 org.kde.KWin /Effects org.freedesktop.DBus.Properties.Get \
        org.kde.kwin.Effects activeEffects    # 期望含 stageanim（13/_kos）
# 连续多次触发仍应每次都有动画（旧版第二次起消失）
# journal 里有新诊断日志（每次收放两条 + 结束清理）：
journalctl --user -f | grep -E "slot-min|slot-unmin|done-erase"
# 正常样例：
#   slot-min "ZCode" healthy false elapsed 0 dur 1000 value 0 done false
#   anim done-erase "ZCode" elapsed 215 dur 215      ← elapsed==dur 完整播完
```

## 当前会话的临时缓解（未安装新版前）

任何时刻手动重载一次特效，可让"下一次收放"恢复动画：

```bash
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.unloadEffect stageanim13
qdbus6 org.kde.KWin /Effects org.kde.kwin.Effects.loadEffect stageanim13
```

## 相关配置

- 全屏动画速率（`kwinrc [KDE] AnimationDurationFactor`）：设为
  "即时"（=0）时**所有**动画时长 ×0，stageanim 也不播——这是 KDE 全局
  语义，不属于本 bug。台前调度动画速度用设置页「动效速度」调节。
- magiclamp（`kwinrc [Plugins] magiclampEnabled`）需保持 false（见根因③）。
