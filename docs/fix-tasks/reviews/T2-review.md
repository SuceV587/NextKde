# T2 审查报告 — 托盘右键菜单黑角

## 结论：PASS（修复第一轮审查发现后通过）

## 范围

- `shell/desktop/modules/bar/SysTray.qml` — 移除 delegate 内 `QsMenuAnchor`，
  改为共享 `ContextMenu` + `QsMenuOpener` 桥接（方案 B）
- `shell/desktop/modules/common/ContextMenu.qml` — 新增 `customMargins`
  四边覆写；delegate 支持 `modelData.entry`（QsMenuEntry）实时绑定；
  高度计算改为 entry-aware
- `shell/desktop/modules/common/MenuItemRow.qml` — 新增 `iconSource`
  （同步 `Image`，icon 非 BundledIcons 登记名时渲染 DBusMenu 图标 URL）

预先存在的 `DockIcon.qml` 改动与本任务无关，未纳入审查与提交。
`//@ pragma UseQApplication` 保留（图标主题 provider 等仍需要），
QsMenuAnchor 已无其他使用者。

## 实现要点

- 每个 SysTray 一个共享 ContextMenu；打开时 `QsMenuOpener.menu` =
  `modelData.menu`（DBusMenuHandle），异步 AboutToShow+GetLayout(-1)
  全树加载后 `children` 从 emptyInstance 单例换成真模型 → 以此判定
  "已加载" 再 show，另有 400ms 兜底 Timer。
- 子菜单 entry 用惰性复用的 QsMenuOpener 枚举（setMenu 即 ref →
  发送 DBusMenu "opened"）；menu 关闭时销毁 opener → unref → "closed"。
- item 携带 `entry` 引用，delegate 对 label/icon/enabled/checkState/
  separator 做实时绑定，布局中属性更新无需重建。
- `rebuildTrayMenu` 保存 page.parents 对应的 entry 链，重建后按
  entry 指针恒等恢复子菜单导航位置。
- 清理顺序：clear() 丢 delegate 引用 → 销毁子菜单 opener →
  `opener.menu = null`（DBusMenu deleteLater），指针安全。
- margins 按 popupEdge 在弹出方向给 -4（与原 QsMenuAnchor 一致；
  margins 是 marginsRemoved 语义，负值扩大 anchor rect 形成间隔）。

## 审查轮次

### 第一轮：PASS with issues（1 项中等问题已修复，低危项处理如下）

1. **[中] pendingShow 期间 anchor delegate 销毁不清理状态**
   — `hide()` 在 `visible=false` 时无操作，`aboutToHide` 不触发，
   `_trayMenuPendingShow`/兜底 Timer/DBusMenuHandle ref 残留，
   可能在死 anchor 上映射幽灵弹窗。
   → delegate `Component.onDestruction` 改为 `hide()` +
   `closeTrayMenuState()`（后者幂等，覆盖 visible/pending 两种情形）。
2. **[低] `hasChildrenChanged` 不触发重建** — 已有 `children-display`
   后置翻转的 entry 会留下过期 chevron。
   → 子菜单 opener 工厂内追加 `Connections { target: sub.menu;
   onHasChildrenChanged → rebuildTrayMenu }`。
3. **[低] radio 项渲染为普通对勾** — 与原 `QActionGroup` 互斥仅视觉
   差异，应用端仍保证互斥，`checkState` 实时绑定正确。接受。
4. **[低] 永不加载的菜单 fallback 显示空胶囊** — 有意为之
   （宁可显示空弹窗也不吞掉点击）。接受。
5. **[低] diffUpdate 每次行变更都发 valuesChanged** — 一次布局 diff
   触发多次同步重建，O(tree) 规模下可接受。接受。
6. **[nit]** `Quickshell.Widgets` 未使用 → 已移除；
   `MenuItemRow` 的 `Image` 显式 `asynchronous: false` → 已加。

## 运行时验证（真机，2026-09-19）

方法：改动同步到 `~/.config/quickshell/kos` 后 `systemctl --user restart
kos-shell.service`，uinput 虚拟指针注入右键，Spectacle 截图验证。

- ✅ Fcitx 托盘图标右键 → liquid-glass 菜单锚定图标下方弹出，
  **四角无黑块**（圆角处正确透出壁纸）
- ✅ 图标/文本/分隔线/勾选态（"键盘-英语"✓、"拼音"未选）渲染正确
- ✅ QQ 菜单：子菜单 chevron → 翻页（在线/离开✓/隐身/离线）→
  "返回" 回到根页正常
- ✅ 菜单项点击 → `entry.triggered()` 送达应用（QQ "退出" 生效、
  Fcitx 已勾选项点击正常关闭菜单）
- ✅ 外部点击 `dismissed by global press` 正常关闭
- ✅ 托盘图标悬停高亮与菜单可见态联动正常
- ✅ 全程 journal 无 QML 错误/新增告警；桌面右键菜单等既有
  ContextMenu 调用方行为不变
- ⚠️ 验证过程中一次坐标漂移误点 "退出 QQ" 导致 QQ 退出，
  已 `gtk-launch qq` 恢复

## 未覆盖

- dockHosted 各边（本机托盘仅在顶栏）：popupEdge→customMargins 映射
  为同一机制，PopupAdjustment.Flip|Slide 兜底。
- 多屏第二 SysTray 实例（同进程内各自独立 opener，refcount 语义已核）。
