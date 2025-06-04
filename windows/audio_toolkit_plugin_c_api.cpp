#include "include/audio_toolkit/audio_toolkit_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "audio_toolkit_plugin.h"

void AudioToolkitPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  audio_toolkit::AudioToolkitPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
