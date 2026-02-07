/**
 * macOS 窗口测试程序
 *
 * 用法：
 * 1. 编译并运行此程序
 * 2. 程序会列出当前可见窗口
 * 3. 用户选择窗口进行测试
 * 4. 显示窗口信息
 * 5. 测试截图方法
 *
 * 此程序用于测试macOS上的窗口查找和信息获取
 */

#include <opencv2/opencv.hpp>

#include <ApplicationServices/ApplicationServices.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreMedia/CoreMedia.h>
#include <CoreVideo/CoreVideo.h>
#include <ScreenCaptureKit/ScreenCaptureKit.h>
#include <iostream>
#include <map>
#include <string>
#include <vector>

// 窗口信息结构体
struct WindowInfo {
  CGWindowID window_id;
  std::string name;
  std::string owner_name;
  CGRect bounds;
  bool is_on_screen;
};

// 获取窗口列表
std::vector<WindowInfo> get_window_list() {
  std::vector<WindowInfo> windows;

  // 获取所有窗口信息
  CFArrayRef window_list = CGWindowListCopyWindowInfo(
      kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
      kCGNullWindowID);

  if (!window_list) {
    std::cerr << "Failed to get window list" << std::endl;
    return windows;
  }

  CFIndex count = CFArrayGetCount(window_list);
  std::cout << "Total windows found: " << count << std::endl;

  for (CFIndex i = 0; i < count; ++i) {
    CFDictionaryRef window_info =
        (CFDictionaryRef)CFArrayGetValueAtIndex(window_list, i);

    // 获取窗口ID
    CFNumberRef window_id_ref =
        (CFNumberRef)CFDictionaryGetValue(window_info, kCGWindowNumber);
    CGWindowID window_id = 0;
    CFNumberGetValue(window_id_ref, kCFNumberIntType, &window_id);

    // 获取窗口名称
    CFStringRef window_name_ref =
        (CFStringRef)CFDictionaryGetValue(window_info, kCGWindowName);
    std::string window_name;
    if (window_name_ref) {
      char buffer[256];
      CFStringGetCString(window_name_ref, buffer, sizeof(buffer),
                         kCFStringEncodingUTF8);
      window_name = buffer;
    }

    // 获取所有者名称
    CFStringRef owner_name_ref =
        (CFStringRef)CFDictionaryGetValue(window_info, kCGWindowOwnerName);
    std::string owner_name;
    if (owner_name_ref) {
      char buffer[256];
      CFStringGetCString(owner_name_ref, buffer, sizeof(buffer),
                         kCFStringEncodingUTF8);
      owner_name = buffer;
    }

    // 获取窗口边界
    CFDictionaryRef bounds_ref =
        (CFDictionaryRef)CFDictionaryGetValue(window_info, kCGWindowBounds);
    CGRect bounds = CGRectNull;
    if (bounds_ref) {
      CFNumberRef x_ref =
          (CFNumberRef)CFDictionaryGetValue(bounds_ref, CFSTR("X"));
      CFNumberRef y_ref =
          (CFNumberRef)CFDictionaryGetValue(bounds_ref, CFSTR("Y"));
      CFNumberRef width_ref =
          (CFNumberRef)CFDictionaryGetValue(bounds_ref, CFSTR("Width"));
      CFNumberRef height_ref =
          (CFNumberRef)CFDictionaryGetValue(bounds_ref, CFSTR("Height"));

      if (x_ref && y_ref && width_ref && height_ref) {
        CFNumberGetValue(x_ref, kCFNumberDoubleType, &bounds.origin.x);
        CFNumberGetValue(y_ref, kCFNumberDoubleType, &bounds.origin.y);
        CFNumberGetValue(width_ref, kCFNumberDoubleType, &bounds.size.width);
        CFNumberGetValue(height_ref, kCFNumberDoubleType, &bounds.size.height);
      }
    }

    // 检查是否在屏幕上
    CFBooleanRef on_screen_ref =
        (CFBooleanRef)CFDictionaryGetValue(window_info, kCGWindowIsOnscreen);
    bool is_on_screen =
        on_screen_ref ? CFBooleanGetValue(on_screen_ref) : false;

    // 只显示有名称的窗口
    if (!window_name.empty() && is_on_screen) {
      windows.push_back(
          {window_id, window_name, owner_name, bounds, is_on_screen});
    }
  }

  CFRelease(window_list);
  return windows;
}

// 显示窗口列表
void display_window_list(const std::vector<WindowInfo> &windows) {
  std::cout << "Found " << windows.size() << " windows:" << std::endl;
  for (size_t i = 0; i < windows.size(); ++i) {
    const auto &win = windows[i];
    std::cout << "  [" << i << "] " << win.name << " (" << win.owner_name << ")"
              << std::endl;
    std::cout << "      Size: " << win.bounds.size.width << "x"
              << win.bounds.size.height << std::endl;
    std::cout << "      Position: (" << win.bounds.origin.x << ", "
              << win.bounds.origin.y << ")" << std::endl;
  }
}

