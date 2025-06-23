import 'dart:io';

import 'package:audio_toolkit/language_type.dart';
import 'package:audio_toolkit_example/api/api_client.dart';
import 'package:audio_toolkit_example/api/request_response.dart';
import 'package:dio/dio.dart';

class AudioToolkitRepo {
  final String url = 'https://api.openai.com/v1/audio/transcriptions';

  // final apikey = dotenv.env['OPENAI_API_KEY'];

  Future<String?> transcribeWithWhisper(File file) async {
    final res =
        await ApiClient.fetch(url, token: 'apikey', isFormData: true, data: {
      'file': await MultipartFile.fromFile(file.path,
          filename: file.uri.pathSegments.last),
      'model': 'whisper-1',
    });

    if (!res.hasError) {
      return res.data['text'];
    } else {
      print('object: ${res.errorMessage}');
      return null;
    }
  }

  Future<RequestResponse> translate(String inputText, LanguageType language) =>
      ApiClient.fetch('https://translatewithopenai-xutti5w4oa-uc.a.run.app',
          data: {"inputText": inputText, "language": language.shortCode});
}
