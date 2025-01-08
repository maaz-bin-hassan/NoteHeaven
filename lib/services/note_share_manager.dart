import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import 'discovery_service.dart';
import 'network_service.dart';

class NoteShareManager {
  static final NoteShareManager _instance = NoteShareManager._internal();
  factory NoteShareManager() => _instance;
  NoteShareManager._internal();

  final _discoveryService = DiscoveryService();
  final _networkService = NetworkService();
  final _receivedNotesController = StreamController<Note>.broadcast();

  Stream<Note> get receivedNotes => _receivedNotesController.stream;

  Future<void> initialize() async {
    await _discoveryService.startDiscovery();
    await _networkService.startServer();
    _listenForNotes();
  }

  void _listenForNotes() {
    _networkService.noteReceiveStream.listen((note) {
      _receivedNotesController.add(note);
    });
  }

  Future<List<String>> findNearbyDevices() async {
    return _discoveryService.findPeers();
  }

  Future<void> shareNote(Note note) async {
    try {
      final peers = await findNearbyDevices();
      debugPrint('Found ${peers.length} peers');

      for (var peerIp in peers) {
        try {
          await _networkService.shareNote(note, peerIp);
          debugPrint('Note shared with $peerIp');
        } catch (e) {
          debugPrint('Error sharing note with $peerIp: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in shareNote: $e');
      rethrow;
    }
  }

  void dispose() {
    _discoveryService.dispose();
    _networkService.dispose();
    _receivedNotesController.close();
  }
}
