import 'package:flutter/services.dart';

import 'audio_toolkit_platform_interface.dart';

class MethodChannelAudioToolkit extends AudioToolkitPlatform {
  final methodChannel = const MethodChannel('audio_toolkit');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
