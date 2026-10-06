#include "fcam/decoders.h"

#include <codecapi.h>
#include <mfapi.h>
#include <mferror.h>
#include <ppl.h>
#include <wmcodecdsp.h>

#include <algorithm>
#include <cstring>

using Microsoft::WRL::ComPtr;

namespace fcam {

int FirstNalType(const uint8_t* data, size_t size) {
  for (size_t i = 0; i + 3 < size; ++i) {
    if (data[i] == 0 && data[i + 1] == 0) {
      if (data[i + 2] == 1) return data[i + 3] & 0x1f;
      if (data[i + 2] == 0 && i + 4 < size && data[i + 3] == 1) {
        return data[i + 4] & 0x1f;
      }
    }
  }
  return -1;
}

namespace {

inline uint8_t Clamp(int v) {
  return static_cast<uint8_t>(v < 0 ? 0 : (v > 255 ? 255 : v));
}

}  // namespace

// ---------------------------------------------------------------------------
// H264Decoder
// ---------------------------------------------------------------------------

H264Decoder::H264Decoder(int width_hint, int height_hint, int fps_hint)
    : width_hint_(width_hint), height_hint_(height_hint), fps_hint_(fps_hint) {}

H264Decoder::~H264Decoder() {
  if (mft_) {
    mft_->ProcessMessage(MFT_MESSAGE_NOTIFY_END_OF_STREAM, 0);
    mft_->ProcessMessage(MFT_MESSAGE_COMMAND_FLUSH, 0);
  }
}

bool H264Decoder::Init() {
  HRESULT hr = CoCreateInstance(CLSID_CMSH264DecoderMFT, nullptr,
                                CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&mft_));
  if (FAILED(hr)) return false;

  ComPtr<IMFAttributes> attributes;
  if (SUCCEEDED(mft_->GetAttributes(&attributes))) {
    attributes->SetUINT32(CODECAPI_AVLowLatencyMode, TRUE);
  }

  ComPtr<IMFMediaType> input;
  MFCreateMediaType(&input);
  input->SetGUID(MF_MT_MAJOR_TYPE, MFMediaType_Video);
  input->SetGUID(MF_MT_SUBTYPE, MFVideoFormat_H264);
  input->SetUINT32(MF_MT_INTERLACE_MODE, MFVideoInterlace_Progressive);
  if (width_hint_ > 0 && height_hint_ > 0) {
    MFSetAttributeSize(input.Get(), MF_MT_FRAME_SIZE, width_hint_, height_hint_);
  }
  if (fps_hint_ > 0) {
    MFSetAttributeRatio(input.Get(), MF_MT_FRAME_RATE, fps_hint_, 1);
  }
  hr = mft_->SetInputType(0, input.Get(), 0);
  if (FAILED(hr)) {
    mft_.Reset();
    return false;
  }

  // May fail until the first SPS is parsed; the stream-change path retries.
  ConfigureOutput();

  mft_->ProcessMessage(MFT_MESSAGE_NOTIFY_BEGIN_STREAMING, 0);
  mft_->ProcessMessage(MFT_MESSAGE_NOTIFY_START_OF_STREAM, 0);
  return true;
}

bool H264Decoder::ConfigureOutput() {
  for (DWORD i = 0;; ++i) {
    ComPtr<IMFMediaType> type;
    if (FAILED(mft_->GetOutputAvailableType(0, i, &type))) return false;
    GUID subtype{};
    type->GetGUID(MF_MT_SUBTYPE, &subtype);
    if (subtype == MFVideoFormat_NV12) {
      if (FAILED(mft_->SetOutputType(0, type.Get(), 0))) return false;
      break;
    }
  }

  ComPtr<IMFMediaType> current;
  if (FAILED(mft_->GetOutputCurrentType(0, &current))) return false;

  MFGetAttributeSize(current.Get(), MF_MT_FRAME_SIZE, &alloc_width_,
                     &alloc_height_);

  MFVideoArea area{};
  UINT32 blob_size = 0;
  if (SUCCEEDED(current->GetBlob(MF_MT_MINIMUM_DISPLAY_APERTURE,
                                 reinterpret_cast<UINT8*>(&area), sizeof(area),
                                 &blob_size)) &&
      area.Area.cx > 0 && area.Area.cy > 0) {
    crop_x_ = area.OffsetX.value;
    crop_y_ = area.OffsetY.value;
    display_width_ = area.Area.cx;
    display_height_ = area.Area.cy;
  } else {
    crop_x_ = 0;
    crop_y_ = 0;
    display_width_ = static_cast<int>(alloc_width_);
    display_height_ = static_cast<int>(alloc_height_);
  }

  UINT32 stride = 0;
  if (SUCCEEDED(current->GetUINT32(MF_MT_DEFAULT_STRIDE, &stride))) {
    stride_ = static_cast<int>(stride);
  } else {
    stride_ = static_cast<int>(alloc_width_);
  }

  UINT32 matrix = 0;
  if (SUCCEEDED(current->GetUINT32(MF_MT_YUV_MATRIX, &matrix)) &&
      matrix == MFVideoTransferMatrix_BT709) {
    matrix_ = YuvMatrix::kBt709;
  } else {
    matrix_ = YuvMatrix::kBt601;
  }

  out_sample_.Reset();
  return true;
}

