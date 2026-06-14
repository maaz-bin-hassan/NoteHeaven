import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Client for NoteHeaven's backend AI proxy.
///
/// The app NEVER holds the DeepSeek API key. It calls our own proxy
/// (`POST {AI_PROXY_URL}/v1/ai/chat`) which adds the secret server-side. The
/// app only carries:
///   * `AI_PROXY_URL` — where the proxy lives (unset ⇒ AI disabled).
///   * `AI_APP_KEY`   — low-sensitivity shared key sent as `x-app-key`.
///
/// The class keeps its old name and `chat`/`isConfigured` surface so existing
/// callers (editor, settings) are unaffected; only the transport changed.
class DeepSeekService {
  static const _timeout = Duration(seconds: 35);

  static final DeepSeekService _instance = DeepSeekService._internal();
  factory DeepSeekService() => _instance;
  DeepSeekService._internal();

  String? get _proxyUrl {
    if (!dotenv.isInitialized) return null;
    final raw = dotenv.env['AI_PROXY_URL']?.trim();
    if (raw == null || raw.isEmpty) return null;
    // Normalise away a trailing slash so we can append the path cleanly.
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  String? get _appKey {
    if (!dotenv.isInitialized) return null;
    final raw = dotenv.env['AI_APP_KEY']?.trim();
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// AI is available once a proxy URL is configured.
  bool get isConfigured => _proxyUrl != null;

  Future<String> chat({
    required String userMessage,
    String? systemMessage,
  }) async {
    final proxyUrl = _proxyUrl;
    if (proxyUrl == null) {
      throw const AiUnconfiguredException();
    }

    final uri = Uri.parse('$proxyUrl/v1/ai/chat');
    final appKey = _appKey;

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
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

    Map<String, dynamic>? json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      json = null;
    }

    if (response.statusCode == 200) {
      final content = json?['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw Exception('The AI returned an empty response.');
      }
      return content.trim();
    }

    // The proxy returns { error: { code, message } } with a user-safe message.
    final serverMessage = (json?['error'] as Map<String, dynamic>?)?['message'];
    if (serverMessage is String && serverMessage.isNotEmpty) {
      throw Exception(serverMessage);
    }
    throw Exception(_fallbackMessage(response.statusCode));
  }

  String _fallbackMessage(int status) {
    switch (status) {
      case 401:
        return 'AI request rejected. Check the app key.';
      case 413:
        return 'That note is too long for the AI.';
      case 429:
        return 'The AI service is busy. Please try again shortly.';
      case 502:
      case 503:
      case 504:
        return 'The AI service is temporarily unavailable.';
      default:
        return 'AI request failed (status $status).';
    }
  }
}

class AiUnconfiguredException implements Exception {
  const AiUnconfiguredException();
  @override
  String toString() =>
      'AI is not configured. Set AI_PROXY_URL to enable it.';
}
