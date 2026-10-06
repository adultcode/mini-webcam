#include "fcam/receiver.h"

#include <mfapi.h>
#include <ppl.h>
#include <ws2tcpip.h>

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <cstring>

namespace fcam {

namespace {

constexpr size_t kHeaderSize = 16;
constexpr uint32_t kMaxPayload = 64u * 1024u * 1024u;
constexpr uint8_t kTypeHello = 0x01;
constexpr uint8_t kTypeH264 = 0x02;
constexpr uint8_t kTypeJpeg = 0x03;
constexpr uint8_t kTypeCodecConfig = 0x04;
constexpr uint8_t kFlagKeyframe = 0x01;

uint64_t ReadBe64(const uint8_t* p) {
  uint64_t v = 0;
  for (int i = 0; i < 8; ++i) v = (v << 8) | p[i];
  return v;
}

uint32_t ReadBe32(const uint8_t* p) {
  return (static_cast<uint32_t>(p[0]) << 24) |
         (static_cast<uint32_t>(p[1]) << 16) |
         (static_cast<uint32_t>(p[2]) << 8) | static_cast<uint32_t>(p[3]);
}

// Minimal extraction for the flat HELLO object; avoids a JSON dependency.
std::string JsonString(const std::string& json, const char* key) {
  std::string needle = std::string("\"") + key + "\"";
  size_t pos = json.find(needle);
  if (pos == std::string::npos) return "";
  pos = json.find(':', pos + needle.size());
  if (pos == std::string::npos) return "";
  pos = json.find('"', pos);
  if (pos == std::string::npos) return "";
  size_t end = json.find('"', pos + 1);
  if (end == std::string::npos) return "";
  return json.substr(pos + 1, end - pos - 1);
}

int JsonInt(const std::string& json, const char* key, int fallback) {
  std::string needle = std::string("\"") + key + "\"";
  size_t pos = json.find(needle);
  if (pos == std::string::npos) return fallback;
  pos = json.find(':', pos + needle.size());
  if (pos == std::string::npos) return fallback;
  return static_cast<int>(strtol(json.c_str() + pos + 1, nullptr, 10));
}

}  // namespace

Receiver::Receiver(flutter::TextureRegistrar* textures) : textures_(textures) {
  WSADATA wsa;
  WSAStartup(MAKEWORD(2, 2), &wsa);

  texture_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture([this](size_t width, size_t height) {
        return CopyPixelBuffer(width, height);
      }));
  texture_id_ = textures_->RegisterTexture(texture_.get());
}

Receiver::~Receiver() {
  Disconnect();

  // Wait until the raster thread is done with the texture before freeing it.
  auto done = std::make_shared<std::pair<std::mutex, std::condition_variable>>();
  auto finished = std::make_shared<bool>(false);
  textures_->UnregisterTexture(texture_id_, [done, finished]() {
    std::lock_guard<std::mutex> lock(done->first);
    *finished = true;
    done->second.notify_all();
  });
  std::unique_lock<std::mutex> lock(done->first);
  done->second.wait_for(lock, std::chrono::milliseconds(500),
                        [&] { return *finished; });

  WSACleanup();
}

// ---------------------------------------------------------------------------
// Connection management (platform thread)
// ---------------------------------------------------------------------------

void Receiver::Connect(const std::string& host, int port) {
  Disconnect();
  running_ = true;
  thread_ = std::thread(&Receiver::Run, this, host, port);
}

void Receiver::Disconnect() {
  running_ = false;
  {
    std::lock_guard<std::mutex> lock(socket_mutex_);
    if (socket_ != INVALID_SOCKET) shutdown(socket_, SD_BOTH);
  }
  wait_cv_.notify_all();
  if (thread_.joinable()) thread_.join();
}

void Receiver::SetTransform(int rotation, bool mirror) {
  rotation = ((rotation % 360) + 360) % 360;
  rotation_ = (rotation / 90) * 90;
  mirror_ = mirror;
}

