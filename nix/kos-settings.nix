{
  lib,
  stdenv,
  cmake,
  kdePackages,
  src,
}:

stdenv.mkDerivation {
  pname = "kos-settings";
  version = "unstable";
  src = "${src}/apps/settings";

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    kdePackages.qtbase
    kdePackages.qtdeclarative
  ];

  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  dontWrapQtApps = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -m 0755 kos-settings $out/bin/
    runHook postInstall
  '';

  meta = with lib; {
    description = "KOS Desktop Shell settings application";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
