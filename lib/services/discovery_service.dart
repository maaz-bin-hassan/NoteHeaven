import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

class DiscoveryService {
  static final DiscoveryService _instance = DiscoveryService._internal();
  factory DiscoveryService() => _instance;
  DiscoveryService._internal();

  RawDatagramSocket? _socket;
  final _port = 4545;
  Timer? _broadcastTimer;
  bool _isRunning = false;

  final _discoveredPeers = <String, DateTime>{};
  final _peerController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get peerStream => _peerController.stream;

  // Add device ID
  final String _deviceId = const Uuid().v4();

  Future<void> startDiscovery() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _port);
      _socket!.broadcastEnabled = true;
      debugPrint('Discovery socket bound to port $_port');

      _socket!.listen((event) {
        _handleDiscoveryMessage(event);
      });

      _startBroadcasting();
      _startPeerCleanup();
    } catch (e) {
      debugPrint('Error starting discovery: $e');
    }
  }

  Future<String?> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting local IP: $e');
    }
    return null;
  }

  void _handleDiscoveryMessage(RawSocketEvent event) async {
    if (event == RawSocketEvent.read) {
      final datagram = _socket!.receive();
      if (datagram != null) {
        final message = String.fromCharCodes(datagram.data);
        final peerAddress = datagram.address.address;

        // Check if this is our own IP
        final localIp = await _getLocalIp();
        if (localIp == peerAddress) {
          debugPrint('Ignoring message from own device');
          return;
        }

        if (message == 'NOTEHEAVEN_DISCOVER') {
          _socket!.send(
            'NOTEHEAVEN_HERE:$_deviceId'.codeUnits,
            datagram.address,
            _port,
          );
          debugPrint('Sent response to $peerAddress');
        } else if (message.startsWith('NOTEHEAVEN_HERE:')) {
          final parts = message.split(':');
          if (parts.length == 2) {
            final peerDeviceId = parts[1];
            // Only add peer if it's not our device
            if (peerDeviceId != _deviceId) {
              _discoveredPeers[peerAddress] = DateTime.now();
              _peerController.add(_getFilteredPeers());
              debugPrint('Discovered peer: $peerAddress (ID: $peerDeviceId)');
            }
          }
        }
      }
    }
  }

  List<String> _getFilteredPeers() {
    return _discoveredPeers.keys.toList();
  }

  void _startPeerCleanup() {
    Timer.periodic(const Duration(seconds: 5), (_) {
      final now = DateTime.now();
      _discoveredPeers.removeWhere((_, timestamp) {
        return now.difference(timestamp).inSeconds > 10;
      });
      _peerController.add(_discoveredPeers.keys.toList());
    });
  }

  void _startBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      try {
        _socket?.send(
          'NOTEHEAVEN_DISCOVER'.codeUnits,
          InternetAddress('255.255.255.255'),
          _port,
        );
      } catch (e) {
        debugPrint('Error broadcasting: $e');
      }
    });
  }

  Future<List<String>> findPeers() async {
    final completer = Completer<List<String>>();

    // Listen for peer updates
    late StreamSubscription subscription;
    subscription = peerStream.listen((peers) {
      if (peers.isNotEmpty) {
        subscription.cancel();
        completer.complete(peers);
      }
    });

    // Set timeout
    Timer(const Duration(seconds: 3), () {
      subscription.cancel();
      if (!completer.isCompleted) {
        completer.complete(_getFilteredPeers());
      }
    });

    return completer.future;
  }

  void dispose() {
    _broadcastTimer?.cancel();
    _socket?.close();
    _peerController.close();
    _isRunning = false;
    _discoveredPeers.clear();
  }
}
