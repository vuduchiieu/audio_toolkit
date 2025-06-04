import 'package:audio_toolkit/audio_toolkit.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'System Audio Recorder Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const RecorderHomePage(),
    );
  }
}

class RecorderHomePage extends StatefulWidget {
  const RecorderHomePage({Key? key}) : super(key: key);

  @override
  State<RecorderHomePage> createState() => _RecorderHomePageState();
}

class _RecorderHomePageState extends State<RecorderHomePage> {
  final recorder = AudioToolkit.instance;

  String lastTranscription = 'Chưa có kết quả';
  double currentDb = 0;
  String lastDetectedSentencePath = '';

  @override
  void initState() {
    super.initState();

    // Lắng nghe sự kiện từ native gửi về
    recorder.onDbAudio.listen((dbValue) {
      setState(() {
        currentDb = dbValue;
      });
    });

    recorder.onSentenceDetected.listen((path) {
      setState(() {
        lastDetectedSentencePath = path;
      });
    });

    recorder.onTranscript.listen((transcriptData) {
      setState(() {
        lastTranscription = transcriptData.toString();
      });
    });

    // Khởi tạo recording
    recorder.initRecording();
  }

  Future<void> startRecording() async {
    final res = await recorder.startSystemRecording();
    print('Start recording response: ${res.result}');
  }

  Future<void> stopRecording() async {
    final res = await recorder.stopSystemRecording();
    print('Stop recording response: $res');
  }

  Future<void> voiceToText(String path) async {
    try {
      // Gọi native để chuyển giọng nói thành text
      // final transcription =
      //     await recorder._invokeNativeMethod('voiceToText', arguments: {
      //   'path': path,
      //   'language': 'vi-VN',
      // });
      // print('Voice to text result: $transcription');
      // setState(() {
      //   lastTranscription = transcription.toString();
      // });
    } catch (e) {
      print('Voice to text failed: $e');
      setState(() {
        lastTranscription = 'Lỗi khi chuyển voice sang text';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Audio Recorder Demo')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('DB audio hiện tại: $currentDb'),
            const SizedBox(height: 10),
            Text('Đường dẫn câu vừa phát hiện: $lastDetectedSentencePath'),
            const SizedBox(height: 10),
            Text('Phiên âm cuối cùng: $lastTranscription'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: startRecording,
              child: const Text('Bắt đầu ghi âm hệ thống'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: stopRecording,
              child: const Text('Dừng ghi âm hệ thống'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (lastDetectedSentencePath.isNotEmpty) {
                  voiceToText(lastDetectedSentencePath);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Chưa có file audio để chuyển thành text')),
                  );
                }
              },
              child: const Text('Chuyển câu vừa ghi âm sang text'),
            ),
          ],
        ),
      ),
    );
  }
}
