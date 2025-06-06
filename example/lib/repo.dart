import 'dart:io';

import 'package:audio_toolkit/language_type.dart';
import 'package:audio_toolkit_example/api/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AudioToolkitRepo {
  final String url = 'https://api.openai.com/v1/audio/transcriptions';

  final apikey = dotenv.env['OPENAI_API_KEY'];

  Future<String?> transcribeWithWhisper(File file) async {
    final res =
        await ApiClient.fetch(url, token: apikey, isFormData: true, data: {
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

  Future<String?> translateWithOpenAI(
      String inputText, LanguageType language) async {
    final url = 'https://api.openai.com/v1/chat/completions';

    final res = await ApiClient.fetch(url, token: apikey, data: {
      "model": "gpt-3.5-turbo",
      "messages": [
        {
          "role": "system",
          "content":
              "You are a translator. Translate all input to ${language.value} without explanation."
        },
        {"role": "user", "content": inputText}
      ],
      "temperature": 0.3
    });

    if (!res.hasError) {
      return res.data["choices"][0]["message"]["content"].toString().trim();
    } else {
      return '🚫 translateWithOpenAI Lỗi rồi ';
    }
  }
}
