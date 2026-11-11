#include "fcam/background_effect.h"

#include <ppl.h>
#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <chrono>
#include <cmath>

#pragma warning(push, 0)
#include "onnxruntime_c_api.h"
#pragma warning(pop)

namespace fcam {

namespace {

struct ModelInfo {
  const wchar_t* file;
  int width;
  int height;
};

// MediaPipe selfie segmentation: input "pixel_values" [1,3,H,W] RGB in 0..1,
// output "alphas" [1,1,H,W], 1 = person.
constexpr ModelInfo kModels[] = {
    {L"selfie_landscape.onnx", 256, 144},
    {L"selfie_square.onnx", 256, 256},
};
constexpr int kLandscapeModel = 0;
constexpr int kSquareModel = 1;

// Width of the downscaled frame the blur runs on.
constexpr int kSmallWidth = 320;
// Weight of the newest mask in the running average; lower = steadier edges,
// higher = less lag behind fast movement.
constexpr float kTemporalNew = 0.6f;
// Mask values below/above these become fully background/person.
constexpr float kEdgeLow = 0.25f;
constexpr float kEdgeHigh = 0.75f;
// Replacement images are shrunk to this long side when loaded.
constexpr UINT kMaxImageSide = 1920;

std::wstring ExeDir() {
  wchar_t path[MAX_PATH];
  const DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
  std::wstring dir(path, n);
  const size_t slash = dir.find_last_of(L"\\/");
  return slash == std::wstring::npos ? L"." : dir.substr(0, slash);
}

bool FileExists(const std::wstring& path) {
  const DWORD attributes = GetFileAttributesW(path.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES &&
         !(attributes & FILE_ATTRIBUTE_DIRECTORY);
}

std::string Narrow(const std::wstring& wide) {
  if (wide.empty()) return {};
  const int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                       static_cast<int>(wide.size()), nullptr,
                                       0, nullptr, nullptr);
  std::string out(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

// Box-averages an RGBA image into dst_w x dst_h (alpha is set to opaque).
void AreaDownsample(const uint8_t* src, int width, int height, uint8_t* dst,
                    int dst_w, int dst_h) {
  concurrency::parallel_for(0, dst_h, [&](int oy) {
    const int y0 = static_cast<int>(static_cast<int64_t>(oy) * height / dst_h);
    const int y1 = std::max(
        y0 + 1, static_cast<int>(static_cast<int64_t>(oy + 1) * height / dst_h));
    uint8_t* out = dst + static_cast<size_t>(oy) * dst_w * 4;
    for (int ox = 0; ox < dst_w; ++ox, out += 4) {
      const int x0 = static_cast<int>(static_cast<int64_t>(ox) * width / dst_w);
      const int x1 = std::max(
          x0 + 1, static_cast<int>(static_cast<int64_t>(ox + 1) * width / dst_w));
      uint32_t sum[3] = {0, 0, 0};
      for (int y = y0; y < y1; ++y) {
        const uint8_t* p = src + (static_cast<size_t>(y) * width + x0) * 4;
        for (int x = x0; x < x1; ++x, p += 4) {
          sum[0] += p[0];
          sum[1] += p[1];
          sum[2] += p[2];
        }
      }
      const uint32_t count = static_cast<uint32_t>((y1 - y0) * (x1 - x0));
      for (int c = 0; c < 3; ++c) {
        out[c] = static_cast<uint8_t>((sum[c] + count / 2) / count);
      }
      out[3] = 255;
    }
  });
}

// One box blur pass over a 4-channel float image, along rows then columns.
// Three passes approximate a Gaussian. Edges are clamped.
void BoxBlur(float* image, float* scratch, int width, int height, int radius) {
  const float inv = 1.0f / static_cast<float>(2 * radius + 1);
  concurrency::parallel_for(0, height, [&](int y) {
    const float* row = image + static_cast<size_t>(y) * width * 4;
    float* out = scratch + static_cast<size_t>(y) * width * 4;
    float acc[4] = {0, 0, 0, 0};
    for (int k = -radius; k <= radius; ++k) {
      const int x = std::clamp(k, 0, width - 1);
      for (int c = 0; c < 4; ++c) acc[c] += row[x * 4 + c];
    }
    for (int x = 0; x < width; ++x) {
      const int add = std::min(x + radius + 1, width - 1);
      const int remove = std::max(x - radius, 0);
      for (int c = 0; c < 4; ++c) {
        out[x * 4 + c] = acc[c] * inv;
        acc[c] += row[add * 4 + c] - row[remove * 4 + c];
      }
    }
  });
  const size_t stride = static_cast<size_t>(width) * 4;
  concurrency::parallel_for(0, width, [&](int x) {
    const float* col = scratch + static_cast<size_t>(x) * 4;
    float* out = image + static_cast<size_t>(x) * 4;
    float acc[4] = {0, 0, 0, 0};
    for (int k = -radius; k <= radius; ++k) {
      const size_t y = static_cast<size_t>(std::clamp(k, 0, height - 1));
      for (int c = 0; c < 4; ++c) acc[c] += col[y * stride + c];
    }
    for (int y = 0; y < height; ++y) {
      const size_t add = static_cast<size_t>(std::min(y + radius + 1, height - 1));
      const size_t remove = static_cast<size_t>(std::max(y - radius, 0));
      for (int c = 0; c < 4; ++c) {
        out[y * stride + c] = acc[c] * inv;
        acc[c] += col[add * stride + c] - col[remove * stride + c];
      }
    }
  });
}

float Smoothstep(float low, float high, float x) {
  const float t = std::clamp((x - low) / (high - low), 0.0f, 1.0f);
  return t * t * (3.0f - 2.0f * t);
}

}  // namespace

// ---------------------------------------------------------------------------
// Segmenter: ONNX Runtime C API, loaded from the DLL next to the executable.
// The C API is used because the C++ wrapper needs exceptions.
// ---------------------------------------------------------------------------

class Segmenter {
 public:
  static std::unique_ptr<Segmenter> Create(std::string* error) {
    std::unique_ptr<Segmenter> segmenter(new Segmenter());
    if (!segmenter->Init(error)) return nullptr;
    return segmenter;
  }

  ~Segmenter() {
    if (!api_) return;
    for (OrtSession*& session : sessions_) {
      if (session) api_->ReleaseSession(session);
    }
    if (memory_) api_->ReleaseMemoryInfo(memory_);
    if (options_) api_->ReleaseSessionOptions(options_);
    if (env_) api_->ReleaseEnv(env_);
    // The DLL stays loaded: unloading ONNX Runtime at runtime is not safe.
  }

  // Runs |model| on planar RGB |input| and writes the person mask to |output|.
  bool Run(int model, const float* input, float* output, std::string* error) {
    const ModelInfo& info = kModels[model];
    if (!sessions_[model]) {
      const std::wstring path = dir_ + L"\\" + info.file;
      if (!Check(api_->CreateSession(env_, path.c_str(), options_,
                                     &sessions_[model]),
                 error)) {
        return false;
      }
    }

    const size_t pixels = static_cast<size_t>(info.width) * info.height;
    const int64_t in_shape[] = {1, 3, info.height, info.width};
    const int64_t out_shape[] = {1, 1, info.height, info.width};
    OrtValue* in = nullptr;
    OrtValue* out = nullptr;
    bool ok =
        Check(api_->CreateTensorWithDataAsOrtValue(
                  memory_, const_cast<float*>(input), pixels * 3 * sizeof(float),
                  in_shape, 4, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &in),
              error) &&
        Check(api_->CreateTensorWithDataAsOrtValue(
                  memory_, output, pixels * sizeof(float), out_shape, 4,
                  ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &out),
              error);
    if (ok) {
      const char* in_names[] = {"pixel_values"};
      const char* out_names[] = {"alphas"};
      ok = Check(api_->Run(sessions_[model], nullptr, in_names, &in, 1,
                           out_names, 1, &out),
                 error);
    }
    if (in) api_->ReleaseValue(in);
    if (out) api_->ReleaseValue(out);
    return ok;
  }

 private:
  Segmenter() = default;

  bool Init(std::string* error) {
    dir_ = ExeDir();
    const std::wstring dll = dir_ + L"\\onnxruntime.dll";
    if (!FileExists(dll)) {
      *error = "onnxruntime.dll is missing next to the app";
      return false;
    }
    for (const ModelInfo& info : kModels) {
      if (!FileExists(dir_ + L"\\" + info.file)) {
        *error = "Segmentation model missing: " + Narrow(info.file);
        return false;
      }
    }

    // Full path: Windows ships an older onnxruntime.dll in System32.
    module_ = LoadLibraryExW(dll.c_str(), nullptr, LOAD_WITH_ALTERED_SEARCH_PATH);
    if (!module_) {
      *error = "Could not load onnxruntime.dll (error " +
               std::to_string(GetLastError()) + ")";
      return false;
    }
    using GetApiBase = const OrtApiBase*(ORT_API_CALL*)(void);
    const auto get_api_base = reinterpret_cast<GetApiBase>(
        reinterpret_cast<void*>(GetProcAddress(module_, "OrtGetApiBase")));
    const OrtApiBase* base = get_api_base ? get_api_base() : nullptr;
    api_ = base ? base->GetApi(ORT_API_VERSION) : nullptr;
    if (!api_) {
      *error = "onnxruntime.dll is not a supported version";
      return false;
    }

    return Check(api_->CreateEnv(ORT_LOGGING_LEVEL_ERROR, "mini-webcam", &env_),
                 error) &&
           Check(api_->CreateSessionOptions(&options_), error) &&
           // The model is tiny: two threads, and no busy-waiting between runs.
           Check(api_->SetIntraOpNumThreads(options_, 2), error) &&
           Check(api_->SetInterOpNumThreads(options_, 1), error) &&
           Check(api_->AddSessionConfigEntry(
                     options_, "session.intra_op.allow_spinning", "0"),
                 error) &&
           Check(api_->SetSessionGraphOptimizationLevel(options_, ORT_ENABLE_ALL),
                 error) &&
           Check(api_->CreateCpuMemoryInfo(OrtDeviceAllocator, OrtMemTypeDefault,
                                           &memory_),
                 error);
  }

  bool Check(OrtStatus* status, std::string* error) {
    if (!status) return true;
    *error = std::string("ONNX Runtime: ") + api_->GetErrorMessage(status);
    api_->ReleaseStatus(status);
    return false;
  }

  std::wstring dir_;
  HMODULE module_ = nullptr;
  const OrtApi* api_ = nullptr;
  OrtEnv* env_ = nullptr;
  OrtSessionOptions* options_ = nullptr;
  OrtMemoryInfo* memory_ = nullptr;
  OrtSession* sessions_[2] = {nullptr, nullptr};
};

// ---------------------------------------------------------------------------
// SampleAxis
// ---------------------------------------------------------------------------

void SampleAxis::Build(int dst_len, int src_len) {
  if (dst == dst_len && src == src_len) return;
  dst = dst_len;
  src = src_len;
  i0.resize(static_cast<size_t>(dst_len));
  i1.resize(static_cast<size_t>(dst_len));
  f.resize(static_cast<size_t>(dst_len));
  const double scale = static_cast<double>(src_len) / dst_len;
  for (int i = 0; i < dst_len; ++i) {
    const double s = std::clamp((i + 0.5) * scale - 0.5, 0.0,
                                static_cast<double>(src_len - 1));
    const int lo = static_cast<int>(s);
    i0[i] = lo;
    i1[i] = std::min(lo + 1, src_len - 1);
    f[i] = static_cast<float>(s - lo);
  }
}

// ---------------------------------------------------------------------------
// BackgroundEffect
// ---------------------------------------------------------------------------

BackgroundEffect::BackgroundEffect() = default;
BackgroundEffect::~BackgroundEffect() = default;

void BackgroundEffect::SetMode(Mode mode, int strength) {
  strength_ = std::clamp(strength, 0, 100);
  mode_ = mode;
}

bool BackgroundEffect::SetImage(const std::wstring& path, std::string* error) {
  if (path.empty()) {
    std::lock_guard<std::mutex> lock(image_mutex_);
    image_.clear();
    image_w_ = image_h_ = 0;
    ++image_version_;
    return true;
  }

  using Microsoft::WRL::ComPtr;
  ComPtr<IWICImagingFactory> factory;
  ComPtr<IWICBitmapDecoder> decoder;
  ComPtr<IWICBitmapFrameDecode> frame;
  ComPtr<IWICBitmapSource> source;
  ComPtr<IWICFormatConverter> converter;
  UINT width = 0, height = 0;
  if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory))) ||
      FAILED(factory->CreateDecoderFromFilename(
          path.c_str(), nullptr, GENERIC_READ, WICDecodeMetadataCacheOnDemand,
          &decoder)) ||
      FAILED(decoder->GetFrame(0, &frame)) ||
      FAILED(frame->GetSize(&width, &height)) || width == 0 || height == 0) {
    *error = "Could not read the image file";
    return false;
  }
  source = frame;

  const UINT long_side = std::max(width, height);
  if (long_side > kMaxImageSide) {
    ComPtr<IWICBitmapScaler> scaler;
    const double scale = static_cast<double>(kMaxImageSide) / long_side;
    width = std::max(1u, static_cast<UINT>(width * scale + 0.5));
    height = std::max(1u, static_cast<UINT>(height * scale + 0.5));
    if (FAILED(factory->CreateBitmapScaler(&scaler)) ||
        FAILED(scaler->Initialize(source.Get(), width, height,
                                  WICBitmapInterpolationModeFant))) {
      *error = "Could not scale the image";
      return false;
    }
    source = scaler;
  }

  std::vector<uint8_t> pixels(static_cast<size_t>(width) * height * 4);
  if (FAILED(factory->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(source.Get(), GUID_WICPixelFormat32bppRGBA,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom)) ||
      FAILED(converter->CopyPixels(nullptr, width * 4,
                                   static_cast<UINT>(pixels.size()),
                                   pixels.data()))) {
    *error = "Could not decode the image";
    return false;
  }

  std::lock_guard<std::mutex> lock(image_mutex_);
  image_ = std::move(pixels);
  image_w_ = static_cast<int>(width);
  image_h_ = static_cast<int>(height);
  ++image_version_;
  return true;
}

