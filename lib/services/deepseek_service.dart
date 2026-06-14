import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Client for the NoteHeaven AI backend proxy.
///
/// The app NEVER holds the DeepSeek API key. It talks only to our own proxy
/// (`AI_PROXY_URL`, see ./server), authenticating with a low-sensitivity app
/// key (`AI_APP_KEY`). The proxy forwards the request to DeepSeek using the
/// real secret, which lives only on the server.
///
/// The feature degrades gracefully: when no proxy URL is configured,
/// [isConfigured] is false and the UI hides/disables the AI affordances rather
/// than throwing.
class DeepSeekService {
  static const _chatPath = '/v1/ai/chat';
  static const _timeout = Duration(seconds: 30);

  static final DeepSeekService _instance = DeepSeekService._internal();
  factory DeepSeekService() => _instance;
  DeepSeekService._internal();

  /// Proxy base URL, trailing slash stripped. Null when unset/blank.
  String? get _baseUrl {
    if (!dotenv.isInitialized) return null;
    final url = dotenv.env['AI_PROXY_URL']?.trim();
    if (url == null || url.isEmpty) return null;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Shared client key sent as `x-app-key`. Optional (the proxy may run open in
  /// local dev), so a null/blank value simply omits the header.
  String? get _appKey {
    if (!dotenv.isInitialized) return null;
    final key = dotenv.env['AI_APP_KEY']?.trim();
    return (key == null || key.isEmpty) ? null : key;
  }

  bool get isConfigured => _baseUrl != null;

  Future<String> chat({
    required String userMessage,
    String? systemMessage,
  }) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) {
      throw const AiUnconfiguredException();
    }

    final appKey = _appKey;
    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('$baseUrl$_chatPath'),
            headers: {
              'Content-Type': 'application/json',
              if (appKey != null) 'x-app-key': appKey,
            },
            body: jsonEncode({
              'userMessage': userMessage,
              if (systemMessage != null && systemMessage.isNotEmpty)
                'systemMessage': systemMessage,
            }),
          )
          .timeout(_timeout);
    } catch (e) {
      throw Exception('Could not reach the AI service. Check your connection.');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('AI request was not authorized.');
    }
    if (response.statusCode == 429) {
      throw Exception('Too many AI requests. Please wait a moment and try again.');
    }
    if (response.statusCode != 200) {
      throw Exception('AI service error (${response.statusCode}).');
    }

    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = data['content'] as String?;
    if (content == null || content.trim().isEmpty) {
      throw Exception('The AI returned an empty response.');
    }

    debugPrint('AI proxy response received (${content.length} chars)');
    return content.trim();
  }
}

class AiUnconfiguredException implements Exception {
  const AiUnconfiguredException();
  @override
  String toString() =>
      'AI is not configured. Set AI_PROXY_URL to enable it.';
}
