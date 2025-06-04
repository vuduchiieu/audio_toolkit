#ifndef FLUTTER_PLUGIN_AUDIO_TOOLKIT_PLUGIN_H_
#define FLUTTER_PLUGIN_AUDIO_TOOLKIT_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace audio_toolkit {

class AudioToolkitPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AudioToolkitPlugin();

  virtual ~AudioToolkitPlugin();

  // Disallow copy and assign.
  AudioToolkitPlugin(const AudioToolkitPlugin&) = delete;
  AudioToolkitPlugin& operator=(const AudioToolkitPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace audio_toolkit

#endif  // FLUTTER_PLUGIN_AUDIO_TOOLKIT_PLUGIN_H_
