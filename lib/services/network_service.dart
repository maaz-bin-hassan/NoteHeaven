import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:web_socket_channel/io.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/note.dart';

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final String _deviceId = const Uuid().v4();

  IOWebSocketChannel? _channel;
  StreamController<Note>? _noteStreamController;
  HttpServer? _server;
  final _port = 8080;
  Timer? _reconnectionTimer;

  final _noteReceiveController = StreamController<Note>.broadcast();
  Stream<Note> get noteReceiveStream => _noteReceiveController.stream;

  Stream<Note> get noteStream {
    _noteStreamController ??= StreamController<Note>.broadcast();
    return _noteStreamController!.stream;
  }

  Future<void> startServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, _port);
      debugPrint('WebSocket server listening on port $_port');

      _server!.transform(WebSocketTransformer()).listen(
        (WebSocket webSocket) {
          debugPrint('Client connected');
          _handleIncomingConnection(webSocket);
        },
        onError: (e) => debugPrint('Server error: $e'),
      );
    } catch (e) {
      debugPrint('Error starting server: $e');
    }
  }

  Future<void> startListening() async {
    await _connectToServer();
  }

  Future<void> _connectToServer() async {
    if (_channel != null) {
      await _channel?.sink.close();
      _channel = null;
    }

    try {
      final ip = await _getLocalIP();
      if (ip == null) return;

      final wsUrl = 'ws://$ip:$_port';
      debugPrint('Connecting to WebSocket at $wsUrl');

      _channel = IOWebSocketChannel.connect(
        wsUrl,
        connectTimeout: const Duration(seconds: 5),
      );

      _channel!.stream.listen(
        (message) {
          try {
            final noteJson = json.decode(message);
            final note = Note.fromJson(noteJson);
            _noteStreamController?.add(note);
            debugPrint('Received note: ${note.title}');
          } catch (e) {
            debugPrint('Error parsing received note: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _scheduleReconnection();
        },
        onDone: () {
          debugPrint('WebSocket connection closed');
          _scheduleReconnection();
        },
      );
    } catch (e) {
      debugPrint('Error connecting to WebSocket: $e');
      _scheduleReconnection();
    }
  }

  void _scheduleReconnection() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer(const Duration(seconds: 5), () {
      debugPrint('Attempting to reconnect...');
      _connectToServer();
    });
  }

  Future<String?> _getLocalIP() async {
    try {
      final networkInfo = NetworkInfo();
      final wifiIP = await networkInfo.getWifiIP();
      debugPrint('WiFi IP: $wifiIP');
      return wifiIP;
    } catch (e) {
      debugPrint('Error getting WiFi IP: $e');
      try {
        final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4,
          includeLinkLocal: true,
        );
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (!addr.isLoopback) {
              debugPrint('Using network interface IP: ${addr.address}');
              return addr.address;
            }
          }
        }
      } catch (e) {
        debugPrint('Error getting network interface IP: $e');
      }
      return null;
    }
  }

  Future<String> _saveFileLocally(
      String sourceFilePath, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final newPath = '${appDir.path}/$fileName';
    await File(sourceFilePath).copy(newPath);
    return newPath;
  }

  Future<void> _sendFile(String filePath, WebSocket socket) async {
    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint('File not found: $filePath');
      return;
    }

    final fileName = basename(filePath);
    final fileBytes = await file.readAsBytes();
    final fileData = {
      'type': 'file_transfer',
      'fileName': fileName,
      'fileData': base64Encode(fileBytes),
    };

    socket.add(json.encode(fileData));
  }

  Future<void> shareNote(Note note, String targetIp) async {
    try {
      final ownIp = await _getLocalIP();
      if (ownIp == targetIp) {
        throw Exception('Cannot share note to own device');
      }

      final wsUrl = 'ws://$targetIp:$_port';
      final channel = IOWebSocketChannel.connect(wsUrl);

      // Wait for the connection to be established
      await channel.ready;
      final webSocket = channel.sink as WebSocket;

      // First, send all files
      for (String imagePath in note.images) {
        await _sendFile(imagePath, webSocket);
      }
      for (String audioPath in note.audioRecordings) {
        await _sendFile(audioPath, webSocket);
      }

      // Then send the note data
      final noteJson = note.toJson();
      final request = {
        'type': 'note_share_request',
        'note': noteJson,
        'sender': await _getLocalIP(),
        'deviceId': _deviceId,
      };

      webSocket.add(json.encode(request));
      debugPrint('Note and files shared with $targetIp');

      await Future.delayed(const Duration(seconds: 2));
      await channel.sink.close();
    } catch (e) {
      debugPrint('Error sharing note: $e');
      rethrow;
    }
  }

  Future<void> acceptNote(Note note, String senderIp) async {
    IOWebSocketChannel? channel;
    try {
      final wsUrl = 'ws://$senderIp:$_port';
      channel = IOWebSocketChannel.connect(
        wsUrl,
        connectTimeout: const Duration(seconds: 5),
      );

      final response = {
        'type': 'note_share_accepted',
        'note': note.toJson(),
      };

      await channel.ready.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Connection timed out'),
      );

      channel.sink.add(json.encode(response));
      debugPrint('Acceptance sent to $senderIp');

      bool confirmed = false;
      await for (var message in channel.stream.timeout(
        const Duration(seconds: 5),
        onTimeout: (sink) => sink.close(),
      )) {
        final data = json.decode(message);
        if (data['type'] == 'note_share_confirmed') {
          confirmed = true;
          break;
        }
      }

      if (!confirmed) {
        throw Exception('Note acceptance was not confirmed');
      }
    } catch (e) {
      debugPrint('Error accepting note: $e');
      rethrow;
    } finally {
      await channel?.sink.close();
    }
  }

  Future<void> broadcastNote(Note note) async {
    try {
      debugPrint('Preparing note for sharing...');
      final localIP = await _getLocalIP();
      if (localIP == null) {
        debugPrint('Could not get local IP');
        return;
      }

      final noteJson = json.encode(note.toJson());
      debugPrint('Note encoded successfully');

      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final List<int> dataToSend = utf8.encode(noteJson);

      socket.send(
        dataToSend,
        InternetAddress('255.255.255.255'),
        _port,
      );

      debugPrint('Note broadcast to local network');

      await Future.delayed(const Duration(seconds: 1));
      socket.close();
    } catch (e, stack) {
      debugPrint('Error sharing note: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  void _handleIncomingConnection(WebSocket webSocket) {
    Map<String, List<int>> fileBuffers = {};
    Map<String, String> receivedFiles = {};

    webSocket.listen(
      (message) async {
        try {
          final data = json.decode(message);

          if (data['deviceId'] == _deviceId) {
            debugPrint('Ignoring message from own device');
            return;
          }

          if (data['type'] == 'file_transfer') {
            final fileName = data['fileName'];
            final fileBytes = base64Decode(data['fileData']);

            // Save received file
            final appDir = await getApplicationDocumentsDirectory();
            final filePath = '${appDir.path}/$fileName';
            await File(filePath).writeAsBytes(fileBytes);
            receivedFiles[fileName] = filePath;
            debugPrint('File received and saved: $filePath');
          } else if (data['type'] == 'note_share_request') {
            final note = Note.fromJson(data['note']);

            // Update note with new file paths
            final List<String> updatedImages = [];
            for (var imagePath in note.images) {
              final fileName = basename(imagePath);
              if (receivedFiles.containsKey(fileName)) {
                updatedImages.add(receivedFiles[fileName]!);
              }
            }

            final List<String> updatedAudioRecordings = [];
            for (var audioPath in note.audioRecordings) {
              final fileName = basename(audioPath);
              if (receivedFiles.containsKey(fileName)) {
                updatedAudioRecordings.add(receivedFiles[fileName]!);
              }
            }

            note.images = updatedImages;
            note.audioRecordings = updatedAudioRecordings;

            _noteReceiveController.add(note);
          }
        } catch (e) {
          debugPrint('Error handling received message: $e');
        }
      },
      onError: (e) => debugPrint('WebSocket error: $e'),
      onDone: () => debugPrint('Client disconnected'),
    );
  }

  void dispose() {
    _reconnectionTimer?.cancel();
    _channel?.sink.close();
    _server?.close();
    _noteStreamController?.close();
    _noteReceiveController.close();
    _channel = null;
    _server = null;
    _noteStreamController = null;
  }
}