std::string BackgroundEffect::error() {
  std::lock_guard<std::mutex> lock(error_mutex_);
  return error_;
}

void BackgroundEffect::SetError(const std::string& error) {
  std::lock_guard<std::mutex> lock(error_mutex_);
  error_ = error;
}

double BackgroundEffect::TakeAverageMs() {
  const uint64_t frames = frames_.exchange(0);
  const uint64_t total = total_us_.exchange(0);
  return frames > 0 ? static_cast<double>(total) / 1000.0 / frames : 0.0;
}

bool BackgroundEffect::EnsureSegmenter() {
  if (segmenter_) return true;
  if (segmenter_failed_) return false;
  std::string error;
  segmenter_ = Segmenter::Create(&error);
  if (!segmenter_) {
    segmenter_failed_ = true;
    SetError(error);
    return false;
  }
  SetError("");
  return true;
}

bool BackgroundEffect::UpdateMask(const uint8_t* src, int width, int height) {
  // Pick the model whose input shape distorts the frame least.
  const int model = width * 3 >= height * 4 ? kLandscapeModel : kSquareModel;
  const int mw = kModels[model].width;
  const int mh = kModels[model].height;
  const size_t pixels = static_cast<size_t>(mw) * mh;
  if (model != model_) {
    model_ = model;
    smoothed_.clear();  // a different model: restart the running average
  }

  model_rgba_.resize(pixels * 4);
  AreaDownsample(src, width, height, model_rgba_.data(), mw, mh);
  input_.resize(pixels * 3);
  constexpr float kScale = 1.0f / 255.0f;
  for (size_t i = 0; i < pixels; ++i) {
    input_[i] = model_rgba_[i * 4] * kScale;
    input_[pixels + i] = model_rgba_[i * 4 + 1] * kScale;
    input_[2 * pixels + i] = model_rgba_[i * 4 + 2] * kScale;
  }

  raw_.resize(pixels);
  std::string error;
  if (!segmenter_->Run(model, input_.data(), raw_.data(), &error)) {
    // Treat it as permanent so the log is not flooded every frame.
    segmenter_.reset();
    segmenter_failed_ = true;
    SetError(error);
    return false;
  }

  if (smoothed_.size() != pixels) {
    smoothed_ = raw_;
  } else {
    for (size_t i = 0; i < pixels; ++i) {
      smoothed_[i] += (raw_[i] - smoothed_[i]) * kTemporalNew;
    }
  }
  alpha_.resize(pixels);
  for (size_t i = 0; i < pixels; ++i) {
    alpha_[i] = Smoothstep(kEdgeLow, kEdgeHigh, smoothed_[i]);
  }
  mask_w_ = mw;
  mask_h_ = mh;
  return true;
}

