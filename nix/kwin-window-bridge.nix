{
    lib,
    stdenv,
    cmake,
    kdePackages,
    src,
}:

stdenv.mkDerivation {
    pname = "quickshell-kwin-window-bridge";
    version = "unstable";
    src = "${src}/helpers/kwin-window-bridge";

    nativeBuildInputs = [
        cmake
        kdePackages.extra-cmake-modules
    ];

    buildInputs = [
        kdePackages.qtbase
        kdePackages.kiconthemes
    ];

    cmakeFlags = [ "-DCMAKE_BUILD_TYPE=Release" ];
    dontWrapQtApps = true;

    installPhase = ''
        runHook preInstall
        mkdir -p $out/libexec
        install -m 0755 quickshell-kwin-window-bridge $out/libexec/
        runHook postInstall
    '';

    meta = with lib; {
        description = "C++ D-Bus bridge for KWin window enumeration";
        homepage = "https://github.com/SuceV587/NextKde.git";
        license = licenses.gpl3;
        platforms = platforms.linux;
    };
}
