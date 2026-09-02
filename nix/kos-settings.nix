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
    # Install QML files: main.qml expects ../share/kos/settings/ relative to binary
    # and ../../shared/qml/controls relative to main.qml
    mkdir -p $out/share/kos/settings
    cp ${src}/main.qml $out/share/kos/settings/main.qml
    mkdir -p $out/share/shared/qml
    cp -r ${src}/../shared/qml/controls $out/share/shared/qml/controls
    runHook postInstall
  '';

  meta = with lib; {
    description = "KOS Desktop Shell settings application";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
