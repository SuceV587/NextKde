# KOS Desktop Shell - NixOS 打包指南

## 项目概览

KOS Desktop Shell 是一个基于 Quickshell 的 iPadOS 风格桌面环境，运行于 KDE Plasma 6 (Wayland) 之上。项目由多个独立组件构成，需要分别打包后整合。

## 组件清单

| 组件 | 语言 | 构建系统 | 说明 |
|------|------|----------|------|
| `shell-data-service` | Go | go build | 系统指标采集、活动账本、桌面文件监听 |
| `file-clipboard-helper` | C++ | CMake | 跨格式文件剪贴板辅助器（仅依赖 Qt6 Gui） |
| `kwin-window-bridge` | C++ | CMake | KWin 窗口枚举 D-Bus 桥 |
| `kos-settings` | C++/QML | CMake | 独立设置应用 |
| `kwin-effects-glass` | C++/GLSL | CMake | KWin 模糊/折射特效（已有 flake.nix） |
| `kwin-dock-window-animation` | C++ | CMake | iPadOS 风格窗口开关动画 |
| `kwin-context-menu-input` | C++ | CMake | 右键菜单外部点击关闭特效 |
| QML Shell 配置 | QML/JS | 无需构建 | Quickshell 直接解释运行 |

## 文件结构

```
Nextkde/
├── flake.nix
├── nix/
│   ├── shell-data-service.nix
│   ├── kwin-window-bridge.nix
│   ├── kos-settings.nix
│   ├── kwin-dock-window-animation.nix
│   ├── kwin-context-menu-input.nix
│   └── default.nix
├── integrations/kwin-effects-glass/
│   ├── flake.nix          (已有)
│   └── nix/package.nix    (已有)
└── ...
```

## 构建步骤

### 第 1 步：创建顶层 flake.nix

```nix
{
  description = "KOS Desktop Shell - iPadOS-style desktop for KDE Plasma 6";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system: let
      pkgs = import nixpkgs { inherit system; };
    in {
      packages = {
        shell-data-service         = pkgs.callPackage ./nix/shell-data-service.nix {};
        kwin-window-bridge         = pkgs.callPackage ./nix/kwin-window-bridge.nix {};
        kos-settings               = pkgs.callPackage ./nix/kos-settings.nix {};
        kwin-dock-window-animation = pkgs.kdePackages.callPackage ./nix/kwin-dock-window-animation.nix {};
        kwin-context-menu-input    = pkgs.kdePackages.callPackage ./nix/kwin-context-menu-input.nix {};
        kwin-effects-glass         = pkgs.kdePackages.callPackage ./integrations/kwin-effects-glass/nix/package.nix {};
        kos-desktop = pkgs.callPackage ./nix/default.nix {
          inherit (self.packages.${system})
            shell-data-service kwin-window-bridge kos-settings
            kwin-dock-window-animation kwin-context-menu-input
            kwin-effects-glass;
        };
        default = self.packages.${system}.kos-desktop;
      };
    });
}
```

### 第 2 步：创建 nix/shell-data-service.nix

包含 Go 数据服务、Qt 剪贴板辅助器、systemd user unit 三个产物。

```nix
{ lib, stdenv, buildGoModule, cmake, qtbase, runCommand }:

let
  file-clipboard-helper = stdenv.mkDerivation {
    pname = "quickshell-file-clipboard-helper";
    version = "unstable";
    src = ../helpers/file-clipboard-helper;
    nativeBuildInputs = [ cmake ];
    buildInputs = [ qtbase ];
    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  };

  go-service = buildGoModule {
    pname = "shell-data-service";
    version = "unstable";
    src = ../services/shell-data-service;
    vendorHash = lib.fakeSha256;  # 首次构建报错后替换为正确 hash
    subPackages = [ "." ];
    ldflags = [ "-s" "-w" ];
  };

  patched-service = runCommand "shell-data-service.service" {} ''
    mkdir -p $out/lib/systemd/user
    sed 's|%h/.local/lib/quickshell/|${go-service}/bin/|g' \
      ${../services/shell-data-service/systemd/shell-data-service.service} \
      > $out/lib/systemd/user/shell-data-service.service
  '';
in
stdenv.mkDerivation {
  pname = "kos-shell-data-service";
  version = "unstable";
  dontUnpack = true;

  installPhase = ''
    mkdir -p $out/lib/quickshell $out/lib/systemd/user
    ln -s ${go-service}/bin/shell-data-service $out/lib/quickshell/shell-data-service
    ln -s ${file-clipboard-helper}/bin/quickshell-file-clipboard-helper \
      $out/lib/quickshell/quickshell-file-clipboard-helper
    cp ${patched-service}/lib/systemd/user/shell-data-service.service \
      $out/lib/systemd/user/
  '';

  passthru = { inherit go-service file-clipboard-helper patched-service; };

  meta = with lib; {
    description = "KOS shared data service";
    license = licenses.gpl3;
  };
}
```

### 第 3 步：创建 nix/kwin-window-bridge.nix