flutter::EncodableMap Receiver::Status() {
  using flutter::EncodableValue;
  const auto now = std::chrono::steady_clock::now();
  const double seconds =
      std::chrono::duration<double>(now - last_status_).count();
  last_status_ = now;
  const uint64_t frames = frames_.exchange(0);
  const uint64_t bytes = bytes_.exchange(0);
  const uint64_t decode_us = decode_us_.exchange(0);

  flutter::EncodableMap map;
  {
    std::lock_guard<std::mutex> lock(status_mutex_);
    map[EncodableValue("state")] = EncodableValue(state_);
    map[EncodableValue("message")] = EncodableValue(message_);
    map[EncodableValue("codec")] = EncodableValue(codec_);
    map[EncodableValue("device")] = EncodableValue(device_);
    map[EncodableValue("width")] = EncodableValue(width_);
    map[EncodableValue("height")] = EncodableValue(height_);
  }
  const double safe = seconds > 0.001 ? seconds : 0.001;
  map[EncodableValue("fps")] = EncodableValue(static_cast<double>(frames) / safe);
  map[EncodableValue("kbps")] =
      EncodableValue(static_cast<double>(bytes) * 8.0 / 1000.0 / safe);
  map[EncodableValue("decodeMs")] = EncodableValue(
      frames > 0 ? static_cast<double>(decode_us) / 1000.0 / frames : 0.0);
  map[EncodableValue("decodeErrors")] =
      EncodableValue(static_cast<int64_t>(decode_errors_.load()));
  map[EncodableValue("textureId")] = EncodableValue(texture_id_);
  map[EncodableValue("vcamEnabled")] = EncodableValue(vcam_.enabled());
  map[EncodableValue("vcamActive")] = EncodableValue(vcam_.active());
  map[EncodableValue("vcamAppConnected")] =
      EncodableValue(vcam_.app_connected());
  map[EncodableValue("vcamError")] = EncodableValue(vcam_.error());
  return map;
}

void Receiver::SetState(const std::string& state, const std::string& message) {
  std::lock_guard<std::mutex> lock(status_mutex_);
  state_ = state;
  message_ = message;
}

// ---------------------------------------------------------------------------
// Network thread
// ---------------------------------------------------------------------------

bool Receiver::WaitOrStop(std::chrono::milliseconds duration) {
  std::unique_lock<std::mutex> lock(wait_mutex_);
  wait_cv_.wait_for(lock, duration, [this] { return !running_; });
  return running_;
}

void Receiver::Run(std::string host, int port) {
  CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  MFStartup(MF_VERSION, MFSTARTUP_NOSOCKET);
  const std::string target = host + ":" + std::to_string(port);

  bool first = true;
  while (running_) {
    SetState(first ? "connecting" : "reconnecting", target);
    first = false;

    std::string error;
    SOCKET s = OpenSocket(host, port, &error);
    if (s != INVALID_SOCKET) {
      {
        std::lock_guard<std::mutex> lock(socket_mutex_);
        socket_ = s;
      }
      if (running_) StreamSession(s);
      {
        std::lock_guard<std::mutex> lock(socket_mutex_);
        socket_ = INVALID_SOCKET;
      }
      closesocket(s);
      error = "Connection to phone lost";
    }
    if (!running_) break;
    SetState("reconnecting", error + ". Retrying...");
    WaitOrStop(std::chrono::milliseconds(1500));
  }

  // COM objects must be released on the thread that created them.
  h264_.reset();
  jpeg_ = JpegDecoder();
  MFShutdown();
  CoUninitialize();
  SetState("idle", "");
}

SOCKET Receiver::OpenSocket(const std::string& host, int port,
                            std::string* error) {
  addrinfo hints{};
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_protocol = IPPROTO_TCP;
  addrinfo* result = nullptr;
  if (getaddrinfo(host.c_str(), std::to_string(port).c_str(), &hints,
                  &result) != 0 ||
      !result) {
    *error = "Cannot resolve " + host;
    return INVALID_SOCKET;
  }

  SOCKET s = socket(result->ai_family, result->ai_socktype, result->ai_protocol);
  if (s == INVALID_SOCKET) {
    freeaddrinfo(result);
    *error = "Socket error";
    return INVALID_SOCKET;
  }

  // Non-blocking connect with a 3 s timeout.
  u_long non_blocking = 1;
  ioctlsocket(s, FIONBIO, &non_blocking);
  connect(s, result->ai_addr, static_cast<int>(result->ai_addrlen));
  freeaddrinfo(result);

  fd_set write_set, error_set;
  FD_ZERO(&write_set);
  FD_ZERO(&error_set);
  FD_SET(s, &write_set);
  FD_SET(s, &error_set);
  timeval timeout{3, 0};
  int ready = select(0, nullptr, &write_set, &error_set, &timeout);
  int so_error = 0;
  int len = sizeof(so_error);
  getsockopt(s, SOL_SOCKET, SO_ERROR, reinterpret_cast<char*>(&so_error), &len);
  if (ready <= 0 || FD_ISSET(s, &error_set) || so_error != 0) {
    closesocket(s);
    *error = ready == 0 ? "Phone not reachable (timeout)"
                        : "Phone refused the connection (is streaming on?)";
    return INVALID_SOCKET;
  }

  non_blocking = 0;
  ioctlsocket(s, FIONBIO, &non_blocking);
  DWORD recv_timeout = 5000;  // The phone always sends at least ~10 fps.
  setsockopt(s, SOL_SOCKET, SO_RCVTIMEO,
             reinterpret_cast<const char*>(&recv_timeout), sizeof(recv_timeout));
  int recv_buffer = 4 * 1024 * 1024;
  setsockopt(s, SOL_SOCKET, SO_RCVBUF,
             reinterpret_cast<const char*>(&recv_buffer), sizeof(recv_buffer));
  return s;
}

