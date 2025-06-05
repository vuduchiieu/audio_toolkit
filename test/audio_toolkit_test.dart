import 'package:flutter_test/flutter_test.dart';
import 'package:audio_toolkit/audio_toolkit.dart';
import 'package:audio_toolkit/audio_toolkit_platform_interface.dart';
import 'package:audio_toolkit/audio_toolkit_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAudioToolkitPlatform
    with MockPlatformInterfaceMixin
    implements AudioToolkitPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final AudioToolkitPlatform initialPlatform = AudioToolkitPlatform.instance;

  test('$MethodChannelAudioToolkit is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAudioToolkit>());
  });

  test('getPlatformVersion', () async {
    AudioToolkit audioToolkitPlugin = AudioToolkit();
    MockAudioToolkitPlatform fakePlatform = MockAudioToolkitPlatform();
    AudioToolkitPlatform.instance = fakePlatform;

    expect(await audioToolkitPlugin.getPlatformVersion(), '42');
  });
}
