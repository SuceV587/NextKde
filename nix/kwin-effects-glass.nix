{
    lib,
    stdenv,
    cmake,
    kdePackages,
    src,
}:

stdenv.mkDerivation {
    pname = "kwin-glass";
    version = "unstable";
    src = "${src}/vendor/kwin-effects-glass";

    nativeBuildInputs = [
        cmake
        kdePackages.extra-cmake-modules
    ];

    buildInputs = [
        kdePackages.kwin
        kdePackages.qttools
    ];

    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
    dontWrapQtApps = true;

    meta = with lib; {
        description = "Fork of the KWin Blur effect for KDE Plasma 6 with glass/refraction features";
        homepage = "https://github.com/SuceV587/NextKde.git";
        license = licenses.gpl3;
        platforms = platforms.linux;
    };
}
