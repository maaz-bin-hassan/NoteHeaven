import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';

/// Low-level WebSocket transport for peer-to-peer note sharing on the LAN.
///
/// Payloads are opaque JSON maps; encoding/decoding of note content and media
/// lives in [NoteShareManager].
class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final String deviceId = const Uuid().v4();
  static const _port = 8080;

  HttpServer? _server;
  final _incomingController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Incoming shared-note payloads from other devices.
  Stream<Map<String, dynamic>> get incomingNotes =>
      _incomingController.stream;

  Future<void> startServer() async {
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      debugPrint('Share server listening on port $_port');
      _server!.transform(WebSocketTransformer()).listen(
            _handleConnection,
            onError: (e) => debugPrint('Share server error: $e'),
          );
    } catch (e) {
      debugPrint('Error starting share server: $e');
    }
  }

  void _handleConnection(WebSocket socket) {
    socket.listen(
      (message) {
        try {
          final data = json.decode(message as String) as Map<String, dynamic>;
          if (data['deviceId'] == deviceId) return; // ignore our own
          if (data['type'] == 'note_share_request' && data['note'] is Map) {
            _incomingController
                .add(Map<String, dynamic>.from(data['note'] as Map));
          }
        } catch (e) {
          debugPrint('Error parsing incoming message: $e');
        }
      },
      onError: (e) => debugPrint('Share socket error: $e'),
      cancelOnError: true,
    );
  }

  /// Sends an already-encoded note payload to [targetIp].
  Future<void> sendNote(Map<String, dynamic> notePayload, String targetIp) async {
    IOWebSocketChannel? channel;
    try {
      channel = IOWebSocketChannel.connect(
        'ws://$targetIp:$_port',
        connectTimeout: const Duration(seconds: 5),
      );
      await channel.ready.timeout(const Duration(seconds: 5));
      channel.sink.add(json.encode({
        'type': 'note_share_request',
        'note': notePayload,
        'deviceId': deviceId,
      }));
      // Give the frame time to flush before closing.
      await Future.delayed(const Duration(milliseconds: 600));
    } finally {
      await channel?.sink.close();
    }
  }

  Future<String?> getLocalIP() async {
    try {
      final wifiIP = await NetworkInfo().getWifiIP();
      if (wifiIP != null && wifiIP.isNotEmpty) return wifiIP;
    } catch (e) {
      debugPrint('getWifiIP failed: $e');
    }
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (e) {
      debugPrint('NetworkInterface.list failed: $e');
    }
    return null;
  }

  void dispose() {
    _server?.close(force: true);
    _server = null;
    _incomingController.close();
  }
}
