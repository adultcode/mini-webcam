#include "fcam/virtual_camera.h"

#include <chrono>

namespace fcam {

namespace {

std::wstring ExeDirectory() {
  wchar_t path[MAX_PATH];
  DWORD len = GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring dir(path, len);
  size_t slash = dir.find_last_of(L"\\/");
  return slash == std::wstring::npos ? L"." : dir.substr(0, slash);
}

}  // namespace

VirtualCamera::VirtualCamera() {
  thread_ = std::thread(&VirtualCamera::SenderLoop, this);
}

VirtualCamera::~VirtualCamera() {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    running_ = false;
  }
  cv_.notify_all();
  if (thread_.joinable()) thread_.join();
  if (dll_) FreeLibrary(dll_);
}

bool VirtualCamera::LoadDll() {
  if (dll_) return true;
  std::wstring path = ExeDirectory() + L"\\softcam.dll";
  dll_ = LoadLibraryW(path.c_str());
  if (!dll_) {
    SetError("softcam.dll not found next to the executable");
    return false;
  }
  create_ = reinterpret_cast<CreateFn>(GetProcAddress(dll_, "scCreateCamera"));
  delete_ = reinterpret_cast<DeleteFn>(GetProcAddress(dll_, "scDeleteCamera"));
  send_ = reinterpret_cast<SendFn>(GetProcAddress(dll_, "scSendFrame"));
  is_connected_ =
      reinterpret_cast<IsConnectedFn>(GetProcAddress(dll_, "scIsConnected"));
  if (!create_ || !delete_ || !send_) {
    SetError("softcam.dll is missing required exports");
    FreeLibrary(dll_);
    dll_ = nullptr;
    return false;
  }
  return true;
}

void VirtualCamera::SetEnabled(bool enabled) {
  {
    std::lock_guard<std::mutex> lock(mutex_);
    enabled_ = enabled;
    if (enabled) error_.clear();
  }
  cv_.notify_all();
}

void VirtualCamera::Push(const uint8_t* rgba, int width, int height, int fps) {
  if (!enabled_) return;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    const size_t size = static_cast<size_t>(width) * height * 4;
    pending_.assign(rgba, rgba + size);
    pending_width_ = width;
    pending_height_ = height;
    pending_fps_ = fps > 0 ? fps : 30;
    has_pending_ = true;
  }
  cv_.notify_one();
}

std::string VirtualCamera::error() {
  std::lock_guard<std::mutex> lock(mutex_);
  return error_;
}

void VirtualCamera::SetError(const std::string& message) {
  std::lock_guard<std::mutex> lock(mutex_);
  error_ = message;
}

void VirtualCamera::SenderLoop() {
  void* camera = nullptr;
  int cam_width = 0, cam_height = 0;
  std::vector<uint8_t> rgba;
  std::vector<uint8_t> bgr;

  auto destroy = [&]() {
    if (camera) {
      delete_(camera);
      camera = nullptr;
    }
    camera_active_ = false;
    app_connected_ = false;
  };

  while (true) {
    int width = 0, height = 0, fps = 30;
    {
      std::unique_lock<std::mutex> lock(mutex_);
      cv_.wait_for(lock, std::chrono::milliseconds(500), [&] {
        return !running_ || (enabled_ && has_pending_) || (!enabled_ && camera);
      });
      if (!running_) break;
      if (!enabled_) {
        has_pending_ = false;
        lock.unlock();
        destroy();
        continue;
      }
      if (!has_pending_) {
        if (camera && is_connected_) app_connected_ = is_connected_(camera);
        continue;
      }
      rgba.swap(pending_);
      width = pending_width_;
      height = pending_height_;
      fps = pending_fps_;
      has_pending_ = false;
    }

    if (!LoadDll()) continue;

    if (camera && (width != cam_width || height != cam_height)) destroy();
    if (!camera) {
      camera = create_(width, height, static_cast<float>(fps));
      if (!camera) {
        SetError(
            "Could not create the virtual camera (is another app already "
            "publishing to Softcam?)");
        std::this_thread::sleep_for(std::chrono::seconds(1));
        continue;
      }
      cam_width = width;
      cam_height = height;
      camera_active_ = true;
    }

    // RGBA -> BGR, top-down.
    const size_t pixels = static_cast<size_t>(width) * height;
    bgr.resize(pixels * 3);
    const uint8_t* src = rgba.data();
    uint8_t* dst = bgr.data();
    for (size_t i = 0; i < pixels; ++i, src += 4, dst += 3) {
      dst[0] = src[2];
      dst[1] = src[1];
      dst[2] = src[0];
    }
    send_(camera, bgr.data());  // Blocks to pace at the camera frame rate.
    if (is_connected_) app_connected_ = is_connected_(camera);
  }
  destroy();
}

}  // namespace fcam
