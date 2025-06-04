import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_toolkit_method_channel.dart';

abstract class AudioToolkitPlatform extends PlatformInterface {
  /// Constructs a AudioToolkitPlatform.
  AudioToolkitPlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioToolkitPlatform _instance = MethodChannelAudioToolkit();

  /// The default instance of [AudioToolkitPlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioToolkit].
  static AudioToolkitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioToolkitPlatform] when
  /// they register themselves.
  static set instance(AudioToolkitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
