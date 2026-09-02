{
  lib,
  stdenv,
  buildGoModule,
  runCommand,
  src,
}:

let
  go-service = buildGoModule {
    pname = "shell-data-service";
    version = "unstable";
    src = "${src}/services/data-service";
    vendorHash = "sha256-Gt+D69n3xUiZDkV6yClL3mJFIAELl9JWPF49JYTdLH0=";
    subPackages = [ "." ];
    ldflags = [ "-s" "-w" ];
    preBuild = ''
      export GOPROXY=https://goproxy.cn,direct
    '';
    postInstall = ''
      # Go names the binary after the module path; rename to expected name
      if [ -f "$out/bin/data-service" ]; then
        mv "$out/bin/data-service" "$out/bin/shell-data-service"
      fi
    '';
  };

  patched-service = runCommand "kos-data.service" { } ''
    mkdir -p $out/lib/systemd/user
    sed 's|%h/.local/libexec/kos-data-service|${go-service}/bin/shell-data-service|g' \
      ${src}/packaging/systemd/kos-data.service \
      > $out/lib/systemd/user/kos-data.service
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
    cp ${patched-service}/lib/systemd/user/kos-data.service \
      $out/lib/systemd/user/

    runHook postInstall
  '';

  passthru = {
    inherit go-service patched-service;
    service = patched-service;
  };

  meta = with lib; {
    description = "KOS shared data service";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
