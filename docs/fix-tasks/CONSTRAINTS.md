# 修复约束

所有 fix-tasks 下的工作必须遵守以下约束。

## 1. 架构红线（PROJECT_CONTEXT.md code-review gate）

- QML / Settings 代码**不得**新增执行桌面集成或系统控制命令：
  `qdbus6`、`kwriteconfig6`、`nmcli`、`wpctl`、`bluetoothctl`、`systemctl`、
  `gio`、`socat`、`sh -c`。
- 需要新系统能力时：在 `shared/contracts/platform.v1.md` 增加有界版本化
  operation，在 kos-platform 实现，QML 经 `PlatformClient.qml` 调用。
- 修复**不得**引入新违规；T10 专门收敛存量违规。
- 配置持久化统一走 `QtCore.Settings`（先例 `DeskCenterConfigService.qml`）
  或抽出的 `JsonConfigStore`，不再复制 `sh -c` 模板。

## 2. 不破坏既有 workaround 与不变量

- `AppLauncher.qml` 常驻窗口是 Qt 6.11 输出切换崩溃 workaround，禁止改回
  随 open 销毁。
- `kos-shell.service` 的 `KillMode=process`、启动顺序依赖（kwin/plasmashell
  After=）是修复过的竞态，不要动。
- `install` 必须保持非热加载语义（不重启运行中的服务、不热载 KWin effect）。
- 数据服务状态根 `$XDG_STATE_HOME/quickshell/shell-data-service/` 的
  用户历史不得删除/迁移丢数据。
- 契约变更必须版本化并同步 `shared/contracts/platform.v1.md`，
  保持 `{ok,result,error}` 响应模型；socket 权限维持 0600。
- QsMenuAnchor 依赖 `shell.qml` 的 `//@ pragma UseQApplication`，
  移除原生菜单路径前先确认无其他使用者。
- 注释里标注"不要改/有意为之"的行为（如拖拽 offset 语义、屏幕生命周期
  保活）保持原语义，除非任务明确要求。

## 3. 范围控制

- 一次只做一个任务（T<n>），不夹带无关重构；保留 worktree 中无关改动。
- 每个任务一个独立 commit，message 遵循仓库现有风格（`fix(scope): …`，
  关注 why 而非 what）。
- 不修改 git 配置、不 push、不 force-push、不动分支保护。

## 4. 验证

- 改动后必须能构建：`./tools/kosctl build`（或对应子集 preset）。
- QML 改动跑 `./tools/qmllint-changed.mjs`；文档契约改动跑
  `./tools/check-docs.py`。
- Shell 行为改动用 verify skill（`qs -p shell` / `kosctl dev`）实测：
  T1 需模拟 daemon 重启验证队列不积压、in-flight 复位；
  T2 需实际右键托盘图标确认黑角消失；
  T5/T6 前后对比 `top`/`pidstat` 空闲 CPU 与 `smaps_rollup` RSS。
- daemon 改动（T3/T7/T8/T9）需保证 daemon 重启后 shell 端无永久卡死
  （依赖 T1 的超时/复位能力）。
- 性能任务给出前后对比数据（进程数/分钟、RSS、写盘字节数）记录在
  对应 reviews/T<n>-review.md 里。

## 5. 审查（强制，每次完成后）

- **每个任务完成后必须调用子代理审查**：把 `git diff`（或文件清单）
  交给只读子代理复核正确性、是否引入新问题、是否遵守本约束文件。
- 审查报告存档 `docs/fix-tasks/reviews/T<n>-review.md`。
- 审查发现问题 → 修复 → 再次子代理审查，直到通过。
- 审查重点提示随任务下发（见各任务的"审查要点"）。

## 6. 安全

- 不提交 secret/凭据；不改 socket 0600 权限与路径校验。
- 拼接进 shell/argv 的外部输入必须校验或改 argv 形式（见 T11）。
- 下载（ArtworkColorSource）必须有大小上限、协议白名单、取消逻辑。
