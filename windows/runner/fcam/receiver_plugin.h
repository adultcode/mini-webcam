#ifndef RUNNER_FCAM_RECEIVER_PLUGIN_H_
#define RUNNER_FCAM_RECEIVER_PLUGIN_H_

#include <flutter/flutter_engine.h>

namespace fcam {

// Registers the "miniwebcam/receiver" method channel and its preview texture.
void RegisterReceiverPlugin(flutter::FlutterEngine* engine);

}  // namespace fcam

#endif  // RUNNER_FCAM_RECEIVER_PLUGIN_H_
