#!/bin/bash
set -e

echo "==> 检查并安装编译依赖 (wayland-protocols-devel, polkit-devel, glib2-devel, mesa-libgbm-devel, mesa-libEGL-devel, cli11-devel, libunwind-devel, ninja-build)..."
sudo dnf install -y \
    wayland-protocols-devel \
    polkit-devel \
    glib2-devel \
    mesa-libgbm-devel \
    mesa-libEGL-devel \
    cli11-devel \
    libunwind-devel \
    ninja-build

echo "==> 正在配置 Quickshell 0.3.1..."
rm -rf /tmp/quickshell-build
cmake -S /tmp/quickshell-src -B /tmp/quickshell-build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DVENDOR_CPPTRACE=ON \
    -DCMAKE_CXX_SCAN_FOR_MODULES=OFF

echo "==> 正在编译 Quickshell 0.3.1..."
cmake --build /tmp/quickshell-build --parallel

echo "==> 正在安装 Quickshell 0.3.1 到 /usr/local..."
sudo cmake --install /tmp/quickshell-build

echo "==> Quickshell 0.3.1 安装完成！版本："
/usr/local/bin/quickshell --version
