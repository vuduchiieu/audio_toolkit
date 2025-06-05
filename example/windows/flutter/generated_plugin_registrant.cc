//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <audio_toolkit/audio_toolkit_plugin_c_api.h>
#include <dynamic_color/dynamic_color_plugin_c_api.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  AudioToolkitPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("AudioToolkitPluginCApi"));
  DynamicColorPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DynamicColorPluginCApi"));
}
