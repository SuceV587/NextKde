# KWin window bridge

KWin does not expose the `zwlr-foreign-toplevel-management-v1` protocol used
by Quickshell's standard `ToplevelManager`. This bridge supplies the KDE
fallback for `desktop/modules/dock/WindowService.qml` without changing its public API.

It consists of:

- `kwin/contents/code/main.js`: a KWin Script that watches normal taskbar
  windows and applies requested activate, minimize, and close operations.
- `src/main.cpp`: a local session D-Bus service used to relay KWin snapshots
  to Quickshell and queue commands in the reverse direction.

Build once after cloning the configuration:

```sh
cmake -S helpers/kwin-window-bridge -B helpers/kwin-window-bridge/build
cmake --build helpers/kwin-window-bridge/build
```

When running under Plasma Wayland, `WindowService` starts the bridge and
loads the script into the current KWin session automatically. On compositors
that expose foreign toplevel management (such as Hyprland), that provider
remains preferred and the KWin fallback stays unused.
