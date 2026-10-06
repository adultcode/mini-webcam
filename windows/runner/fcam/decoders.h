#ifndef RUNNER_FCAM_DECODERS_H_
#define RUNNER_FCAM_DECODERS_H_

#include <windows.h>
#include <mfidl.h>
#include <mftransform.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <cstdint>
#include <functional>
#include <vector>

namespace fcam {

enum class YuvMatrix { kBt601, kBt709 };

// A decoded NV12 picture. Planes point into decoder-owned memory and are only
// valid for the duration of the callback.
struct Nv12View {
  const uint8_t* y;
  const uint8_t* uv;
  int pitch;
  int width;
  int height;
  YuvMatrix matrix;
};

// H.264 Annex-B -> NV12 using the Media Foundation H.264 decoder MFT that ships
// with Windows (no FFmpeg dependency). Low-latency mode is enabled so every
// input access unit produces an output picture immediately.
// Must be used from a thread with COM (MTA) and MFStartup initialized.
class H264Decoder {
 public:
  using FrameCallback = std::function<void(const Nv12View&)>;

  H264Decoder(int width_hint, int height_hint, int fps_hint);
  ~H264Decoder();

  H264Decoder(const H264Decoder&) = delete;
  H264Decoder& operator=(const H264Decoder&) = delete;

  // Feeds one access unit. Invokes |callback| for every picture produced.
  bool Decode(const uint8_t* data, size_t size, int64_t pts_us,
              const FrameCallback& callback);

 private:
  bool Init();
  bool ConfigureOutput();
  void Drain(const FrameCallback& callback);
  void Emit(const FrameCallback& callback);

  Microsoft::WRL::ComPtr<IMFTransform> mft_;
  Microsoft::WRL::ComPtr<IMFSample> out_sample_;
  bool init_failed_ = false;
  int width_hint_;
  int height_hint_;
  int fps_hint_;
  UINT32 alloc_width_ = 0;
  UINT32 alloc_height_ = 0;
  int crop_x_ = 0;
  int crop_y_ = 0;
  int display_width_ = 0;
  int display_height_ = 0;
  int stride_ = 0;
  YuvMatrix matrix_ = YuvMatrix::kBt601;
};

// JPEG -> RGBA using WIC. Must be used from a thread with COM initialized.
class JpegDecoder {
 public:
  bool Decode(const uint8_t* data, size_t size, std::vector<uint8_t>* rgba,
              int* width, int* height);

 private:
  Microsoft::WRL::ComPtr<IWICImagingFactory> factory_;
};

// NAL unit type (5 = IDR, 7 = SPS) of the first Annex-B unit, or -1.
int FirstNalType(const uint8_t* data, size_t size);

// NV12 -> RGBA (limited range), parallelized over rows.
void Nv12ToRgba(const Nv12View& src, uint8_t* dst);

}  // namespace fcam

#endif  // RUNNER_FCAM_DECODERS_H_