void BackgroundEffect::BuildBlurredBackground(const uint8_t* src, int width,
                                              int height) {
  small_w_ = std::min(width, kSmallWidth);
  small_h_ = std::max(1, static_cast<int>(static_cast<int64_t>(height) *
                                          small_w_ / width));
  const size_t pixels = static_cast<size_t>(small_w_) * small_h_;
  small_rgba_.resize(pixels * 4);
  AreaDownsample(src, width, height, small_rgba_.data(), small_w_, small_h_);

  // Weight each pixel by how much background it is.
  alpha_small_x_.Build(small_w_, mask_w_);
  alpha_small_y_.Build(small_h_, mask_h_);
  small_.resize(pixels * 4);
  small_tmp_.resize(pixels * 4);
  for (int y = 0; y < small_h_; ++y) {
    const float* a0 = alpha_.data() + static_cast<size_t>(alpha_small_y_.i0[y]) * mask_w_;
    const float* a1 = alpha_.data() + static_cast<size_t>(alpha_small_y_.i1[y]) * mask_w_;
    const float fy = alpha_small_y_.f[y];
    for (int x = 0; x < small_w_; ++x) {
      const int x0 = alpha_small_x_.i0[x];
      const int x1 = alpha_small_x_.i1[x];
      const float fx = alpha_small_x_.f[x];
      const float top = a0[x0] + (a0[x1] - a0[x0]) * fx;
      const float bottom = a1[x0] + (a1[x1] - a1[x0]) * fx;
      const float weight = 1.0f - (top + (bottom - top) * fy);
      const size_t i = (static_cast<size_t>(y) * small_w_ + x) * 4;
      small_[i] = small_rgba_[i] * weight;
      small_[i + 1] = small_rgba_[i + 1] * weight;
      small_[i + 2] = small_rgba_[i + 2] * weight;
      small_[i + 3] = weight;
    }
  }

  const int radius = 1 + strength_ * 15 / 100;
  for (int pass = 0; pass < 3; ++pass) {
    BoxBlur(small_.data(), small_tmp_.data(), small_w_, small_h_, radius);
  }
}