```nix
{ lib, stdenv, cmake, extra-cmake-modules, qtbase, kiconthemes }:

stdenv.mkDerivation {
  pname = "quickshell-kwin-window-bridge";
  version = "unstable";
  src = ../helpers/kwin-window-bridge;
  nativeBuildInputs = [ cmake extra-cmake-modules ];
  buildInputs = [ qtbase kiconthemes ];
  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  meta = with lib; {
    description = "C++ D-Bus bridge for KWin window enumeration";
    license = licenses.gpl3;
  };
}
```

### 第 4 步：创建 nix/kos-settings.nix

```nix
{ lib, stdenv, cmake, qtbase, qtdeclarative }:

stdenv.mkDerivation {
  pname = "kos-settings";
  version = "unstable";
  src = ../apps/settings;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ qtbase qtdeclarative ];
  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  meta = with lib; {
    description = "KOS Desktop Shell settings application";
    license = licenses.gpl3;
  };
}
```

### 第 5 步：创建 nix/kwin-dock-window-animation.nix

```nix
{ lib, stdenv, cmake, extra-cmake-modules, kwin, kconfig, qtbase }:

stdenv.mkDerivation {
  pname = "kwin-dock-window-animation";
  version = "unstable";
  src = ../integrations/kwin-dock-window-animation;
  nativeBuildInputs = [ cmake extra-cmake-modules ];
  buildInputs = [ kwin kconfig qtbase ];
  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  meta = with lib; {
    description = "iPadOS-style scale/genie window animation for KWin";
    license = licenses.gpl3;
  };
}
```

### 第 6 步：创建 nix/kwin-context-menu-input.nix

```nix
{ lib, stdenv, cmake, extra-cmake-modules, kwin, qtbase }:

stdenv.mkDerivation {
  pname = "kwin-context-menu-input";
  version = "unstable";
  src = ../integrations/kwin-context-menu-input;
  nativeBuildInputs = [ cmake extra-cmake-modules ];
  buildInputs = [ kwin qtbase ];
  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  meta = with lib; {
    description = "KWin effect for context menu outside-click dismiss";
    license = licenses.gpl3;
  };
}
```

### 第 7 步：创建 nix/default.nix（整合包）

```nix
{ lib, stdenv, shell-data-service, kwin-window-bridge, kos-settings
, kwin-dock-window-animation, kwin-context-menu-input, kwin-effects-glass
}:

stdenv.mkDerivation {
  pname = "kos-desktop";
  version = "unstable";
  src = ./..;
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/share/kos-desktop
    cp -r shell.qml $out/share/kos-desktop/
    cp -r desktop $out/share/kos-desktop/
    cp -r shared $out/share/kos-desktop/
    cp -r helpers/global-shortcuts $out/share/kos-desktop/

    mkdir -p $out/share/applications
    substitute ${../packaging/desktop/kos-settings.desktop.in} \
      $out/share/applications/kos-settings.desktop \
      --replace '@CMAKE_INSTALL_FULL_BINDIR@' "${kos-settings}/bin"

    mkdir -p $out/lib/quickshell
    ln -s ${shell-data-service}/lib/quickshell/shell-data-service \
      $out/lib/quickshell/shell-data-service
    ln -s ${shell-data-service}/lib/quickshell/quickshell-file-clipboard-helper \
      $out/lib/quickshell/quickshell-file-clipboard-helper

    mkdir -p $out/libexec
    ln -s ${kwin-window-bridge}/bin/quickshell-kwin-window-bridge \
      $out/libexec/quickshell-kwin-window-bridge
  '';

  passthru = {
    inherit shell-data-service kwin-window-bridge kos-settings
            kwin-dock-window-animation kwin-context-menu-input
            kwin-effects-glass;
  };

  meta = with lib; {
    description = "KOS Desktop Shell - iPadOS-style desktop for KDE Plasma 6";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
```

## 构建与验证

```bash
# 构建所有组件
nix build .#kos-desktop

# 单独构建某个组件
nix build .#shell-data-service
nix build .#kwin-window-bridge
nix build .#kos-settings
nix build .#kwin-dock-window-animation
nix build .#kwin-context-menu-input
nix build .#kwin-effects-glass

# 运行 Shell（需要 quickshell 已安装）
quickshell --path ./result/share/kos-desktop
```

## 注意事项

1. **vendorHash**：使用 `lib.fakeSha256` 占位，首次构建失败后会显示正确的 hash，替换即可。
2. **systemd unit**：原始 service 文件硬编码 `%h/.local/lib/quickshell/`，已通过 `sed` 替换为 Nix store 路径。
3. **KWin 特效**：安装后需在「系统设置 → 桌面特效」中手动启用。
4. **全局快捷键**：`helpers/global-shortcuts/install.py` 是运行时脚本，不适合打包，建议用户安装后手动运行。
5. **通知接管**：需从 Plasma 托盘移除通知组件并重启 `plasmashell`。
6. **Shader 文件**：`desktop/shaders/` 下已有预编译的 `.qsb` 文件，无需在 Nix 构建中处理。
7. **运行时依赖**：Quickshell、NetworkManager (nmcli)、systemd user session、可选 cliphist。