bool Receiver::RecvAll(SOCKET s, uint8_t* buffer, size_t size) {
  size_t received = 0;
  while (received < size) {
    int chunk = static_cast<int>(size - received > (1u << 20) ? (1u << 20)
                                                              : size - received);
    int n = recv(s, reinterpret_cast<char*>(buffer + received), chunk, 0);
    if (n <= 0) return false;
    received += static_cast<size_t>(n);
  }
  return true;
}

bool Receiver::StreamSession(SOCKET s) {
  uint8_t header[kHeaderSize];
  while (running_) {
    if (!RecvAll(s, header, kHeaderSize)) return false;
    if (header[0] != 'F' || header[1] != 'C') {
      SetState("error", "Unexpected data from phone (version mismatch?)");
      return false;
    }
    const uint8_t type = header[2];
    const bool keyframe = (header[3] & kFlagKeyframe) != 0;
    const int64_t pts = static_cast<int64_t>(ReadBe64(header + 4));
    const uint32_t size = ReadBe32(header + 12);
    if (size > kMaxPayload) return false;

    payload_.resize(size);
    if (size > 0 && !RecvAll(s, payload_.data(), size)) return false;
    bytes_ += kHeaderSize + size;

    switch (type) {
      case kTypeHello:
        OnHello(std::string(payload_.begin(), payload_.end()));
        break;
      case kTypeCodecConfig:
        config_ = payload_;
        break;
      case kTypeH264:
        OnH264(payload_.data(), payload_.size(), pts, keyframe);
        break;
      case kTypeJpeg:
        OnJpeg(payload_.data(), payload_.size());
        break;
      default:
        break;  // Unknown packet types are skipped for forward compatibility.
    }
  }
  return true;
}

void Receiver::OnHello(const std::string& json) {
  const std::string codec = JsonString(json, "codec");
  const int width = JsonInt(json, "width", 0);
  const int height = JsonInt(json, "height", 0);
  stream_fps_ = JsonInt(json, "fps", 30);

  h264_.reset();
  config_.clear();
  if (codec == "h264") {
    h264_ = std::make_unique<H264Decoder>(width, height, stream_fps_);
  }

  std::lock_guard<std::mutex> lock(status_mutex_);
  codec_ = codec;
  device_ = JsonString(json, "device");
  width_ = width;
  height_ = height;
  state_ = "streaming";
  message_.clear();
}

void Receiver::OnH264(const uint8_t* data, size_t size, int64_t pts,
                      bool keyframe) {
  if (!h264_) return;
  // Make every IDR self-contained so the decoder can (re)start on it.
  if (keyframe && !config_.empty() && FirstNalType(data, size) != 7) {
    au_.assign(config_.begin(), config_.end());
    au_.insert(au_.end(), data, data + size);
    data = au_.data();
    size = au_.size();
  }

  const auto start = std::chrono::steady_clock::now();
  const bool ok = h264_->Decode(data, size, pts, [&](const Nv12View& view) {
    rgba_.resize(static_cast<size_t>(view.width) * view.height * 4);
    Nv12ToRgba(view, rgba_.data());
    decode_us_ += static_cast<uint64_t>(
        std::chrono::duration_cast<std::chrono::microseconds>(
            std::chrono::steady_clock::now() - start)
            .count());
    Present(rgba_.data(), view.width, view.height);
  });
  if (!ok) ++decode_errors_;
}

