#ifndef RUNNER_FCAM_BACKGROUND_EFFECT_H_
#define RUNNER_FCAM_BACKGROUND_EFFECT_H_

#include <windows.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace fcam {

class Segmenter;

// Bilinear sampling positions along one axis, from a destination of |dst|
// pixels into a source of |src| pixels. Cached because frame sizes rarely
// change.
struct SampleAxis {
  void Build(int dst_len, int src_len);

  int dst = 0;
  int src = 0;
  std::vector<int> i0;
  std::vector<int> i1;
  std::vector<float> f;
};

// Background blur / replacement for the outgoing video. A person mask comes
// from the MediaPipe selfie segmentation model, run with ONNX Runtime on the
// CPU. onnxruntime.dll is loaded on first use, so the app still starts (with
// the effect unavailable) when the DLL or the models are missing.
//
// Apply() runs on the decoder thread. The setters run on the platform thread.
class BackgroundEffect {
 public:
  enum class Mode { kOff = 0, kBlur = 1, kImage = 2 };

  BackgroundEffect();
  ~BackgroundEffect();

  BackgroundEffect(const BackgroundEffect&) = delete;
  BackgroundEffect& operator=(const BackgroundEffect&) = delete;

  // |strength| is 0..100 and only affects the blur.
  void SetMode(Mode mode, int strength);
  // Loads the replacement image (any format WIC reads). An empty path clears
  // it. Needs COM on the calling thread.
  bool SetImage(const std::wstring& path, std::string* error);

  // Returns |src| untouched when the effect is off or unavailable. Otherwise
  // returns a buffer owned by this object, valid until the next call.
  const uint8_t* Apply(const uint8_t* src, int width, int height);

  Mode mode() const { return mode_; }
  // True when the last frame went through the effect.
  bool active() const { return active_; }
  std::string error();
  // Average milliseconds per processed frame since the previous call.
  double TakeAverageMs();

 private:
  bool EnsureSegmenter();
  void SetError(const std::string& error);
  bool UpdateMask(const uint8_t* src, int width, int height);
  void BuildBlurredBackground(const uint8_t* src, int width, int height);
  bool UpdateScaledImage(int width, int height);

  std::atomic<Mode> mode_{Mode::kOff};
  std::atomic<int> strength_{60};
  std::atomic<bool> active_{false};

  std::mutex error_mutex_;
  std::string error_;

  // Decoder-thread state.
  std::unique_ptr<Segmenter> segmenter_;
  bool segmenter_failed_ = false;
  int model_ = -1;
  std::vector<uint8_t> model_rgba_;  // frame downscaled to the model input
  std::vector<float> input_;         // planar RGB, 0..1
  std::vector<float> raw_;           // model output
  std::vector<float> smoothed_;      // raw output averaged over time
  std::vector<float> alpha_;         // smoothed output with sharpened edges
  int mask_w_ = 0;
  int mask_h_ = 0;

  // Blur: a small, weighted copy of the frame. RGB is premultiplied by the
  // background weight (1 - alpha) so the person does not bleed into the blur.
  std::vector<uint8_t> small_rgba_;
  std::vector<float> small_;
  std::vector<float> small_tmp_;
  int small_w_ = 0;
  int small_h_ = 0;

  SampleAxis mask_x_, mask_y_;
  SampleAxis small_x_, small_y_;
  SampleAxis alpha_small_x_, alpha_small_y_;
  std::vector<uint8_t> out_;

  // Replacement image: loaded on the platform thread, scaled to the frame on
  // the decoder thread whenever the image or the frame size changes.
  std::mutex image_mutex_;
  std::vector<uint8_t> image_;
  int image_w_ = 0;
  int image_h_ = 0;
  uint64_t image_version_ = 0;
  std::vector<uint8_t> image_scaled_;
  int scaled_w_ = 0;
  int scaled_h_ = 0;
  uint64_t scaled_version_ = 0;

  std::atomic<uint64_t> total_us_{0};
  std::atomic<uint64_t> frames_{0};
};

}  // namespace fcam

#endif  // RUNNER_FCAM_BACKGROUND_EFFECT_H_
