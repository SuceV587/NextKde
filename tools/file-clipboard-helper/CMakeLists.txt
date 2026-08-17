cmake_minimum_required(VERSION 3.21)

project(quickshell_file_clipboard_helper LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Gui)

qt_standard_project_setup()

qt_add_executable(quickshell-file-clipboard-helper
    main.cpp
)

target_link_libraries(quickshell-file-clipboard-helper PRIVATE Qt6::Gui)

install(TARGETS quickshell-file-clipboard-helper
    RUNTIME DESTINATION lib/quickshell
)
