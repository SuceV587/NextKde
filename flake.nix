{
  description = "KOS Desktop Shell - iPadOS-style desktop for KDE Plasma 6";

  inputs = {
    nixpkgs = {
      url = "git+https://mirrors.nju.edu.cn/git/nixpkgs.git?ref=nixos-unstable&shallow=1";
    };
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = let
        kos-desktop = pkgs.callPackage ./nix/package.nix {
          src = ./.;
        };
      in {
        inherit kos-desktop;
        inherit (kos-desktop.passthru)
          shell-data-service kos-settings kos-platform kosctl
          kwin-dock-window-animation kwin-context-menu-input kwin-effects-glass
          kwin-decoration-liquid-glass;
        kos-apps = kos-desktop.passthru.apps;
        default = kos-desktop;
      };

      # Fully declarative NixOS module — no manual steps required
      nixosModules.kos = { config, lib, pkgs, ... }:
      let
        cfg = config.services.kos;
        kos = self.packages.${system}.kos-desktop.override { buildWeather = cfg.weather.enable; };
        qs_bin = "/run/current-system/sw/bin/quickshell";
        
        # NixOS control interface
        kos-ctl = pkgs.callPackage ./nix/kos-ctl.nix {};
      in {
        options.services.kos = {
          enable = lib.mkEnableOption "KOS Desktop Shell";
          weather = {
            enable = lib.mkEnableOption "KOS Weather standalone application";
          };
          apps = {
            enable = lib.mkEnableOption "KOS standalone applications (Calendar, Todo, Music) and the shared PIM service";
          };
          # Readability defaults seeded into the Shell appearance config on
          # first run. A theme author can flip them here to test the adaptive
          # ink and hover-hint behaviour without touching a running session;
          # the in-app Settings page remains the runtime control.
          adaptiveTextColor = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Seed adaptive glass text colour (black/white by wallpaper luminance).";
          };
          hoverHints = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Seed hover function-name hints on status and Control Center controls.";
          };
        };

        config = lib.mkIf cfg.enable {
          # System-wide packages: binaries + KWin plugins + kosctl + kos-ctl
          environment.systemPackages = [
            kos
            kos.passthru.kosctl
            kos-ctl
            kos.passthru.kwin-dock-window-animation
            kos.passthru.kwin-context-menu-input
            kos.passthru.kwin-effects-glass
            kos.passthru.kwin-decoration-liquid-glass
          ] ++ lib.optionals cfg.weather.enable [
            kos.passthru.weather
          ] ++ lib.optionals cfg.apps.enable [
            kos.passthru.apps
          ];

          # KWin plugins live under lib/kwin/ in the Nix store
          environment.pathsToLink = [ "/lib/kwin" ];

          # Systemd user services — declaratively defined with Nix store paths
          systemd.user.services = {
            # Oneshot: copy shell QML to ~/.config/quickshell/kos/
            kos-shell-init = {
              description = "KOS shell config initializer";
              wantedBy = [ "default.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "kos-shell-init" ''
                  set -e
                  shell_config="$HOME/.config/quickshell/kos"
                  
                  # Fix permissions on existing files before removal
                  # (Nix store copies may be read-only)
                  if [[ -d "$shell_config" ]]; then
                    find "$shell_config" -type d -exec chmod u+w {} + 2>/dev/null || true
                    find "$shell_config" -type f -exec chmod u+w {} + 2>/dev/null || true
                    rm -rf "$shell_config"
                  fi
                  
                  # Create fresh directories
                  mkdir -p "$shell_config/shared/qml"
                  
                  # Copy shell QML (follow symlinks, ignore source permissions)
                  cp -rL --no-preserve=mode ${kos}/share/kos-desktop/shell/. "$shell_config/"
                  
                  # Copy shared QML (controls, foundation, colorize)
                  if [[ -d ${kos}/share/shared/qml ]]; then
                    cp -rL --no-preserve=mode ${kos}/share/shared/qml/. "$shell_config/shared/qml/"
                  elif [[ -d ${kos}/share/kos-desktop/shared/qml ]]; then
                    cp -rL --no-preserve=mode ${kos}/share/kos-desktop/shared/qml/. "$shell_config/shared/qml/"
                  fi
                '';
              };
            };

            # Oneshot: seed the appearance readability defaults before the
            # Shell starts. Only writes when no config exists so the running
            # session (and the in-app Settings page) stays authoritative.
            kos-appearance-init = {
              description = "KOS appearance readability defaults";
              wantedBy = [ "default.target" ];
              before = [ "kos-shell.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "kos-appearance-init" ''
                  set -e
                  state_home="''${XDG_STATE_HOME:-$HOME/.local/state}"
                  config_file="$state_home/quickshell/kos/appearance/config.json"
                  if [[ -e "$config_file" ]]; then
                    exit 0
                  fi
                  mkdir -p "$(dirname "$config_file")"
                  cat > "$config_file" <<'EOF'
${builtins.toJSON {
  version = 11;
  adaptiveTextColor = cfg.adaptiveTextColor;
  hoverHints = cfg.hoverHints;
}}
EOF
                '';
              };
            };

            # Oneshot: mirror `kosctl install`'s KWin setup. Enables the KOS
            # Glass effect and the Liquid Glass decoration in kwinrc, then
            # applies them to the running compositor when KWin is already up.
            kos-kwin-effects = {
              description = "Enable KOS KWin effects and Liquid Glass decoration";
              wantedBy = [ "default.target" ];
              after = [ "graphical-session.target" "plasma-kwin_wayland.service" ];
              partOf = [ "graphical-session.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "kos-kwin-effects" ''
                  set -e
                  kwriteconfig="${pkgs.kdePackages.kconfig}/bin/kwriteconfig6"

                  # Glass is a fork of KWin Blur and cannot run alongside it.
                  "$kwriteconfig" --file kwinrc --group Plugins \
                    --key blurEnabled false --type bool --notify false
                  for effect in kos_dock_window_animation kos_context_menu_input glass; do
                    "$kwriteconfig" --file kwinrc --group Plugins \
                      --key "$effect""Enabled" true --type bool --notify false
                  done

                  # Select the compiled Liquid Glass window decoration. KWin
                  # reads the selected plugin from the legacy
                  # `org.kde.kdecoration2` config group even though KDecoration3
                  # plugins install under an `org.kde.kdecoration3` directory;
                  # writing the directory name never selects the plugin and
                  # leaves KWin on the previous decoration. `theme` only applies
                  # to multi-theme packages such as Aurorae, so a stale value
                  # must be removed.
                  "$kwriteconfig" --file kwinrc --group org.kde.kdecoration2 \
                    --key library kos_liquid_glass --notify false
                  "$kwriteconfig" --file kwinrc --group org.kde.kdecoration2 \
                    --key theme --delete --notify false || true
                  # Clear a stale selection from the directory-named group that
                  # older KOS revisions wrote, so it cannot confuse a future
                  # config-group rename.
                  "$kwriteconfig" --file kwinrc --group org.kde.kdecoration3 \
                    --key library --delete --notify false || true
                  "$kwriteconfig" --file kwinrc --group Effect-blurplus \
                    --key BlurDecorations true --type bool --notify false

                  # Apply to the running session. Writing kwinrc only takes
                  # effect after the next KWin start, so load the already
                  # installed plugins explicitly when KWin is on the bus.
                  busctl="${pkgs.systemd}/bin/busctl"
                  if "$busctl" --user status org.kde.KWin >/dev/null 2>&1; then
                    "$busctl" --user call org.kde.KWin /Effects \
                      org.kde.kwin.Effects unloadEffect s blur >/dev/null 2>&1 || true
                    for effect in kos_dock_window_animation kos_context_menu_input glass; do
                      "$busctl" --user call org.kde.KWin /Effects \
                        org.kde.kwin.Effects loadEffect s "$effect" >/dev/null 2>&1 || true
                      "$busctl" --user call org.kde.KWin /Effects \
                        org.kde.kwin.Effects reconfigureEffect s "$effect" >/dev/null 2>&1 || true
                    done
                    "$busctl" --user call org.kde.KWin /KWin \
                      org.kde.KWin reconfigure >/dev/null 2>&1 || true
                  fi
                '';
              };
            };

            # Platform daemon
            kos-platform = {
              description = "KOS platform integration service";
              wantedBy = [ "default.target" ];
              after = [ "graphical-session.target" ];
              partOf = [ "graphical-session.target" ];
              serviceConfig = {
                Type = "simple";
                # Prepend the store tools instead of replacing PATH. The user
                # manager's PATH carries the per-user and home-manager profiles
                # (`/etc/profiles/per-user/<user>/bin`, `~/.nix-profile/bin`),
                # which is where NixOS installs applications; replacing PATH
                # made `application.launch` fail to find any user-installed app
                # ("无法找到程序").
                ExecStart = pkgs.writeShellScript "kos-platform-start" ''
                  export PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils ]}:$PATH
                  exec ${kos}/libexec/kos-platform daemon
                '';
                Environment = [
                  "KOS_PLATFORM_KWIN_SCRIPT=${kos}/share/kos/platform/kwin/window-bridge.js"
                ];
                Restart = "on-failure";
                RestartSec = 2;
              };
            };

            # Data service
            kos-data = {
              description = "KOS persistent data service";
              wantedBy = [ "default.target" ];
              after = [ "graphical-session.target" ];
              partOf = [ "graphical-session.target" ];
              serviceConfig = {
                Type = "simple";
                ExecStart = "${kos}/libexec/kos-data-service";
                Restart = "on-failure";
                RestartSec = 2;
              };
            };

            # Quickshell desktop shell
            kos-shell = {
              description = "KOS Quickshell desktop shell";
              wantedBy = [ "default.target" ];
              requires = [ "kos-platform.service" "kos-data.service" "kos-shell-init.service" "kos-appearance-init.service" ];
              after = [ "kos-platform.service" "kos-data.service" "kos-shell-init.service" "kos-appearance-init.service" ];
              partOf = [ "graphical-session.target" ];
              serviceConfig = {
                Type = "simple";
                KillMode = "process";
                # Keep the user manager's PATH so Shell-spawned launches resolve
                # user-installed applications; prepend the shell helpers the
                # QML process wrappers rely on.
                ExecStart = pkgs.writeShellScript "kos-shell-start" ''
                  export PATH=${lib.makeBinPath [ pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused ]}:$PATH
                  exec ${qs_bin} --no-duplicate -c kos
                '';
                Environment = [
                  "QS_DISABLE_FILE_WATCHER=1"
                ];
                Restart = "on-failure";
                RestartSec = 2;
              };
            };
          } // lib.optionalAttrs cfg.apps.enable {
            # Refresh the KDE application database so the standalone apps show
            # up immediately after a rebuild instead of waiting for a session
            # restart.
            kos-apps-cache = {
              description = "Refresh the KDE application database for KOS apps";
              wantedBy = [ "default.target" ];
              after = [ "kos-shell-init.service" ];
              partOf = [ "graphical-session.target" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.kdePackages.kservice}/bin/kbuildsycoca6 --noincremental";
              };
            };
          };
        };
      };

      # Export source path for other flakes
      lib.${system} = {
        src = ./.;
      };
    };
}
