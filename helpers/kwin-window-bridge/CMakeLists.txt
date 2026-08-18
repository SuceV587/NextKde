cmake_minimum_required(VERSION 3.21)

project(quickshell_kwin_window_bridge LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core Concurrent DBus Gui)
find_package(KF6IconThemes REQUIRED)

qt_standard_project_setup()

qt_add_executable(quickshell-kwin-window-bridge
    src/main.cpp
)

target_link_libraries(quickshell-kwin-window-bridge PRIVATE
    Qt6::Core
    Qt6::Concurrent
    Qt6::DBus
    Qt6::Gui
    KF6::IconThemes
)
