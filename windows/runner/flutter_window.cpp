#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

namespace {
constexpr LONG kFixedWidth = 400;
constexpr LONG kFixedHeight = 720;
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // Remove resize border and maximize button for fixed-size window
  HWND hwnd = GetHandle();
  LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
  style &= ~(WS_THICKFRAME | WS_MAXIMIZEBOX);
  SetWindowLongPtr(hwnd, GWL_STYLE, style);
  // Recalculate the non-client area after style change
  SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
               SWP_NOZORDER | SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_GETMINMAXINFO: {
      MINMAXINFO* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
      // Fixed window size
      mmi->ptMinTrackSize.x = kFixedWidth;
      mmi->ptMinTrackSize.y = kFixedHeight;
      mmi->ptMaxTrackSize.x = kFixedWidth;
      mmi->ptMaxTrackSize.y = kFixedHeight;
      mmi->ptMaxSize.x = kFixedWidth;
      mmi->ptMaxSize.y = kFixedHeight;
      return 0;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
