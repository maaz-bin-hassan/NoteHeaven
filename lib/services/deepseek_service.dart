import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thin OpenAI-compatible client for DeepSeek chat completions.
///
/// The feature degrades gracefully: when no API key is configured,
/// [isConfigured] is false and the UI hides/disables the AI affordances rather
/// than throwing.
///
/// SECURITY NOTE: bundling the API key in the app's assets means anyone can
/// extract it from the distributed APK/AAB. For a real production release the
/// key should live behind a backend proxy you control, with the app calling
/// that proxy instead of DeepSeek directly.
class DeepSeekService {
  static const _baseUrl = 'https://api.deepseek.com';
  static const _defaultModel = 'deepseek-chat';
  static const _timeout = Duration(seconds: 30);

  static final DeepSeekService _instance = DeepSeekService._internal();
  factory DeepSeekService() => _instance;
  DeepSeekService._internal();

  String? get _apiKey {
    if (!dotenv.isInitialized) return null;
    final key = dotenv.env['DEEPSEEK_API_KEY'];
    if (key == null) return null;
    final trimmed = key.trim();
    if (trimmed.isEmpty || trimmed == 'your_deepseek_api_key_here') return null;
    return trimmed;
  }

  String get _model {
    final m = dotenv.isInitialized ? dotenv.env['DEEPSEEK_MODEL']?.trim() : null;
    return (m == null || m.isEmpty) ? _defaultModel : m;
  }

  bool get isConfigured => _apiKey != null;

  Future<String> chat({
    required String userMessage,
    String? systemMessage,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null) {
      throw const AiUnconfiguredException();
    }

    final messages = <Map<String, String>>[
      if (systemMessage != null && systemMessage.isNotEmpty)
        {'role': 'system', 'content': systemMessage},
      {'role': 'user', 'content': userMessage},
    ];

    late final http.Response response;
    try {
      response = await http
          .post(
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
          )
          .timeout(_timeout);
    } catch (e) {
      throw Exception('Could not reach the AI service. Check your connection.');
    }

    if (response.statusCode == 401) {
      throw Exception('AI request rejected: invalid API key.');
    }
    if (response.statusCode != 200) {
      throw Exception('AI service error (${response.statusCode}).');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    String? content;
    if (choices != null && choices.isNotEmpty) {
      final message = choices.first['message'];
      if (message is Map) content = message['content'] as String?;
    }
    if (content == null || content.trim().isEmpty) {
      throw Exception('The AI returned an empty response.');
    }

    debugPrint('DeepSeek response received (${content.length} chars)');
    return content.trim();
  }
}

class AiUnconfiguredException implements Exception {
  const AiUnconfiguredException();
  @override
  String toString() =>
      'AI is not configured. Add a DEEPSEEK_API_KEY to enable it.';
}
