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
      "model": "gpt-4o",
      "messages": [
        {
          "role": "system",
          "content":
              " Translate the text sent by the user into $language following these rules:"
                  "\n1. Do not translate proper nouns."
                  "\n2. Preserve whitespace."
                  "\n3. Ensure the use of the most accurate words."
                  "\n4. Return only the translated text, nothing else."
                  "\n5. Keep emojis and emoticons unchanged."
                  "\n6. Do not return the text before translation."
                  "\n7. If the input language and the language to be translated are the same, return the original text."
        },
        {"role": "user", "content": inputText}
      ],
      "temperature": 0.7
    });

    if (!res.hasError) {
      return res.data["choices"][0]["message"]["content"].toString().trim();
    } else {
      return '🚫 translateWithOpenAI Lỗi rồi ${res.errorMessage}';
    }
  }
}