// 选择窗口
WindowInfo *select_window(std::vector<WindowInfo> &windows) {
  std::cout << std::endl
            << "Enter window index to test (or window name keyword): ";
  std::string input;
  std::getline(std::cin, input);

  // 尝试解析为数字索引
  try {
    size_t index = std::stoul(input);
    if (index < windows.size()) {
      return &windows[index];
    }
  } catch (...) {
    // 按名称搜索
    for (auto &win : windows) {
      if (win.name.find(input) != std::string::npos ||
          win.owner_name.find(input) != std::string::npos) {
        return &win;
      }
    }
  }

  return nullptr;
}

// 检查屏幕录制权限
bool check_screen_recording_permission() {
  // 使用CGPreflightScreenCaptureAccess()检查权限
  // 这个函数在macOS 10.15+可用
  if (__builtin_available(macOS 10.15, *)) {
    return CGPreflightScreenCaptureAccess();
  }
  return true; // 旧版本默认有权限
}

// 请求屏幕录制权限
bool request_screen_recording_permission() {
  if (__builtin_available(macOS 10.15, *)) {
    return CGRequestScreenCaptureAccess();
  }
  return true;
}

// 显示权限状态和引导信息
void show_permission_status() {
  std::cout << std::endl << "=== Permission Status ===" << std::endl;

  bool has_permission = check_screen_recording_permission();
  std::cout << "Screen Recording Permission: "
            << (has_permission ? "GRANTED" : "DENIED") << std::endl;

  while (!has_permission) {
    // 尝试请求权限（在某些情况下如首次运行可能有效）
    std::cout << "Attempting to request permission..." << std::endl;
    if (request_screen_recording_permission()) {
      std::cout
          << "Permission request completed. Check if permission was granted."
          << std::endl;
    } else {
      std::cout << "Permission request failed or not supported in this context."
                << std::endl;
      std::cout << std::endl;
      std::cout << "To access all windows (including other applications), you "
                   "need to grant Screen Recording permission:"
                << std::endl;
      std::cout << std::endl;
      std::cout << "Method 1 - System Preferences:" << std::endl;
      std::cout << "1. Open System Preferences > Security & Privacy > Privacy"
                << std::endl;
      std::cout << "2. Select 'Screen Recording' from the left sidebar"
                << std::endl;
      std::cout << "3. Click the lock icon and enter your password if needed"
                << std::endl;
      std::cout << "4. Click the '+' button and add Terminal.app (or your IDE)"
                << std::endl;
      std::cout << "5. Check the box next to Terminal (or your IDE)"
                << std::endl;
      std::cout << "6. Restart this application" << std::endl;
      std::cout << std::endl;
      std::cout << "Method 2 - Command Line (for development):" << std::endl;
      std::cout << "Run: tccutil reset ScreenCapture" << std::endl;
      std::cout
          << "Then re-run this program and grant permission when prompted."
          << std::endl;
      std::cout << std::endl;

      std::cout << "Note: Currently only system windows are visible. "
                << std::endl;
      std::cout << "After granting permission, you should see windows from all "
                   "applications."
                << std::endl;
      std::cout << std::endl;
    }

    if (std::cin.good()) {
      std::cout << "Would you like to check again? (y/n): ";
      std::string choice;
      std::getline(std::cin, choice);
      if (choice == "y" || choice == "Y") {
        has_permission = check_screen_recording_permission();
      } else {
        break;
      }
    } else {
      break;
    }
  }

  if (has_permission) {
    std::cout
        << "✓ Permission granted! You should see windows from all applications."
        << std::endl;
  }

  std::cout << std::endl;
}

