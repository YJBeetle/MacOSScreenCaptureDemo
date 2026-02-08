cmake_minimum_required(VERSION 3.16)

project(MacOSTest)

# 查找OpenCV
find_package(OpenCV REQUIRED)

if(NOT OpenCV_FOUND)
    message(FATAL_ERROR "OpenCV not found. Please install OpenCV first.")
endif()

# macOS 窗口测试程序
add_executable(window_test window_test.mm)

# 链接 macOS 框架
find_library(APPLICATION_SERVICES ApplicationServices REQUIRED)
find_library(CORE_FOUNDATION CoreFoundation REQUIRED)
find_library(FOUNDATION Foundation REQUIRED)
find_library(SCREEN_CAPTURE_KIT ScreenCaptureKit REQUIRED)
find_library(CORE_MEDIA CoreMedia REQUIRED)
find_library(CORE_VIDEO CoreVideo REQUIRED)
find_library(APP_KIT AppKit REQUIRED)

target_link_libraries(window_test
    ${OpenCV_LIBS}
    ${APPLICATION_SERVICES}
    ${CORE_FOUNDATION}
    ${FOUNDATION}
    ${SCREEN_CAPTURE_KIT}
    ${CORE_MEDIA}
    ${CORE_VIDEO}
    ${APP_KIT}
)

# 包含OpenCV头文件
target_include_directories(window_test PRIVATE ${OpenCV_INCLUDE_DIRS})
