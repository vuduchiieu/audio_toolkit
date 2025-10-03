import 'dart:async';
import 'dart:io';
import 'package:audio_toolkit/language_type.dart';
import 'package:flutter/services.dart';
import 'audio_toolkit_platform_interface.dart';

final MethodChannel _channel = MethodChannel('audio_toolkit');

/// Kết quả trả về từ các phương thức native.
///
/// Chứa thông tin về lỗi (nếu có), văn bản được nhận dạng, đường dẫn file,
/// và trạng thái thành công hay không.
class NativeMethodResult {
  final String? errorMessage;
  final String? text;
  final String? path;
  final bool result;

  NativeMethodResult({
    this.errorMessage,
    this.text,
    required this.result,
    this.path,
  });

  factory NativeMethodResult.fromJson(dynamic json) {
    return NativeMethodResult(
      result: json['result'] == 'true',
      errorMessage: json['errorMessage'],
      text: json['text'],
      path: json['path'],
    );
  }
}

/// Lớp chính cung cấp các API để ghi âm, nhận dạng giọng nói và xử lý audio.
///
/// Sử dụng phương thức native thông qua MethodChannel để tương tác với nền tảng.
class AudioToolkit {
  static final AudioToolkit _instance = AudioToolkit._internal();

  /// Singleton instance của [AudioToolkit]
  static AudioToolkit get instance => _instance;

  /// Khởi tạo instance nội bộ
  factory AudioToolkit() => _instance;

  AudioToolkit._internal();

  final StreamController<String> _onSystemAudioTextController =
      StreamController.broadcast();

  final StreamController<double> _dbAudiodController =
      StreamController.broadcast();

  final StreamController<String> _onMicAudioTextController =
      StreamController.broadcast();

  final StreamController<double> _micDbController =
      StreamController.broadcast();

  /// Stream phát hiện đoạn âm thanh từ hệ thống đã được ghi thành file.
  Stream<String> get onSystemAudio => _onSystemAudioTextController.stream;

  /// Stream đo mức âm lượng (dB) của hệ thống.
  Stream<double> get onDbAudio => _dbAudiodController.stream;

  /// Stream phát ra văn bản được nhận dạng từ mic.
  Stream<String> get onMicAudio => _onMicAudioTextController.stream;

  /// Stream đo mức âm lượng (dB) từ mic.
  Stream<double> get onMicDb => _micDbController.stream;

  /// Khởi tạo toolkit (gọi khi bắt đầu app).
  ///
  /// Thiết lập các luồng và khởi tạo ghi âm hệ thống nếu đang chạy trên macOS.
  Future<void> init() async {
    if (Platform.isMacOS) {
      await initRecording();
      _channel.setMethodCallHandler(_handleNativeCalls);
    }
  }

  /// Gọi method native qua tên và tham số truyền vào.
  Future<NativeMethodResult> _invokeNativeMethod(String methodName,
      {Map? arguments}) async {
    final nativeResponse = await _channel.invokeMethod(methodName, arguments);
    return NativeMethodResult.fromJson(nativeResponse);
  }

  /// Khởi tạo ghi âm hệ thống (yêu cầu quyền).
  Future<NativeMethodResult> initRecording() =>
      _invokeNativeMethod('initRecording');

  /// Bắt đầu ghi âm hệ thống.
  Future<NativeMethodResult> startRecord(LanguageType language) =>
      _invokeNativeMethod('startRecording',
          arguments: {'language': language.value});

  /// Dừng ghi âm và trả về file hệ thống.
  Future<NativeMethodResult> stopRecording() =>
      _invokeNativeMethod('stopRecording');

  /// Bật ghi âm hệ thống (system audio).
  Future<NativeMethodResult> turnOnSystemRecording() =>
      _invokeNativeMethod('turnOnSystemRecording');

  /// Tắt ghi âm hệ thống.
  Future<NativeMethodResult> turnOffSystemRecording() =>
      _invokeNativeMethod('turnOffSystemRecording');

  /// Bật ghi âm từ microphone.
  Future<NativeMethodResult> turnOnMicRecording() =>
      _invokeNativeMethod('turnOnMicRecording');

  /// Tắt ghi âm từ microphone.
  Future<NativeMethodResult> turnOffMicRecording() =>
      _invokeNativeMethod('turnOffMicRecording');

  /// Lắng nghe và xử lý các sự kiện trả về từ native (invokeMethod).
  Future<void> _handleNativeCalls(MethodCall call) async {
    switch (call.method) {
      case 'onSystemText':
        final String path = call.arguments['text'];
        _onSystemAudioTextController.add(path);
        break;
      case 'onMicText':
        _onMicAudioTextController.add(call.arguments['text']);
        break;

      case 'dbMic':
        double? value = double.tryParse(call.arguments.toString());
        if (value != null) {
          _micDbController.add(value);
        }
        break;

      case 'dbSystem':
        final double? value = double.tryParse(call.arguments.toString());
        if (value != null) {
          _dbAudiodController.add(value);
        }
        break;

      default:
        print('⚠️ Method ${call.method} chưa được handle');
    }
  }

  /// Trả về phiên bản hệ điều hành từ native.
  Future<String?> getPlatformVersion() {
    return AudioToolkitPlatform.instance.getPlatformVersion();
  }

  Future<void> dispose() async {
    _onSystemAudioTextController.close();
    _dbAudiodController.close();
    _micDbController.close();

    await Future.wait(
        [stopRecording(), turnOffMicRecording(), turnOffSystemRecording()]);
  }
}
