import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_toolkit_platform_interface.dart';

/// An implementation of [AudioToolkitPlatform] that uses method channels.
class MethodChannelAudioToolkit extends AudioToolkitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_toolkit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