// Scales the replacement image to cover the frame (cropping the overflow).
bool BackgroundEffect::UpdateScaledImage(int width, int height) {
  std::lock_guard<std::mutex> lock(image_mutex_);
  if (image_.empty()) return false;
  if (scaled_version_ == image_version_ && scaled_w_ == width &&
      scaled_h_ == height) {
    return true;
  }

  const int iw = image_w_;
  const int ih = image_h_;
  const double scale = std::max(static_cast<double>(width) / iw,
                                static_cast<double>(height) / ih);
  const double off_x = (width - iw * scale) / 2.0;
  const double off_y = (height - ih * scale) / 2.0;
  image_scaled_.resize(static_cast<size_t>(width) * height * 4);
  const uint8_t* in = image_.data();
  uint8_t* out = image_scaled_.data();
  concurrency::parallel_for(0, height, [&](int oy) {
    const double sy = std::clamp((oy + 0.5 - off_y) / scale - 0.5, 0.0,
                                 static_cast<double>(ih - 1));
    const int y0 = static_cast<int>(sy);
    const int y1 = std::min(y0 + 1, ih - 1);
    const double fy = sy - y0;
    uint8_t* dst = out + static_cast<size_t>(oy) * width * 4;
    for (int ox = 0; ox < width; ++ox, dst += 4) {
      const double sx = std::clamp((ox + 0.5 - off_x) / scale - 0.5, 0.0,
                                   static_cast<double>(iw - 1));
      const int x0 = static_cast<int>(sx);
      const int x1 = std::min(x0 + 1, iw - 1);
      const double fx = sx - x0;
      const uint8_t* p00 = in + (static_cast<size_t>(y0) * iw + x0) * 4;
      const uint8_t* p01 = in + (static_cast<size_t>(y0) * iw + x1) * 4;
      const uint8_t* p10 = in + (static_cast<size_t>(y1) * iw + x0) * 4;
      const uint8_t* p11 = in + (static_cast<size_t>(y1) * iw + x1) * 4;
      for (int c = 0; c < 3; ++c) {
        const double top = p00[c] + (p01[c] - p00[c]) * fx;
        const double bottom = p10[c] + (p11[c] - p10[c]) * fx;
        dst[c] = static_cast<uint8_t>(top + (bottom - top) * fy + 0.5);
      }
      dst[3] = 255;
    }
  });
  scaled_w_ = width;
  scaled_h_ = height;
  scaled_version_ = image_version_;
  return true;
}

