# 修复任务（Fix Tasks）

本目录管理 2026-09-19 全项目审查发现问题的修复工作。

## 文件

- `ROADMAP.md` — 修复任务路线图（任务清单、优先级、状态）
- `CONSTRAINTS.md` — 所有修复必须遵守的约束
- `ACCEPTANCE.md` — 每个任务的验收标准与通用验收流程
- `reviews/` — 每次修复完成后的子代理审查报告（`T<n>-review.md`）

## 工作流程（强制）

1. 从 ROADMAP 取任务，先读 CONSTRAINTS.md。
2. 实现修复（只改该任务范围，不夹带无关改动）。
3. 构建 + 相关验证（见 CONSTRAINTS.md §验证）。
4. **完成后必须调用子代理审查**：把改动 diff 交给只读子代理复核，
   审查报告存档到 `reviews/T<n>-review.md`。
5. 审查通过 → 更新 ROADMAP 状态并提交；审查提出问题 → 修复后重新审查。
6. 验收人对照 ACCEPTANCE.md 勾选确认。

## 审查发现的来源

2026-09-19 由 4 个并行子代理完成的审查：

- 托盘菜单黑角根因（Quickshell `PlatformMenuEntry` createWinId 早于 Breeze polish，KDE bug 385311 同款）
- Shell QML 性能（IPC 队列无界、无界 map、不可见渲染）
- C++/Go 后端（子进程风暴、无超时、写放大）
- 通用代码质量（红线违规、bug）
