#ifndef RUNNER_FCAM_RECEIVER_H_
#define RUNNER_FCAM_RECEIVER_H_

#include <winsock2.h>
#include <windows.h>

#include <flutter/encodable_value.h>
#include <flutter/texture_registrar.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "fcam/decoders.h"
#include "fcam/virtual_camera.h"

namespace fcam {

// Connects to the phone's FCAM stream, decodes it natively and fans the frames
// out to the Flutter preview texture and the virtual webcam. No video data ever
// crosses the platform channel; Dart only polls Status().
class Receiver {
 public:
  explicit Receiver(flutter::TextureRegistrar* textures);
  ~Receiver();

  Receiver(const Receiver&) = delete;
  Receiver& operator=(const Receiver&) = delete;

  int64_t texture_id() const { return texture_id_; }

  void Connect(const std::string& host, int port);
  void Disconnect();
  void SetTransform(int rotation, bool mirror);
  void SetPreviewEnabled(bool enabled) { preview_enabled_ = enabled; }
  // Output aspect ratio (0:0 = keep the camera's). fill=true crops, false pads.
  void SetAspect(int aspect_w, int aspect_h, bool fill);
  void SetVirtualCameraEnabled(bool enabled) { vcam_.SetEnabled(enabled); }

  flutter::EncodableMap Status();

  // Saves the latest preview frame (after rotation/mirror) as a PNG.
  bool SaveSnapshot(const std::wstring& path, std::string* error);

 private:
  void Run(std::string host, int port);
  bool StreamSession(SOCKET s);
  SOCKET OpenSocket(const std::string& host, int port, std::string* error);
  bool RecvAll(SOCKET s, uint8_t* buffer, size_t size);
  bool WaitOrStop(std::chrono::milliseconds duration);

  void OnHello(const std::string& json);
  void OnH264(const uint8_t* data, size_t size, int64_t pts, bool keyframe);
  void OnJpeg(const uint8_t* data, size_t size);
  void Present(const uint8_t* rgba, int width, int height);
  const uint8_t* Reframe(const uint8_t* src, int* width, int* height);

  void SetState(const std::string& state, const std::string& message);
  const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t width, size_t height);

  flutter::TextureRegistrar* textures_;
  std::unique_ptr<flutter::TextureVariant> texture_;
  int64_t texture_id_ = -1;

  // Preview double buffer: decoder thread fills back_, swaps under lock.
  std::mutex pixel_mutex_;
  std::vector<uint8_t> front_;
  std::vector<uint8_t> back_;
  int front_width_ = 0;
  int front_height_ = 0;
  FlutterDesktopPixelBuffer pixel_buffer_{};

  std::thread thread_;
  std::atomic<bool> running_{false};
  std::mutex socket_mutex_;
  SOCKET socket_ = INVALID_SOCKET;
  std::mutex wait_mutex_;
  std::condition_variable wait_cv_;

  // Decoder-thread state.
  std::unique_ptr<H264Decoder> h264_;
  JpegDecoder jpeg_;
  std::vector<uint8_t> config_;
  std::vector<uint8_t> au_;
  std::vector<uint8_t> rgba_;
  std::vector<uint8_t> transformed_;
  std::vector<uint8_t> reframed_;
  std::atomic<int> aspect_w_{0};
  std::atomic<int> aspect_h_{0};
  std::atomic<bool> aspect_fill_{false};
  std::vector<uint8_t> payload_;
  int stream_fps_ = 30;
  std::atomic<int> rotation_{0};
  std::atomic<bool> mirror_{false};
  std::atomic<bool> preview_enabled_{true};

  VirtualCamera vcam_;

  // Status shared with the platform thread.
  std::mutex status_mutex_;
  std::string state_ = "idle";
  std::string message_;
  std::string codec_;
  std::string device_;
  int width_ = 0;
  int height_ = 0;
  std::atomic<uint64_t> frames_{0};
  std::atomic<uint64_t> bytes_{0};
  std::atomic<uint64_t> decode_us_{0};
  std::atomic<uint64_t> decode_errors_{0};
  std::chrono::steady_clock::time_point last_status_ =
      std::chrono::steady_clock::now();
};

}  // namespace fcam

#endif  // RUNNER_FCAM_RECEIVER_H_
