{
  lib,
  stdenv,
  pkgs,
  src,
  quickshell,
}:

let
  shell-data-service = pkgs.callPackage ./shell-data-service.nix { inherit src; };
  kwin-window-bridge = pkgs.callPackage ./kwin-window-bridge.nix { inherit src; };
  kos-settings = pkgs.callPackage ./kos-settings.nix { inherit src; };
  kos-platform = pkgs.callPackage ./kos-platform.nix { inherit src; };
  kwin-dock-window-animation = pkgs.callPackage ./kwin-dock-window-animation.nix { inherit src; };
  kwin-context-menu-input = pkgs.callPackage ./kwin-context-menu-input.nix { inherit src; };
  kwin-effects-glass = pkgs.callPackage ./kwin-effects-glass.nix { inherit src; };

  # Patch systemd service files with correct Nix store paths
  qs_bin = "${quickshell}/bin/quickshell";

  patched-platform-service = stdenv.mkDerivation {
    name = "kos-platform.service";
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/systemd/user
      sed 's|%h/.local/libexec/kos-platform|${kos-platform}/libexec/kos-platform|g' \
        ${src}/packaging/systemd/kos-platform.service \
        > $out/lib/systemd/user/kos-platform.service
      runHook postInstall
    '';
  };

  patched-data-service = stdenv.mkDerivation {
    name = "kos-data.service";
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/systemd/user
      sed 's|%h/.local/libexec/kos-data-service|${shell-data-service}/lib/quickshell/shell-data-service|g' \
        ${src}/packaging/systemd/kos-data.service \
        > $out/lib/systemd/user/kos-data.service
      runHook postInstall
    '';
  };

  patched-shell-service = stdenv.mkDerivation {
    name = "kos-shell.service";
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/systemd/user
      sed 's|@QS_EXEC@|${qs_bin}|g' \
        ${src}/packaging/systemd/kos-shell.service.in \
        > $out/lib/systemd/user/kos-shell.service
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = "kos-desktop";
  version = "unstable";
  inherit src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # Shell QML files
    mkdir -p $out/share/kos-desktop
    cp -r shell.qml $out/share/kos-desktop/
    cp -r desktop $out/share/kos-desktop/
    cp -r shared $out/share/kos-desktop/
    cp -r helpers/global-shortcuts $out/share/kos-desktop/

    # Desktop file
    mkdir -p $out/share/applications
    substitute packaging/desktop/kos-settings.desktop.in \
      $out/share/applications/kos-settings.desktop \
      --replace-fail '@CMAKE_INSTALL_FULL_BINDIR@' "${kos-settings}/bin"

    # Quickshell helpers
    mkdir -p $out/lib/quickshell
    ln -s ${shell-data-service}/lib/quickshell/shell-data-service \
      $out/lib/quickshell/shell-data-service
    ln -s ${shell-data-service}/lib/quickshell/quickshell-file-clipboard-helper \
      $out/lib/quickshell/quickshell-file-clipboard-helper

    # KWin window bridge
    mkdir -p $out/libexec
    ln -s ${kwin-window-bridge}/libexec/quickshell-kwin-window-bridge \
      $out/libexec/quickshell-kwin-window-bridge

    # KOS platform daemon
    ln -s ${kos-platform}/libexec/kos-platform \
      $out/libexec/kos-platform

    # KWin window-bridge.js
    mkdir -p $out/share/kos/platform/kwin
    ln -s ${kos-platform}/share/kos/platform/kwin/window-bridge.js \
      $out/share/kos/platform/kwin/window-bridge.js

    # KWin effect plugins
    mkdir -p $out/lib/kwin
    ln -s ${kwin-dock-window-animation}/lib/kwin/kwin4_effect_dock_window_animation.so \
      $out/lib/kwin/kwin4_effect_dock_window_animation.so 2>/dev/null || true
    ln -s ${kwin-dock-window-animation}/share/kwin/effects/kos_dock_window_animation/metadata.json \
      $out/share/kos-desktop/kos_dock_window_animation metadata.json 2>/dev/null || \
      cp -r ${kwin-dock-window-animation}/share/kwin/effects/kos_dock_window_animation \
        $out/share/kos-desktop/ 2>/dev/null || true
    ln -s ${kwin-context-menu-input}/lib/kwin/kwin4_effect_context_menu_input.so \
      $out/lib/kwin/kwin4_effect_context_menu_input.so 2>/dev/null || true
    cp -r ${kwin-context-menu-input}/share/kwin/effects/kos_context_menu_input \
      $out/share/kos-desktop/ 2>/dev/null || true
    cp -r ${kwin-effects-glass}/share/kwin/effects/glass \
      $out/share/kos-desktop/ 2>/dev/null || true

    # Systemd user services (patched with Nix store paths)
    mkdir -p $out/lib/systemd/user
    cp ${patched-platform-service}/lib/systemd/user/kos-platform.service \
      $out/lib/systemd/user/
    cp ${patched-data-service}/lib/systemd/user/kos-data.service \
      $out/lib/systemd/user/
    cp ${patched-shell-service}/lib/systemd/user/kos-shell.service \
      $out/lib/systemd/user/

    runHook postInstall
  '';

  passthru = {
    inherit shell-data-service kwin-window-bridge kos-settings kos-platform
            kwin-dock-window-animation kwin-context-menu-input kwin-effects-glass;
    inherit patched-platform-service patched-data-service patched-shell-service;
  };

  meta = with lib; {
    description = "KOS Desktop Shell - iPadOS-style desktop for KDE Plasma 6";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
