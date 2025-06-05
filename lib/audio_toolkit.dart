import 'dart:async';
import 'dart:io';
import 'package:audio_toolkit/language_type.dart';
import 'package:flutter/services.dart';
import 'audio_toolkit_platform_interface.dart';

final MethodChannel _channel = MethodChannel('audio_toolkit');

class NativeMethodResult {
  final String? errorMessage;
  final String? text;
  final String? path;
  final bool result;

  NativeMethodResult(
      {this.errorMessage, this.text, required this.result, this.path});

  factory NativeMethodResult.fromJson(json) {
    return NativeMethodResult(
        result: json['result'] == 'true',
        errorMessage: json['errorMessage'],
        text: json['text'],
        path: json['path']);
  }
}

class AudioToolkit {
  static final AudioToolkit _instance = AudioToolkit._internal();
  static AudioToolkit get instance => _instance;

  factory AudioToolkit() => _instance;

  AudioToolkit._internal();

  Future<void> init() async {
    if (Platform.isMacOS) {}
    _channel.setMethodCallHandler(_handleNativeCalls);
    await initRecording();
    await turnOnSystemRecording();
  }

  final StreamController<String> _sentenceDetectedController =
      StreamController.broadcast();

  final StreamController<double> _dbAudiodController =
      StreamController.broadcast();

  Stream<String> get onSentenceDetected => _sentenceDetectedController.stream;
  Stream<double> get onDbAudio => _dbAudiodController.stream;

  Future<NativeMethodResult> _invokeNativeMethod(String methodName,
      {Map? arguments}) async {
    final nativeResponse = await _channel.invokeMethod(methodName, arguments);
    return NativeMethodResult.fromJson(nativeResponse);
  }

  Future<NativeMethodResult> initRecording() =>
      _invokeNativeMethod('initRecording');

  Future<NativeMethodResult> startRecord() =>
      _invokeNativeMethod('startRecording');
  Future<NativeMethodResult> stopRecording() =>
      _invokeNativeMethod('stopRecording');

  Future<NativeMethodResult> turnOnSystemRecording() =>
      _invokeNativeMethod('turnOnSystemRecording');
  Future<NativeMethodResult> turnOffSystemRecording() =>
      _invokeNativeMethod('turnOffSystemRecording');

  Future<NativeMethodResult> startMicRecording() =>
      _invokeNativeMethod('startMicRecording');
  Future<NativeMethodResult> stopMicRecording() =>
      _invokeNativeMethod('stopMicRecording');

  Future<NativeMethodResult> transcribeAudio(
          String path, LanguageType language) =>
      _invokeNativeMethod('transcribeAudio',
          arguments: {"path": path, "language": language.value});

  Future<void> _handleNativeCalls(MethodCall call) async {
    switch (call.method) {
      case 'onSentenceDetected':
        final String path = call.arguments['path'];
        _sentenceDetectedController.add(path);
        break;
      case 'db':
        final doubleValue = double.tryParse(call.arguments.toString());
        if (doubleValue != null) {
          _dbAudiodController.add(doubleValue);
        }
        break;
      default:
        print('⚠️ Method ${call.method} chưa được handle');
    }
  }

  Future<String?> getPlatformVersion() {
    return AudioToolkitPlatform.instance.getPlatformVersion();
  }
}
