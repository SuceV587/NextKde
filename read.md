# 目录说明

- `desktop/`：当前 Quickshell 桌面环境；所有 Bar、Dock、桌面图标和覆盖层都在这里。
- `apps/`：独立 Qt Quick 桌面应用；它们不得 import `desktop/` 或 Quickshell 专属模块。
- `shared/`：极少量纯 Qt Quick 的跨进程 UI、资源和数据协议。
- `services/`：常驻后台服务，例如 Go 的 shell-data-service。
- `helpers/`：按需启动的 C++ / Qt 原生帮助程序。
- `integrations/`：KWin 等外部桌面集成。
- `tools/`：安装、构建与诊断脚本。

完整边界见 [docs/ProjectArchitecture.md](docs/ProjectArchitecture.md)。桌面功能改动前另请阅读 [docs/DockArchitecture.md](docs/DockArchitecture.md)。
