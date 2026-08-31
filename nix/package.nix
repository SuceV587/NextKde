{
  lib,
  stdenv,
  pkgs,
  src,
}:

let
  shell-data-service = pkgs.callPackage ./shell-data-service.nix { inherit src; };
  kwin-window-bridge = pkgs.callPackage ./kwin-window-bridge.nix { inherit src; };
  kos-settings = pkgs.callPackage ./kos-settings.nix { inherit src; };
  kwin-dock-window-animation = pkgs.callPackage ./kwin-dock-window-animation.nix { inherit src; };
  kwin-context-menu-input = pkgs.callPackage ./kwin-context-menu-input.nix { inherit src; };
in
stdenv.mkDerivation {
  pname = "kos-desktop";
  version = "unstable";
  inherit src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/kos-desktop
    cp -r shell.qml $out/share/kos-desktop/
    cp -r desktop $out/share/kos-desktop/
    cp -r shared $out/share/kos-desktop/
    cp -r helpers/global-shortcuts $out/share/kos-desktop/

    mkdir -p $out/share/applications
    substitute packaging/desktop/kos-settings.desktop.in \
      $out/share/applications/kos-settings.desktop \
      --replace-fail '@CMAKE_INSTALL_FULL_BINDIR@' "${kos-settings}/bin"

    mkdir -p $out/lib/quickshell
    ln -s ${shell-data-service}/lib/quickshell/shell-data-service \
      $out/lib/quickshell/shell-data-service
    ln -s ${shell-data-service}/lib/quickshell/quickshell-file-clipboard-helper \
      $out/lib/quickshell/quickshell-file-clipboard-helper

    mkdir -p $out/libexec
    ln -s ${kwin-window-bridge}/libexec/quickshell-kwin-window-bridge \
      $out/libexec/quickshell-kwin-window-bridge

    runHook postInstall
  '';

  passthru = {
    inherit shell-data-service kwin-window-bridge kos-settings
            kwin-dock-window-animation kwin-context-menu-input;
  };

  meta = with lib; {
    description = "KOS Desktop Shell - iPadOS-style desktop for KDE Plasma 6";
    homepage = "https://github.com/SuceV587/NextKde";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
