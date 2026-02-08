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
#include <unistd.h>
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
    std::cout
        << "Displaying screenshot with OpenCV (press any key to continue)..."
        << std::endl;
    cv::imshow("Window Screenshot", captured_image);
    cv::waitKey(1000);
    cv::destroyAllWindows();
  } else {
    std::cout << "Screenshot failed" << std::endl;
  }

  std::cout << std::endl << "Screenshot test completed." << std::endl;
}

// 获取窗口的进程PID
pid_t get_window_pid(CGWindowID window_id) {
  // 获取窗口信息
  CFArrayRef window_list =
      CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, window_id);

  if (!window_list || CFArrayGetCount(window_list) == 0) {
    if (window_list)
      CFRelease(window_list);
    return -1;
  }

  CFDictionaryRef window_info =
      (CFDictionaryRef)CFArrayGetValueAtIndex(window_list, 0);

  // 获取进程PID
  CFNumberRef pid_ref =
      (CFNumberRef)CFDictionaryGetValue(window_info, kCGWindowOwnerPID);
  pid_t pid = -1;
  if (pid_ref) {
    CFNumberGetValue(pid_ref, kCFNumberIntType, &pid);
  }

  CFRelease(window_list);
  return pid;
}

// 激活目标窗口 (使其获得焦点)
bool activate_window(pid_t target_pid) {
  if (target_pid <= 0) {
    std::cout << "Invalid target PID: " << target_pid << std::endl;
    return false;
  }

  std::cout << "Activating window for process " << target_pid << std::endl;

  // 使用NSRunningApplication激活应用
  // 这会将整个应用带到前台
  NSRunningApplication *app =
      [NSRunningApplication runningApplicationWithProcessIdentifier:target_pid];
  if (app) {
    [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    usleep(200000); // 等待窗口激活
    std::cout << "Window activated using NSRunningApplication" << std::endl;
    return true;
  }

  std::cout << "Failed to activate window using NSRunningApplication"
            << std::endl;
  return false;
}

// 模拟鼠标点击 (使用全局事件注入)
bool simulate_mouse_click(pid_t target_pid, CGPoint location,
                          bool is_double_click = false) {
  if (target_pid <= 0) {
    std::cout << "Invalid target PID: " << target_pid << std::endl;
    return false;
  }

  std::cout << "Simulating mouse click at (" << location.x << ", " << location.y
            << ") for process " << target_pid << std::endl;

  // 先激活窗口
  if (!activate_window(target_pid)) {
    std::cout << "Warning: Failed to activate window, click may not work"
              << std::endl;
  }

  // 首先移动鼠标到目标位置
  CGEventRef mouse_move =
      CGEventCreateMouseEvent(nullptr,            // 源事件
                              kCGEventMouseMoved, // 事件类型
                              location,           // 位置
                              kCGMouseButtonLeft  // 鼠标按钮
      );

  if (mouse_move) {
    CGEventPost(kCGHIDEventTap, mouse_move);
    CFRelease(mouse_move);
    usleep(50000); // 等待鼠标移动
  }

  // 创建鼠标按下事件
  CGEventRef click_down =
      CGEventCreateMouseEvent(nullptr,               // 源事件
                              kCGEventLeftMouseDown, // 事件类型
                              location,              // 位置
                              kCGMouseButtonLeft     // 鼠标按钮
      );

  if (!click_down) {
    std::cout << "Failed to create mouse down event" << std::endl;
    return false;
  }

  // 创建鼠标释放事件
  CGEventRef click_up = CGEventCreateMouseEvent(nullptr,             // 源事件
                                                kCGEventLeftMouseUp, // 事件类型
                                                location,            // 位置
                                                kCGMouseButtonLeft   // 鼠标按钮
  );

  if (!click_up) {
    std::cout << "Failed to create mouse up event" << std::endl;
    CFRelease(click_down);
    return false;
  }

  // 如果是双击，设置点击次数
  if (is_double_click) {
    CGEventSetIntegerValueField(click_down, kCGMouseEventClickState, 2);
    CGEventSetIntegerValueField(click_up, kCGMouseEventClickState, 2);
  }

  // 使用全局事件注入
  CGEventPost(kCGHIDEventTap, click_down);
  usleep(10000); // 短暂延迟
  CGEventPost(kCGHIDEventTap, click_up);

  // 清理
  CFRelease(click_down);
  CFRelease(click_up);

  std::cout << "Mouse click simulation completed" << std::endl;
  return true;
}

// 模拟鼠标移动 (使用全局事件注入)
bool simulate_mouse_move(pid_t target_pid, CGPoint location) {
  if (target_pid <= 0) {
    std::cout << "Invalid target PID: " << target_pid << std::endl;
    return false;
  }

  std::cout << "Simulating mouse move to (" << location.x << ", " << location.y
            << ") for process " << target_pid << std::endl;

  // 创建鼠标移动事件
  CGEventRef mouse_move =
      CGEventCreateMouseEvent(nullptr,            // 源事件
                              kCGEventMouseMoved, // 事件类型
                              location,           // 位置
                              kCGMouseButtonLeft  // 鼠标按钮 (移动时不重要)
      );

  if (!mouse_move) {
    std::cout << "Failed to create mouse move event" << std::endl;
    return false;
  }

  // 使用全局事件注入
  CGEventPost(kCGHIDEventTap, mouse_move);

  // 清理
  CFRelease(mouse_move);

  std::cout << "Mouse move simulation completed" << std::endl;
  return true;
}

// 测试输入模拟方法
void test_input_simulation(CGWindowID window_id, const WindowInfo &win_info) {
  std::cout << std::endl << "=== Testing Input Simulation ===" << std::endl;
  std::cout << "Selected window: " << win_info.name << " ("
            << win_info.owner_name << ")" << std::endl;
  std::cout << "Window ID: " << window_id << std::endl;
  std::cout << "Bounds: " << win_info.bounds.origin.x << ", "
            << win_info.bounds.origin.y << " - " << win_info.bounds.size.width
            << "x" << win_info.bounds.size.height << std::endl;

  // 获取目标进程PID
  pid_t target_pid = get_window_pid(window_id);
  if (target_pid <= 0) {
    std::cout << "Failed to get PID for window " << window_id << std::endl;
    return;
  }

  std::cout << "Target process PID: " << target_pid << std::endl;

  // 计算窗口中心点作为点击位置
  CGPoint click_location = {
      win_info.bounds.origin.x + win_info.bounds.size.width / 2,
      win_info.bounds.origin.y + win_info.bounds.size.height / 2};

  std::cout << std::endl << "Testing mouse click simulation..." << std::endl;

  // 模拟鼠标移动到窗口中心
  if (!simulate_mouse_move(target_pid, click_location)) {
    std::cout << "Mouse move simulation failed" << std::endl;
    return;
  }

  // 等待一下
  usleep(500000); // 0.5秒

  // 模拟鼠标点击
  if (!simulate_mouse_click(target_pid, click_location, false)) {
    std::cout << "Mouse click simulation failed" << std::endl;
    return;
  }

  std::cout << "Input simulation test completed successfully!" << std::endl;
  std::cout << "Check if the target window responded to the simulated click."
            << std::endl;
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

  // 测试输入模拟
  test_input_simulation(selected_window->window_id, *selected_window);

  std::cout << std::endl << "=== Test Complete ===" << std::endl;
  return 0;
}