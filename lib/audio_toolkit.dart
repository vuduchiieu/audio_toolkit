import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'audio_toolkit_platform_interface.dart';

final MethodChannel _channel = MethodChannel('audio_toolkit');

class NativeMethodResult {
  final String? errorMessage;
  final bool result;

  NativeMethodResult({this.errorMessage, required this.result});

  factory NativeMethodResult.fromJson(json) {
    return NativeMethodResult(
        result: json['result'] == 'true', errorMessage: json['errorMessage']);
  }
}

class AudioToolkit {
  static AudioToolkit get instance => _getInstance();
  static AudioToolkit? _instance;
  static AudioToolkit _getInstance() {
    _instance ??= AudioToolkit._internal();
    return _instance!;
  }

  factory AudioToolkit() => _getInstance();

  AudioToolkit._internal() {
    if (Platform.isMacOS) {
      _channel.setMethodCallHandler(_handleNativeCalls);
      initRecording();
      return;
    }
  }

  final StreamController<String> _sentenceDetectedController =
      StreamController.broadcast();

  final StreamController<double> _dbAudiodController =
      StreamController.broadcast();

  final StreamController<Map> _transcriptController =
      StreamController.broadcast();

  Stream<String> get onSentenceDetected => _sentenceDetectedController.stream;
  Stream<double> get onDbAudio => _dbAudiodController.stream;
  Stream<Map> get onTranscript => _transcriptController.stream;

  Future<NativeMethodResult> _invokeNativeMethod(String methodName,
      {Map? arguments}) async {
    final nativeResponse = await _channel.invokeMethod(methodName, arguments);
    return NativeMethodResult.fromJson(nativeResponse);
  }

  Future<NativeMethodResult> initRecording() =>
      _invokeNativeMethod('initRecording');
  Future<NativeMethodResult> startSystemRecording() =>
      _invokeNativeMethod('startSystemRecording', arguments: {
        "language": '',
      });
  Future<NativeMethodResult> stopSystemRecording() =>
      _invokeNativeMethod('stopSystemRecording');

  Future<NativeMethodResult> startMicRecording() =>
      _invokeNativeMethod('startMicRecording');
  Future<NativeMethodResult> stopMicRecording() =>
      _invokeNativeMethod('stopMicRecording');

  Future<void> _handleNativeCalls(MethodCall call) async {
    switch (call.method) {
      case 'onTranscript':
        _transcriptController.add(call.arguments);
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
