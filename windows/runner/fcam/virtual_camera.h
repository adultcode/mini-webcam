#ifndef RUNNER_FCAM_VIRTUAL_CAMERA_H_
#define RUNNER_FCAM_VIRTUAL_CAMERA_H_

#include <windows.h>

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace fcam {

// Publishes frames to the "DirectShow Softcam" virtual webcam
// (https://github.com/tshino/softcam, MIT). softcam.dll is loaded at runtime from
// the executable's directory; the DirectShow filter must be registered once
// (regsvr32) for apps like Zoom/Teams/OBS to see the camera.
//
// softcam paces scSendFrame() to the camera frame rate, so frames are handed to
// a dedicated sender thread and the network/decoder thread never blocks.
class VirtualCamera {
 public:
  VirtualCamera();
  ~VirtualCamera();

  VirtualCamera(const VirtualCamera&) = delete;
  VirtualCamera& operator=(const VirtualCamera&) = delete;

  void SetEnabled(bool enabled);
  bool enabled() const { return enabled_; }

  // Queues an RGBA frame (latest wins). Converted to BGR on the sender thread.
  void Push(const uint8_t* rgba, int width, int height, int fps);

  // Status for the UI.
  bool dll_loaded() const { return dll_ != nullptr; }
  bool active() const { return camera_active_; }
  bool app_connected() const { return app_connected_; }
  std::string error();

 private:
  using CreateFn = void*(__cdecl*)(int, int, float);
  using DeleteFn = void(__cdecl*)(void*);
  using SendFn = void(__cdecl*)(void*, const void*);
  using IsConnectedFn = bool(__cdecl*)(void*);

  bool LoadDll();
  void SenderLoop();
  void SetError(const std::string& message);

  HMODULE dll_ = nullptr;
  CreateFn create_ = nullptr;
  DeleteFn delete_ = nullptr;
  SendFn send_ = nullptr;
  IsConnectedFn is_connected_ = nullptr;

  std::atomic<bool> enabled_{false};
  std::atomic<bool> running_{true};
  std::atomic<bool> camera_active_{false};
  std::atomic<bool> app_connected_{false};

  std::mutex mutex_;
  std::condition_variable cv_;
  std::vector<uint8_t> pending_;  // RGBA
  int pending_width_ = 0;
  int pending_height_ = 0;
  int pending_fps_ = 30;
  bool has_pending_ = false;
  std::string error_;

  std::thread thread_;
};

}  // namespace fcam

#endif  // RUNNER_FCAM_VIRTUAL_CAMERA_H_
