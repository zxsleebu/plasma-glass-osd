cmake_minimum_required(VERSION 3.20)
project(osdblur LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
find_package(Qt6 REQUIRED COMPONENTS Gui Qml)
find_package(KF6WindowSystem REQUIRED)
qt_standard_project_setup(REQUIRES 6.5)
qt_add_qml_module(osdblur
    URI OsdBlur
    VERSION 1.0
    SHARED
    PLUGIN_TARGET osdblur
    OUTPUT_DIRECTORY ${OSDBLUR_OUT}/OsdBlur
    SOURCES windowblur.h windowblur.cpp
)
target_link_libraries(osdblur PRIVATE Qt6::Gui Qt6::Qml KF6::WindowSystem)
