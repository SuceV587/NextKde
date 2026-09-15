{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  kdePackages,
  gst_all_1,
  taglib,
  src,
}:

let
  # Keep the GStreamer plugins discoverable at runtime. NixOS does not set
  # GST_PLUGIN_SYSTEM_PATH_1_0 globally, so bake the core/base/good plugin
  # directories into the application wrappers.
  gstPlugins = lib.makeSearchPath "lib/gstreamer-1.0" [
    gst_all_1.gstreamer.out
    gst_all_1.gst-plugins-base.out
    gst_all_1.gst-plugins-good.out
  ];
in
# Standalone KOS applications (Calendar, Todo, Music) and the shared
# D-Bus-activated PIM service. Weather keeps its own derivation so the
# NixOS module can enable it independently of the app suite.
stdenv.mkDerivation {
  pname = "kos-apps";
  version = "unstable";
  inherit src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    kdePackages.extra-cmake-modules
    kdePackages.wrapQtAppsHook
  ];

  buildInputs = [
    kdePackages.qtbase
    kdePackages.qtdeclarative
    kdePackages.kwindowsystem
    kdePackages.kcalendarcore
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    taglib
  ];

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=Release"
    "-DKOS_BUILD_PLATFORM=OFF"
    "-DKOS_BUILD_KWIN_PLUGINS=OFF"
    "-DKOS_BUILD_CALENDAR=ON"
    "-DKOS_BUILD_TODO=ON"
    "-DKOS_BUILD_WEATHER=OFF"
    "-DKOS_BUILD_MUSIC=ON"
    "-DBUILD_TESTING=OFF"
  ];

  qtWrapperArgs = [
    "--prefix GST_PLUGIN_SYSTEM_PATH_1_0 : ${gstPlugins}"
    "--prefix GST_PLUGIN_PATH_1_0 : ${gstPlugins}"
  ];

  meta = with lib; {
    description = "KOS standalone applications (Calendar, Todo, Music) and the PIM service";
    homepage = "https://gitee.com/xiaoyintx_ciallo/test";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