void Receiver::OnJpeg(const uint8_t* data, size_t size) {
  int width = 0, height = 0;
  const auto start = std::chrono::steady_clock::now();
  if (!jpeg_.Decode(data, size, &rgba_, &width, &height)) {
    ++decode_errors_;
    return;
  }
  decode_us_ += static_cast<uint64_t>(
      std::chrono::duration_cast<std::chrono::microseconds>(
          std::chrono::steady_clock::now() - start)
          .count());
  Present(rgba_.data(), width, height);
}

void Receiver::Present(const uint8_t* rgba, int width, int height) {
  const int rotation = rotation_;
  const bool mirror = mirror_;
  const uint8_t* src = rgba;
  int w = width;
  int h = height;

  if (rotation != 0 || mirror) {
    const bool swap = rotation == 90 || rotation == 270;
    const int ow = swap ? height : width;
    const int oh = swap ? width : height;
    transformed_.resize(static_cast<size_t>(ow) * oh * 4);
    const uint32_t* in = reinterpret_cast<const uint32_t*>(rgba);
    uint32_t* out = reinterpret_cast<uint32_t*>(transformed_.data());
    concurrency::parallel_for(0, oh, [&](int oy) {
      uint32_t* row = out + static_cast<size_t>(oy) * ow;
      for (int ox = 0; ox < ow; ++ox) {
        const int tx = mirror ? ow - 1 - ox : ox;
        int sx, sy;
        switch (rotation) {
          case 90:
            sx = oy;
            sy = height - 1 - tx;
            break;
          case 180:
            sx = width - 1 - tx;
            sy = height - 1 - oy;
            break;
          case 270:
            sx = width - 1 - oy;
            sy = tx;
            break;
          default:
            sx = tx;
            sy = oy;
            break;
        }
        row[ox] = in[static_cast<size_t>(sy) * width + sx];
      }
    });
    src = transformed_.data();
    w = ow;
    h = oh;
  }

  src = Reframe(src, &w, &h);

  ++frames_;
  {
    std::lock_guard<std::mutex> lock(status_mutex_);
    width_ = w;
    height_ = h;
  }

  vcam_.Push(src, w, h, stream_fps_);

  if (preview_enabled_) {
    back_.assign(src, src + static_cast<size_t>(w) * h * 4);
    {
      std::lock_guard<std::mutex> lock(pixel_mutex_);
      std::swap(front_, back_);
      front_width_ = w;
      front_height_ = h;
    }
    textures_->MarkTextureFrameAvailable(texture_id_);
  }
}

void Receiver::SetAspect(int aspect_w, int aspect_h, bool fill) {
  aspect_w_ = aspect_w > 0 && aspect_h > 0 ? aspect_w : 0;
  aspect_h_ = aspect_w > 0 && aspect_h > 0 ? aspect_h : 0;
  aspect_fill_ = fill;
}

// Fits (black bars) or fills (crops) the frame into the chosen aspect ratio.
// The output keeps the source's short side, so a 1080x1920 portrait frame
// becomes a standard 1920x1080 landscape frame. Bilinear resampling.
const uint8_t* Receiver::Reframe(const uint8_t* src, int* width, int* height) {
  const int aw = aspect_w_;
  const int ah = aspect_h_;
  if (aw <= 0 || ah <= 0) return src;
  const int w = *width;
  const int h = *height;
  const double target = static_cast<double>(aw) / ah;
  if (std::abs(static_cast<double>(w) / h - target) < 0.01) return src;

  const int short_side = std::min(w, h);
  int out_w = target >= 1.0 ? static_cast<int>(short_side * target + 0.5) : short_side;
  int out_h = target >= 1.0 ? short_side : static_cast<int>(short_side / target + 0.5);
  out_w &= ~1;
  out_h &= ~1;

  const double sx_scale = static_cast<double>(out_w) / w;
  const double sy_scale = static_cast<double>(out_h) / h;
  const double scale = aspect_fill_ ? std::max(sx_scale, sy_scale) : std::min(sx_scale, sy_scale);
  const double off_x = (out_w - w * scale) / 2.0;
  const double off_y = (out_h - h * scale) / 2.0;

  reframed_.resize(static_cast<size_t>(out_w) * out_h * 4);
  const uint8_t* in = src;
  uint8_t* out = reframed_.data();
  constexpr uint32_t kBlack = 0xFF000000u;  // RGBA (0,0,0,255) little-endian

  concurrency::parallel_for(0, out_h, [&](int oy) {
    uint32_t* row = reinterpret_cast<uint32_t*>(out) + static_cast<size_t>(oy) * out_w;
    const double sy = (oy + 0.5 - off_y) / scale - 0.5;
    if (sy < -0.5 || sy > h - 0.5) {
      std::fill(row, row + out_w, kBlack);
      return;
    }
    const int y0 = std::clamp(static_cast<int>(std::floor(sy)), 0, h - 1);
    const int y1 = std::min(y0 + 1, h - 1);
    const int fy = std::clamp(static_cast<int>((sy - y0) * 256.0), 0, 256);
    const uint8_t* r0 = in + static_cast<size_t>(y0) * w * 4;
    const uint8_t* r1 = in + static_cast<size_t>(y1) * w * 4;
    uint8_t* dst = reinterpret_cast<uint8_t*>(row);
    for (int ox = 0; ox < out_w; ++ox, dst += 4) {
      const double sx = (ox + 0.5 - off_x) / scale - 0.5;
      if (sx < -0.5 || sx > w - 0.5) {
        *reinterpret_cast<uint32_t*>(dst) = kBlack;
        continue;
      }
      const int x0 = std::clamp(static_cast<int>(std::floor(sx)), 0, w - 1);
      const int x1 = std::min(x0 + 1, w - 1);
      const int fx = std::clamp(static_cast<int>((sx - x0) * 256.0), 0, 256);
      for (int c = 0; c < 4; ++c) {
        const int top = r0[x0 * 4 + c] * (256 - fx) + r0[x1 * 4 + c] * fx;
        const int bottom = r1[x0 * 4 + c] * (256 - fx) + r1[x1 * 4 + c] * fx;
        dst[c] = static_cast<uint8_t>((top * (256 - fy) + bottom * fy) >> 16);
      }
    }
  });

  *width = out_w;
  *height = out_h;
  return out;
}

