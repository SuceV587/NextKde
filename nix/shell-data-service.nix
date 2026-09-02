{
  lib,
  stdenv,
  buildGoModule,
  cmake,
  kdePackages,
  runCommand,
  src,
}:

let
  file-clipboard-helper = stdenv.mkDerivation {
    pname = "quickshell-file-clipboard-helper";
    version = "unstable";
    src = "${src}/helpers/file-clipboard-helper";
    nativeBuildInputs = [ cmake ];
    buildInputs = [ kdePackages.qtbase ];
    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
    dontWrapQtApps = true;
  };

  go-service = buildGoModule {
    pname = "shell-data-service";
    version = "unstable";
    src = "${src}/services/shell-data-service";
    vendorHash = "sha256-Gt+D69n3xUiZDkV6yClL3mJFIAELl9JWPF49JYTdLH0=";
    subPackages = [ "." ];
    ldflags = [ "-s" "-w" ];
    preBuild = ''
      export GOPROXY=https://goproxy.cn,direct
    '';
  };

  patched-service = runCommand "shell-data-service.service" { } ''
    mkdir -p $out/lib/systemd/user
    sed 's|%h/.local/lib/quickshell/|${go-service}/bin/|g' \
      ${src}/services/shell-data-service/systemd/shell-data-service.service \
      > $out/lib/systemd/user/shell-data-service.service
  '';
in
stdenv.mkDerivation {
  pname = "kos-shell-data-service";
  version = "unstable";
  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/quickshell $out/lib/systemd/user
    ln -s ${go-service}/bin/shell-data-service $out/lib/quickshell/shell-data-service
    ln -s ${file-clipboard-helper}/lib/quickshell/quickshell-file-clipboard-helper \
      $out/lib/quickshell/quickshell-file-clipboard-helper
    cp ${patched-service}/lib/systemd/user/shell-data-service.service \
      $out/lib/systemd/user/

    runHook postInstall
  '';

  passthru = {
    inherit go-service file-clipboard-helper patched-service;
  };

  meta = with lib; {
    description = "KOS shared data service";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
