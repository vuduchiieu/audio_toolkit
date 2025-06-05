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

  /// Khởi tạo kết quả native method.
  NativeMethodResult({
    this.errorMessage,
    this.text,
    required this.result,
    this.path,
  });

  /// Tạo instance từ JSON trả về từ native.
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

  /// Truy cập singleton instance của [AudioToolkit].
  static AudioToolkit get instance => _instance;

  factory AudioToolkit() => _instance;

  AudioToolkit._internal();

  /// Khởi tạo plugin, thiết lập listener và bắt đầu các dịch vụ ghi âm hệ thống.
  Future<void> init() async {
    if (Platform.isMacOS) {
      // Có thể thêm xử lý đặc thù macOS tại đây.
    }
    _channel.setMethodCallHandler(_handleNativeCalls);
    await initRecording();
    await turnOnSystemRecording();
  }

  final StreamController<String> _sentenceDetectedController =
      StreamController.broadcast();

  final StreamController<double> _dbAudiodController =
      StreamController.broadcast();

  /// Stream phát ra các câu đã được nhận dạng (đoạn văn bản).
  Stream<String> get onSentenceDetected => _sentenceDetectedController.stream;

  /// Stream phát ra giá trị mức âm thanh (dB) realtime.
  Stream<double> get onDbAudio => _dbAudiodController.stream;

  /// Gọi phương thức native với tên [methodName] và truyền [arguments].
  ///
  /// Trả về [NativeMethodResult] chứa kết quả gọi native.
  Future<NativeMethodResult> _invokeNativeMethod(String methodName,
      {Map? arguments}) async {
    final nativeResponse = await _channel.invokeMethod(methodName, arguments);
    return NativeMethodResult.fromJson(nativeResponse);
  }

  /// Khởi tạo dịch vụ ghi âm.
  Future<NativeMethodResult> initRecording() =>
      _invokeNativeMethod('initRecording');

  /// Bắt đầu ghi âm.
  Future<NativeMethodResult> startRecord() =>
      _invokeNativeMethod('startRecording');

  /// Dừng ghi âm.
  Future<NativeMethodResult> stopRecording() =>
      _invokeNativeMethod('stopRecording');

  /// Bật ghi âm hệ thống (system audio).
  Future<NativeMethodResult> turnOnSystemRecording() =>
      _invokeNativeMethod('turnOnSystemRecording');

  /// Tắt ghi âm hệ thống.
  Future<NativeMethodResult> turnOffSystemRecording() =>
      _invokeNativeMethod('turnOffSystemRecording');

  /// Bắt đầu ghi âm micro.
  Future<NativeMethodResult> startMicRecording() =>
      _invokeNativeMethod('startMicRecording');

  /// Dừng ghi âm micro.
  Future<NativeMethodResult> stopMicRecording() =>
      _invokeNativeMethod('stopMicRecording');

  /// Khởi tạo dịch vụ chuyển giọng nói thành văn bản.
  ///
  /// **Lưu ý:** Chỉ hoạt động khi build app, không hoạt động khi debug vì lý do quyền nhận diện giọng nói.
  Future<NativeMethodResult> initTranscribeAudio() =>
      _invokeNativeMethod('initTranscribeAudio');

  /// Chuyển file âm thanh tại [path] thành văn bản với ngôn ngữ [language].
  Future<NativeMethodResult> transcribeAudio(
          String path, LanguageType language) =>
      _invokeNativeMethod('transcribeAudio',
          arguments: {"path": path, "language": language.value});

  /// Xử lý các cuộc gọi từ native.
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

  /// Lấy phiên bản nền tảng hiện tại.
  Future<String?> getPlatformVersion() {
    return AudioToolkitPlatform.instance.getPlatformVersion();
  }
}
