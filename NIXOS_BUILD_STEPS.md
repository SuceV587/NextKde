# KOS Desktop Shell - NixOS 构建指南

## 前提条件

- NixOS 系统已安装
- 已克隆 Nextkde 仓库到 `/home/xiaoyintx/Nextkde`
- 已克隆 nix-configuration-xiaoyintx 仓库到 `/home/xiaoyintx/nix-configuration-xiaoyintx`
- 已启用 flakes：`~/.config/nix/nix.conf` 中包含 `experimental-features = nix-command flakes`

## 文件结构

```
nix-configuration-xiaoyintx/
├── flake.nix
├── package/
│   ├── default.nix
│   └── kos-desktop/
│       ├── default.nix                    # 整合包
│       ├── shell-data-service.nix         # Go 数据服务 + 剪贴板辅助器
│       ├── kwin-window-bridge.nix         # C++ KWin 窗口桥
│       ├── kos-settings.nix              # 设置应用
│       ├── kwin-dock-window-animation.nix # KWin Dock 窗口动画特效
│       └── kwin-context-menu-input.nix    # KWin 右键菜单输入特效
```

## 构建步骤

### 第 1 步：构建所有组件

```bash
cd ~/nix-configuration-xiaoyintx

# 构建完整包（包含所有组件）
nix build --impure .#packages.x86_64-linux.kos-desktop
```

单独构建某个组件：

```bash
nix build --impure .#packages.x86_64-linux.kos-shell-data-service
nix build --impure .#packages.x86_64-linux.kos-kwin-window-bridge
nix build --impure .#packages.x86_64-linux.kos-settings
nix build --impure .#packages.x86_64-linux.kos-kwin-dock-window-animation
nix build --impure .#packages.x86_64-linux.kos-kwin-context-menu-input
```

### 第 2 步：加入 NixOS 系统配置

在 `hosts/omen-16/config.nix` 的 `environment.systemPackages` 中添加：

```nix
environment.systemPackages = with pkgs; [
    # ... 其他包
    localpkg.kos-desktop
];
```

### 第 3 步：重新构建系统

```bash
sudo nixos-rebuild switch --flake .#omen-16 --impure
```

### 第 4 步：运行 KOS Desktop Shell

```bash
quickshell --path /run/current-system/share/kos-desktop
```

## 构建过程中解决的问题

| 问题 | 解决方案 |
|------|---------|
| `callPackage` 不能作为函数参数被自动注入 | 改用 `pkgs` 参数，通过 `pkgs.callPackage` 调用子包 |
| `src` 与 nixpkgs 中已重命名的包冲突 | 改名 `kosSrc` |
| `lib.fakeSha256` 格式不对 | 改用 `lib.fakeHash` |
| `extra-cmake-modules` 已移除 Qt5 版本 | 用 `kdePackages.extra-cmake-modules` |
| CMake 缺少 `install()` target | 自定义 `installPhase` |
| Qt wrapping 错误 | 设置 `dontWrapQtApps = true` |
| Go 模块下载超时 | 添加 `GOPROXY=https://goproxy.cn,direct` |
| symlink 路径错误 | 修正为实际安装路径（`lib/quickshell/`、`libexec/`） |
| 纯求值模式不允许绝对路径 | 使用 `--impure` 标志 |

## 组件说明

| 包名 | 说明 |
|------|------|
| `kos-desktop` | 完整包，包含所有组件和 QML 文件 |
| `kos-shell-data-service` | Go 数据服务 + Qt 剪贴板辅助器 + systemd unit |
| `kos-kwin-window-bridge` | C++ KWin 窗口桥 |
| `kos-settings` | 设置应用 |
| `kos-kwin-dock-window-animation` | iPadOS 风格窗口动画 |
| `kos-kwin-context-menu-input` | 右键菜单外部点击关闭特效 |

## 注意事项

1. **`--impure` 标志**：因为 `kosSrc` 指向 flake 外的本地路径，构建时必须加 `--impure`
2. **KWin 特效**：安装后需在「系统设置 → 桌面特效」中手动启用
3. **全局快捷键**：需手动运行 `python3 /run/current-system/share/kos-desktop/helpers/global-shortcuts/install.py`
4. **通知接管**：需从 Plasma 托盘移除通知组件并重启 `plasmashell`
5. **运行时依赖**：需要安装 `quickshell` 包

## 卸载

```bash
# 从 config.nix 中移除 localpkg.kos-desktop
# 然后重新构建系统
sudo nixos-rebuild switch --flake .#omen-16 --impure

# 清理未使用的包
nix-collect-garbage
```