bool Receiver::SaveSnapshot(const std::wstring& path, std::string* error) {
  std::vector<uint8_t> pixels;
  UINT width = 0, height = 0;
  {
    std::lock_guard<std::mutex> lock(pixel_mutex_);
    if (front_.empty()) {
      *error = "No video frame yet (is the preview on?)";
      return false;
    }
    pixels = front_;
    width = static_cast<UINT>(front_width_);
    height = static_cast<UINT>(front_height_);
  }
  for (size_t i = 0; i + 3 < pixels.size(); i += 4) std::swap(pixels[i], pixels[i + 2]);

  using Microsoft::WRL::ComPtr;
  ComPtr<IWICImagingFactory> factory;
  ComPtr<IWICStream> stream;
  ComPtr<IWICBitmapEncoder> encoder;
  ComPtr<IWICBitmapFrameEncode> frame;
  WICPixelFormatGUID format = GUID_WICPixelFormat32bppBGRA;
  const UINT stride = width * 4;
  bool ok =
      SUCCEEDED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                                 CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory))) &&
      SUCCEEDED(factory->CreateStream(&stream)) &&
      SUCCEEDED(stream->InitializeFromFilename(path.c_str(), GENERIC_WRITE)) &&
      SUCCEEDED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder)) &&
      SUCCEEDED(encoder->Initialize(stream.Get(), WICBitmapEncoderNoCache)) &&
      SUCCEEDED(encoder->CreateNewFrame(&frame, nullptr)) &&
      SUCCEEDED(frame->Initialize(nullptr)) &&
      SUCCEEDED(frame->SetSize(width, height)) &&
      SUCCEEDED(frame->SetPixelFormat(&format)) &&
      IsEqualGUID(format, GUID_WICPixelFormat32bppBGRA) &&
      SUCCEEDED(frame->WritePixels(height, stride, stride * height, pixels.data())) &&
      SUCCEEDED(frame->Commit()) && SUCCEEDED(encoder->Commit());
  if (!ok) *error = "Could not write the PNG file";
  return ok;
}

// Raster thread. The mutex stays locked until Flutter has uploaded the pixels.
const FlutterDesktopPixelBuffer* Receiver::CopyPixelBuffer(size_t, size_t) {
  pixel_mutex_.lock();
  if (front_.empty()) {
    pixel_mutex_.unlock();
    return nullptr;
  }
  pixel_buffer_.buffer = front_.data();
  pixel_buffer_.width = static_cast<size_t>(front_width_);
  pixel_buffer_.height = static_cast<size_t>(front_height_);
  pixel_buffer_.release_context = this;
  pixel_buffer_.release_callback = [](void* context) {
    static_cast<Receiver*>(context)->pixel_mutex_.unlock();
  };
  return &pixel_buffer_;
}

}  // namespace fcam
