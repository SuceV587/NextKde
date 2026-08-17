#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname -- "$script_dir")
build_root=${QUICKSHELL_BUILD_DIR:-"$project_dir/.build/shell-data-service"}
install_dir=${QUICKSHELL_SERVICE_DIR:-"$HOME/.local/lib/quickshell"}
unit_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/systemd/user

for command_name in go cmake c++ install; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing build dependency: $command_name" >&2
        exit 1
    fi
done

mkdir -p "$build_root/go" "$build_root/clipboard" "$install_dir" "$unit_dir"

(
    cd "$script_dir/shell-data-service"
    GOCACHE=${GOCACHE:-"$build_root/go-cache"} \
        go build -trimpath -o "$build_root/go/shell-data-service" .
)

cmake -S "$script_dir/file-clipboard-helper" \
    -B "$build_root/clipboard" -DCMAKE_BUILD_TYPE=Release
cmake --build "$build_root/clipboard" --parallel

install -m 0755 "$build_root/go/shell-data-service" \
    "$install_dir/shell-data-service"
install -m 0755 "$build_root/clipboard/quickshell-file-clipboard-helper" \
    "$install_dir/quickshell-file-clipboard-helper"
install -m 0644 "$script_dir/shell-data-service/systemd/shell-data-service.service" \
    "$unit_dir/shell-data-service.service"

if [ "$install_dir" != "$HOME/.local/lib/quickshell" ]; then
    echo "Installed binaries, but the bundled user unit expects" >&2
    echo "  $HOME/.local/lib/quickshell" >&2
    echo "Set ExecStart manually before enabling the service." >&2
    exit 0
fi

systemctl --user daemon-reload
systemctl --user enable --now shell-data-service.service
systemctl --user restart shell-data-service.service

echo "Installed and restarted shell-data-service."