// 纯C包装函数，内部使用Objective-C调用ScreenCaptureKit
cv::Mat capture_window_screenshot(CGWindowID window_id, size_t width,
                                  size_t height) {
  cv::Mat result;

  // 检查macOS版本
  if (__builtin_available(macOS 12.3, *)) {
    // 使用GCD信号量进行同步
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block cv::Mat captured_image;

    // 异步获取可共享内容
    [SCShareableContent getShareableContentWithCompletionHandler:^(
                            SCShareableContent *content, NSError *error) {
      if (error || !content) {
        std::cout << "Failed to get shareable content" << std::endl;
        dispatch_semaphore_signal(semaphore);
        return;
      }

      // 查找目标窗口
      SCWindow *targetWindow = nil;
      for (SCWindow *window in content.windows) {
        if (window.windowID == window_id) {
          targetWindow = window;
          break;
        }
      }

      if (!targetWindow) {
        std::cout << "Target window not found" << std::endl;
        dispatch_semaphore_signal(semaphore);
        return;
      }

      // 创建内容过滤器
      SCContentFilter *filter = [[SCContentFilter alloc]
          initWithDesktopIndependentWindow:targetWindow];
      if (!filter) {
        std::cout << "Failed to create content filter" << std::endl;
        dispatch_semaphore_signal(semaphore);
        return;
      }

      // 创建截图配置
      SCStreamConfiguration *config = [[SCStreamConfiguration alloc] init];
      config.width = width;
      config.height = height;
      config.pixelFormat = kCVPixelFormatType_32BGRA;
      config.colorSpaceName = kCGColorSpaceSRGB;

      // 执行截图
      [SCScreenshotManager
          captureSampleBufferWithFilter:filter
                          configuration:config
                      completionHandler:^(CMSampleBufferRef sampleBuffer,
                                          NSError *error) {
                        if (error || !sampleBuffer) {
                          std::cout << "Screenshot failed" << std::endl;
                          [filter release];
                          [config release];
                          dispatch_semaphore_signal(semaphore);
                          return;
                        }

                        // 处理图像数据
                        CVImageBufferRef imageBuffer =
                            CMSampleBufferGetImageBuffer(sampleBuffer);
                        if (imageBuffer) {
                          CVPixelBufferLockBaseAddress(
                              imageBuffer, kCVPixelBufferLock_ReadOnly);

                          void *baseAddress =
                              CVPixelBufferGetBaseAddress(imageBuffer);
                          size_t width = CVPixelBufferGetWidth(imageBuffer);
                          size_t height = CVPixelBufferGetHeight(imageBuffer);
                          size_t bytesPerRow =
                              CVPixelBufferGetBytesPerRow(imageBuffer);

                          if (baseAddress && width > 0 && height > 0) {
                            captured_image =
                                cv::Mat((int)height, (int)width, CV_8UC4,
                                        baseAddress, bytesPerRow)
                                    .clone();
                          }

                          CVPixelBufferUnlockBaseAddress(
                              imageBuffer, kCVPixelBufferLock_ReadOnly);
                        }

                        [filter release];
                        [config release];
                        dispatch_semaphore_signal(semaphore);
                      }];
    }];

    // 等待完成
    if (dispatch_semaphore_wait(
            semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) ==
        0) {
      result = captured_image;
    }
  } else {
    std::cout << "ScreenCaptureKit requires macOS 12.3 or later" << std::endl;
  }

  return result;
}

// 测试截图方法
void test_screencap_methods(CGWindowID window_id, const WindowInfo &win_info) {
  std::cout << std::endl
            << "Selected window: " << win_info.name << " ("
            << win_info.owner_name << ")" << std::endl;
  std::cout << "Window ID: " << window_id << std::endl;
  std::cout << "Bounds: " << win_info.bounds.origin.x << ", "
            << win_info.bounds.origin.y << " - " << win_info.bounds.size.width
            << "x" << win_info.bounds.size.height << std::endl;

  std::cout << std::endl << "Testing screenshot..." << std::endl;

  cv::Mat captured_image = capture_window_screenshot(
      window_id, win_info.bounds.size.width, win_info.bounds.size.height);

  if (!captured_image.empty()) {
    std::cout << "Screenshot captured successfully!" << std::endl;
    std::cout << "Image size: " << captured_image.cols << "x"
              << captured_image.rows << std::endl;

    // 显示截图
    std::cout << "Displaying screenshot with OpenCV..." << std::endl;
    cv::imshow("Window Screenshot", captured_image);
    cv::waitKey(0);
    cv::destroyAllWindows();
  } else {
    std::cout << "Screenshot failed" << std::endl;
  }

  std::cout << std::endl << "Screenshot test completed." << std::endl;
}

int main() {
  std::cout << "=== macOS Window Test ===" << std::endl;
  std::cout << "PID: " << getpid() << std::endl;
  std::cout << std::endl;

  // 检查和显示权限状态
  show_permission_status();

  // 获取窗口列表
  auto windows = get_window_list();
  if (windows.empty()) {
    std::cout << "No windows found" << std::endl;
    return -1;
  }

  // 显示窗口列表
  display_window_list(windows);

  // 选择窗口
  WindowInfo *selected_window = select_window(windows);
  if (!selected_window) {
    std::cout << "Window not found" << std::endl;
    return -1;
  }

  // 测试截图方法
  test_screencap_methods(selected_window->window_id, *selected_window);

  std::cout << std::endl << "=== Test Complete ===" << std::endl;
  return 0;
}