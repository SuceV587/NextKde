{
  lib,
  stdenv,
  pkgs,
  src,
  quickshell ? null,
}:

let
  shell-data-service = pkgs.callPackage ./shell-data-service.nix { inherit src; };
  kos-settings = pkgs.callPackage ./kos-settings.nix { inherit src; };
  kos-platform = pkgs.callPackage ./kos-platform.nix { inherit src; };
  kwin-dock-window-animation = pkgs.callPackage ./kwin-dock-window-animation.nix { inherit src; };
  kwin-context-menu-input = pkgs.callPackage ./kwin-context-menu-input.nix { inherit src; };
  kwin-effects-glass = pkgs.callPackage ./kwin-effects-glass.nix { inherit src; };

  qs_bin = if quickshell != null then "${quickshell}/bin/quickshell" else "/run/current-system/sw/bin/quickshell";

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

  patched-data-service = shell-data-service.passthru.patched-service;

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

    mkdir -p $out/share/kos-desktop
    cp -r shell/ $out/share/kos-desktop/
    cp -r shared/ $out/share/kos-desktop/
    # shell.qml must be at root for quickshell to find it
    cp shell/shell.qml $out/share/kos-desktop/shell.qml

    mkdir -p $out/share/applications
    substitute packaging/desktop/kos-settings.desktop.in \
      $out/share/applications/kos-settings.desktop \
      --replace-fail 'kos-settings' "${kos-settings}/bin/kos-settings"

    mkdir -p $out/lib/quickshell
    ln -s ${shell-data-service}/lib/quickshell/shell-data-service \
      $out/lib/quickshell/shell-data-service

    mkdir -p $out/libexec
    ln -s ${kos-platform}/libexec/kos-platform \
      $out/libexec/kos-platform

    mkdir -p $out/share/kos/platform/kwin
    ln -s ${kos-platform}/share/kos/platform/kwin/window-bridge.js \
      $out/share/kos/platform/kwin/window-bridge.js

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
    inherit shell-data-service kos-settings kos-platform
            kwin-dock-window-animation kwin-context-menu-input kwin-effects-glass;
    inherit patched-platform-service patched-shell-service;
  };

  meta = with lib; {
    description = "KOS Desktop Shell - iPadOS-style desktop for KDE Plasma 6";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