const uint8_t* BackgroundEffect::Apply(const uint8_t* src, int width,
                                       int height) {
  const Mode mode = mode_;
  if (mode == Mode::kOff || width <= 0 || height <= 0) {
    active_ = false;
    return src;
  }
  const auto start = std::chrono::steady_clock::now();

  if (!EnsureSegmenter() || !UpdateMask(src, width, height)) {
    active_ = false;
    return src;
  }
  const bool blur = mode == Mode::kBlur;
  if (blur) {
    BuildBlurredBackground(src, width, height);
    small_x_.Build(width, small_w_);
    small_y_.Build(height, small_h_);
  } else if (!UpdateScaledImage(width, height)) {
    active_ = false;  // no image chosen yet
    return src;
  }

  mask_x_.Build(width, mask_w_);
  mask_y_.Build(height, mask_h_);
  out_.resize(static_cast<size_t>(width) * height * 4);
  const float* alpha = alpha_.data();
  const float* blurred = small_.data();
  const uint8_t* image = image_scaled_.data();
  uint8_t* out = out_.data();
  const int mw = mask_w_;
  const size_t small_stride = static_cast<size_t>(small_w_) * 4;

  concurrency::parallel_for(0, height, [&](int y) {
    const float* a0 = alpha + static_cast<size_t>(mask_y_.i0[y]) * mw;
    const float* a1 = alpha + static_cast<size_t>(mask_y_.i1[y]) * mw;
    const float afy = mask_y_.f[y];
    const float* s0 = blur ? blurred + small_y_.i0[y] * small_stride : nullptr;
    const float* s1 = blur ? blurred + small_y_.i1[y] * small_stride : nullptr;
    const float sfy = blur ? small_y_.f[y] : 0.0f;
    const size_t row = static_cast<size_t>(y) * width * 4;
    const uint8_t* fg = src + row;
    const uint8_t* bg_image = image + row;
    uint8_t* dst = out + row;

    for (int x = 0; x < width; ++x, fg += 4, dst += 4) {
      const int mx0 = mask_x_.i0[x];
      const int mx1 = mask_x_.i1[x];
      const float mfx = mask_x_.f[x];
      const float top = a0[mx0] + (a0[mx1] - a0[mx0]) * mfx;
      const float bottom = a1[mx0] + (a1[mx1] - a1[mx0]) * mfx;
      const float a = top + (bottom - top) * afy;
      if (a >= 0.999f) {
        *reinterpret_cast<uint32_t*>(dst) = *reinterpret_cast<const uint32_t*>(fg);
        continue;
      }

      float bg[3];
      if (blur) {
        const size_t sx0 = static_cast<size_t>(small_x_.i0[x]) * 4;
        const size_t sx1 = static_cast<size_t>(small_x_.i1[x]) * 4;
        const float sfx = small_x_.f[x];
        float v[4];
        for (int c = 0; c < 4; ++c) {
          const float t = s0[sx0 + c] + (s0[sx1 + c] - s0[sx0 + c]) * sfx;
          const float b = s1[sx0 + c] + (s1[sx1 + c] - s1[sx0 + c]) * sfx;
          v[c] = t + (b - t) * sfy;
        }
        if (v[3] > 1e-3f) {
          const float inv = 1.0f / v[3];
          bg[0] = v[0] * inv;
          bg[1] = v[1] * inv;
          bg[2] = v[2] * inv;
        } else {
          // Surrounded by person: no background to borrow from.
          bg[0] = fg[0];
          bg[1] = fg[1];
          bg[2] = fg[2];
        }
      } else {
        const uint8_t* p = bg_image + static_cast<size_t>(x) * 4;
        bg[0] = p[0];
        bg[1] = p[1];
        bg[2] = p[2];
      }

      for (int c = 0; c < 3; ++c) {
        const float value = bg[c] + (fg[c] - bg[c]) * a;
        dst[c] = static_cast<uint8_t>(std::clamp(value + 0.5f, 0.0f, 255.0f));
      }
      dst[3] = 255;
    }
  });

  total_us_ += static_cast<uint64_t>(
      std::chrono::duration_cast<std::chrono::microseconds>(
          std::chrono::steady_clock::now() - start)
          .count());
  ++frames_;
  active_ = true;
  return out_.data();
}

}  // namespace fcam