bool H264Decoder::Decode(const uint8_t* data, size_t size, int64_t pts_us,
                         const FrameCallback& callback) {
  if (!mft_) {
    if (init_failed_ || !Init()) {
      init_failed_ = true;
      return false;
    }
  }

  ComPtr<IMFMediaBuffer> buffer;
  if (FAILED(MFCreateMemoryBuffer(static_cast<DWORD>(size), &buffer))) {
    return false;
  }
  BYTE* dst = nullptr;
  if (FAILED(buffer->Lock(&dst, nullptr, nullptr))) return false;
  memcpy(dst, data, size);
  buffer->Unlock();
  buffer->SetCurrentLength(static_cast<DWORD>(size));

  ComPtr<IMFSample> sample;
  MFCreateSample(&sample);
  sample->AddBuffer(buffer.Get());
  sample->SetSampleTime(pts_us * 10);

  HRESULT hr = mft_->ProcessInput(0, sample.Get(), 0);
  if (hr == MF_E_NOTACCEPTING) {
    Drain(callback);
    hr = mft_->ProcessInput(0, sample.Get(), 0);
  }
  if (FAILED(hr)) return false;
  Drain(callback);
  return true;
}

void H264Decoder::Drain(const FrameCallback& callback) {
  for (int guard = 0; guard < 16; ++guard) {
    if (!out_sample_) {
      MFT_OUTPUT_STREAM_INFO info{};
      if (FAILED(mft_->GetOutputStreamInfo(0, &info))) return;
      if (!(info.dwFlags & (MFT_OUTPUT_STREAM_PROVIDES_SAMPLES |
                            MFT_OUTPUT_STREAM_CAN_PROVIDE_SAMPLES))) {
        ComPtr<IMFMediaBuffer> buffer;
        DWORD size = info.cbSize > 0 ? info.cbSize
                                     : alloc_width_ * alloc_height_ * 3 / 2;
        if (size == 0 || FAILED(MFCreateMemoryBuffer(size, &buffer))) return;
        MFCreateSample(&out_sample_);
        out_sample_->AddBuffer(buffer.Get());
      }
    }

    MFT_OUTPUT_DATA_BUFFER output{};
    output.dwStreamID = 0;
    output.pSample = out_sample_.Get();
    DWORD status = 0;
    HRESULT hr = mft_->ProcessOutput(0, 1, &output, &status);
    if (output.pEvents) output.pEvents->Release();
    if (hr == MF_E_TRANSFORM_NEED_MORE_INPUT) return;
    if (hr == MF_E_TRANSFORM_STREAM_CHANGE) {
      if (!ConfigureOutput()) return;
      continue;
    }
    if (FAILED(hr)) return;

    if (!out_sample_ && output.pSample) {
      // Decoder-provided sample.
      ComPtr<IMFSample> provided;
      provided.Attach(output.pSample);
      out_sample_ = provided;
      Emit(callback);
      out_sample_.Reset();
    } else {
      Emit(callback);
      // The MS decoder fails (E_FAIL) when handed back the same sample, so a
      // fresh one is allocated for the next picture.
      out_sample_.Reset();
    }
  }
}

