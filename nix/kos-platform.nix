{
    lib,
    stdenv,
    cmake,
    kdePackages,
    src,
}:

stdenv.mkDerivation {
    pname = "kos-platform";
    version = "unstable";
    src = "${src}/platform";

    nativeBuildInputs = [
        cmake
    ];

    buildInputs = [
        kdePackages.qtbase
        kdePackages.qtdeclarative
        kdePackages.kiconthemes
    ];

    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
    dontWrapQtApps = true;

    meta = with lib; {
        description = "KOS platform integration daemon (D-Bus bridge for KWin, network, audio, etc.)";
        homepage = "https://github.com/SuceV587/NextKde.git";
        license = licenses.gpl3;
        platforms = platforms.linux;
    };
}
