{
  lib,
  stdenv,
  cmake,
  kdePackages,
  src,
}:

stdenv.mkDerivation {
  pname = "kwin-context-menu-input";
  version = "unstable";
  src = "${src}/integrations/kwin-context-menu-input";

  nativeBuildInputs = [
    cmake
    kdePackages.extra-cmake-modules
  ];

  buildInputs = [
    kdePackages.kwin
    kdePackages.qtbase
  ];

  cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
  dontWrapQtApps = true;

  meta = with lib; {
    description = "KWin effect for context menu outside-click dismiss";
    homepage = "https://github.com/SuceV587/NextKde";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
