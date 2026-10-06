// Winsock must come before any header that pulls in windows.h.
#include "fcam/receiver.h"

#include "fcam/receiver_plugin.h"

#include <dshow.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>
#include <vector>

namespace fcam {

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::string Narrow(const std::wstring& wide) {
  if (wide.empty()) return {};
  int size = WideCharToMultiByte(CP_UTF8, 0, wide.c_str(),
                                 static_cast<int>(wide.size()), nullptr, 0,
                                 nullptr, nullptr);
  std::string out(static_cast<size_t>(size), '\0');
  WideCharToMultiByte(CP_UTF8, 0, wide.c_str(), static_cast<int>(wide.size()),
                      out.data(), size, nullptr, nullptr);
  return out;
}

std::wstring Widen(const std::string& utf8) {
  if (utf8.empty()) return {};
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(),
                                 static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring out(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()),
                      out.data(), size);
  return out;
}

// Names of the DirectShow video capture devices other apps can see.
EncodableList ListVideoDevices() {
  EncodableList names;
  Microsoft::WRL::ComPtr<ICreateDevEnum> dev_enum;
  if (FAILED(CoCreateInstance(CLSID_SystemDeviceEnum, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&dev_enum)))) {
    return names;
  }
  Microsoft::WRL::ComPtr<IEnumMoniker> monikers;
  if (dev_enum->CreateClassEnumerator(CLSID_VideoInputDeviceCategory,
                                      &monikers, 0) != S_OK) {
    return names;
  }
  Microsoft::WRL::ComPtr<IMoniker> moniker;
  while (monikers->Next(1, &moniker, nullptr) == S_OK) {
    Microsoft::WRL::ComPtr<IPropertyBag> bag;
    if (SUCCEEDED(moniker->BindToStorage(nullptr, nullptr, IID_PPV_ARGS(&bag)))) {
      VARIANT name;
      VariantInit(&name);
      if (SUCCEEDED(bag->Read(L"FriendlyName", &name, nullptr)) &&
          name.vt == VT_BSTR) {
        names.push_back(EncodableValue(Narrow(name.bstrVal)));
      }
      VariantClear(&name);
    }
    moniker.Reset();
  }
  return names;
}

const EncodableValue* Arg(const EncodableMap* args, const char* key) {
  if (!args) return nullptr;
  auto it = args->find(EncodableValue(key));
  return it == args->end() ? nullptr : &it->second;
}

int IntArg(const EncodableMap* args, const char* key, int fallback) {
  const EncodableValue* v = Arg(args, key);
  if (!v) return fallback;
  if (auto i = std::get_if<int32_t>(v)) return *i;
  if (auto l = std::get_if<int64_t>(v)) return static_cast<int>(*l);
  return fallback;
}

bool BoolArg(const EncodableMap* args, const char* key, bool fallback) {
  const EncodableValue* v = Arg(args, key);
  if (!v) return fallback;
  if (auto b = std::get_if<bool>(v)) return *b;
  return fallback;
}

std::string StringArg(const EncodableMap* args, const char* key) {
  const EncodableValue* v = Arg(args, key);
  if (!v) return {};
  if (auto s = std::get_if<std::string>(v)) return *s;
  return {};
}

class ReceiverPlugin : public flutter::Plugin {
 public:
  explicit ReceiverPlugin(flutter::PluginRegistrarWindows* registrar)
      : receiver_(std::make_unique<Receiver>(registrar->texture_registrar())) {
    channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
        registrar->messenger(), "miniwebcam/receiver",
        &flutter::StandardMethodCodec::GetInstance());
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      Handle(call, std::move(result));
    });
  }

  ~ReceiverPlugin() override { channel_->SetMethodCallHandler(nullptr); }

 private:
  void Handle(const flutter::MethodCall<EncodableValue>& call,
              std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
    const auto* args = std::get_if<EncodableMap>(call.arguments());
    const std::string& method = call.method_name();

    if (method == "textureId") {
      result->Success(EncodableValue(receiver_->texture_id()));
    } else if (method == "connect") {
      const std::string host = StringArg(args, "host");
      if (host.empty()) {
        result->Error("bad_args", "host is required");
        return;
      }
      receiver_->Connect(host, IntArg(args, "port", 8555));
      result->Success();
    } else if (method == "disconnect") {
      receiver_->Disconnect();
      result->Success();
    } else if (method == "status") {
      result->Success(EncodableValue(receiver_->Status()));
    } else if (method == "setTransform") {
      receiver_->SetTransform(IntArg(args, "rotation", 0),
                              BoolArg(args, "mirror", false));
      result->Success();
    } else if (method == "setAspect") {
      receiver_->SetAspect(IntArg(args, "width", 0), IntArg(args, "height", 0),
                           BoolArg(args, "fill", false));
      result->Success();
    } else if (method == "setPreview") {
      receiver_->SetPreviewEnabled(BoolArg(args, "enabled", true));
      result->Success();
    } else if (method == "setVirtualCamera") {
      receiver_->SetVirtualCameraEnabled(BoolArg(args, "enabled", false));
      result->Success();
    } else if (method == "snapshot") {
      const std::string path = StringArg(args, "path");
      std::string error;
      if (path.empty()) {
        result->Error("bad_args", "path is required");
      } else if (receiver_->SaveSnapshot(Widen(path), &error)) {
        result->Success();
      } else {
        result->Error("snapshot_failed", error);
      }
    } else if (method == "listCameras") {
      result->Success(EncodableValue(ListVideoDevices()));
    } else {
      result->NotImplemented();
    }
  }

  std::unique_ptr<Receiver> receiver_;
  std::unique_ptr<flutter::MethodChannel<EncodableValue>> channel_;
};

}  // namespace

void RegisterReceiverPlugin(flutter::FlutterEngine* engine) {
  auto* registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(
              engine->GetRegistrarForPlugin("MiniWebcamReceiverPlugin"));
  registrar->AddPlugin(std::make_unique<ReceiverPlugin>(registrar));
}

}  // namespace fcam
