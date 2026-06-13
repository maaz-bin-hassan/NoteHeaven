import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class DeepSeekService {
  static const _baseUrl = 'https://api.deepseek.com';
  static const _model = 'deepseek-v4-flash';

  static final DeepSeekService _instance = DeepSeekService._internal();
  factory DeepSeekService() => _instance;
  DeepSeekService._internal();

  String? get _apiKey => dotenv.env['DEEPSEEK_API_KEY'];

  Future<String> chat({
    required String userMessage,
    String? systemMessage,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DEEPSEEK_API_KEY is not set in .env');
    }

    final messages = <Map<String, String>>[];
    if (systemMessage != null && systemMessage.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemMessage});
    }
    messages.add({'role': 'user', 'content': userMessage});

    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': messages,
        'stream': false,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'DeepSeek API error (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('DeepSeek API returned no choices');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content'] as String?;
    if (content == null || content.isEmpty) {
      throw Exception('DeepSeek API returned empty content');
    }

    debugPrint('DeepSeek response received (${content.length} chars)');
    return content;
  }
}