void H264Decoder::Emit(const FrameCallback& callback) {
  ComPtr<IMFMediaBuffer> buffer;
  if (FAILED(out_sample_->GetBufferByIndex(0, &buffer))) return;

  BYTE* base = nullptr;
  LONG pitch = 0;
  ComPtr<IMF2DBuffer> buffer2d;
  bool locked2d = false;
  if (SUCCEEDED(buffer.As(&buffer2d)) &&
      SUCCEEDED(buffer2d->Lock2D(&base, &pitch))) {
    locked2d = true;
    if (pitch <= 0) {
      buffer2d->Unlock2D();
      locked2d = false;
    }
  }
  if (!locked2d) {
    if (FAILED(buffer->Lock(&base, nullptr, nullptr))) return;
    pitch = stride_ > 0 ? stride_ : static_cast<LONG>(alloc_width_);
  }

  Nv12View view{};
  view.pitch = static_cast<int>(pitch);
  view.y = base + crop_y_ * pitch + crop_x_;
  view.uv = base + pitch * static_cast<LONG>(alloc_height_) +
            (crop_y_ / 2) * pitch + crop_x_;
  view.width = display_width_ & ~1;
  view.height = display_height_ & ~1;
  view.matrix = matrix_;
  if (view.width > 0 && view.height > 0) callback(view);

  if (locked2d) {
    buffer2d->Unlock2D();
  } else {
    buffer->Unlock();
  }
}

// ---------------------------------------------------------------------------
// JpegDecoder
// ---------------------------------------------------------------------------

bool JpegDecoder::Decode(const uint8_t* data, size_t size,
                         std::vector<uint8_t>* rgba, int* width, int* height) {
  if (!factory_ &&
      FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory_)))) {
    return false;
  }
  ComPtr<IWICStream> stream;
  if (FAILED(factory_->CreateStream(&stream)) ||
      FAILED(stream->InitializeFromMemory(const_cast<BYTE*>(data),
                                          static_cast<DWORD>(size)))) {
    return false;
  }
  ComPtr<IWICBitmapDecoder> decoder;
  if (FAILED(factory_->CreateDecoderFromStream(
          stream.Get(), nullptr, WICDecodeMetadataCacheOnDemand, &decoder))) {
    return false;
  }
  ComPtr<IWICBitmapFrameDecode> frame;
  if (FAILED(decoder->GetFrame(0, &frame))) return false;

  ComPtr<IWICFormatConverter> converter;
  if (FAILED(factory_->CreateFormatConverter(&converter)) ||
      FAILED(converter->Initialize(frame.Get(), GUID_WICPixelFormat32bppRGBA,
                                   WICBitmapDitherTypeNone, nullptr, 0.0,
                                   WICBitmapPaletteTypeCustom))) {
    return false;
  }
  UINT w = 0, h = 0;
  converter->GetSize(&w, &h);
  if (w == 0 || h == 0) return false;
  rgba->resize(static_cast<size_t>(w) * h * 4);
  if (FAILED(converter->CopyPixels(nullptr, w * 4,
                                   static_cast<UINT>(rgba->size()),
                                   rgba->data()))) {
    return false;
  }
  *width = static_cast<int>(w);
  *height = static_cast<int>(h);
  return true;
}

// ---------------------------------------------------------------------------
// Color conversion
// ---------------------------------------------------------------------------

void Nv12ToRgba(const Nv12View& src, uint8_t* dst) {
  // Fixed-point (x256) limited-range coefficients.
  const bool bt709 = src.matrix == YuvMatrix::kBt709;
  const int rv = bt709 ? 459 : 409;
  const int gu = bt709 ? 55 : 100;
  const int gv = bt709 ? 136 : 208;
  const int bu = bt709 ? 541 : 516;

  const int pair_rows = src.height / 2;
  concurrency::parallel_for(0, pair_rows, [&](int pair) {
    const uint8_t* uv_row = src.uv + static_cast<size_t>(pair) * src.pitch;
    for (int sub = 0; sub < 2; ++sub) {
      const int row = pair * 2 + sub;
      const uint8_t* y_row = src.y + static_cast<size_t>(row) * src.pitch;
      uint8_t* out = dst + static_cast<size_t>(row) * src.width * 4;
      for (int x = 0; x < src.width; x += 2) {
        const int d = uv_row[x] - 128;
        const int e = uv_row[x + 1] - 128;
        const int r_add = rv * e + 128;
        const int g_add = -gu * d - gv * e + 128;
        const int b_add = bu * d + 128;
        for (int k = 0; k < 2; ++k) {
          const int c = 298 * (y_row[x + k] - 16);
          out[0] = Clamp((c + r_add) >> 8);
          out[1] = Clamp((c + g_add) >> 8);
          out[2] = Clamp((c + b_add) >> 8);
          out[3] = 255;
          out += 4;
        }
      }
    }
  });
}

}  // namespace fcam
