cmake_minimum_required(VERSION 3.21)

project(kos_dock_window_animation LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(QT_MAJOR_VERSION 6)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${ECM_MODULE_PATH} ${ECM_KDE_MODULE_DIR})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core DBus Gui Widgets OpenGL Network Xml)
find_package(KF6 REQUIRED COMPONENTS Config)
find_package(KWin REQUIRED COMPONENTS kwineffects)

add_library(kos_dock_window_animation MODULE
    dockwindowanimationeffect.cpp
    main.cpp
)

target_link_libraries(kos_dock_window_animation PRIVATE
    Qt6::Core
    Qt6::DBus
    KF6::ConfigCore
    KWin::kwin
)

install(TARGETS kos_dock_window_animation
    DESTINATION ${KDE_INSTALL_PLUGINDIR}/kwin/effects/plugins)
