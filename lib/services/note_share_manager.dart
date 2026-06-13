import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import 'discovery_service.dart';
import 'network_service.dart';

/// Coordinates peer discovery and note transfer.
///
/// Media (images/audio) is embedded as base64 in the payload so received notes
/// reference files that actually exist on the receiving device. Vector
/// drawings travel as JSON. A combined media cap keeps payloads sane on the
/// local socket; if exceeded, text + drawings are shared and media is skipped.
class NoteShareManager {
  static final NoteShareManager _instance = NoteShareManager._internal();
  factory NoteShareManager() => _instance;
  NoteShareManager._internal();

  static const _mediaCapBytes = 6 * 1024 * 1024; // ~6 MB total

  final _discoveryService = DiscoveryService();
  final _networkService = NetworkService();
  final _receivedNotesController = StreamController<Note>.broadcast();
  StreamSubscription? _incomingSub;
  bool _initialized = false;

  Stream<Note> get receivedNotes => _receivedNotesController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _networkService.startServer();
    await _discoveryService.startDiscovery();
    _incomingSub = _networkService.incomingNotes.listen((payload) async {
      try {
        final note = await _decode(payload);
        _receivedNotesController.add(note);
      } catch (e) {
        debugPrint('Failed to decode shared note: $e');
      }
    });
  }

  Future<List<String>> findNearbyDevices() => _discoveryService.findPeers();

  /// Returns true if at least one peer received the note.
  Future<bool> shareNote(Note note) async {
    final peers = await findNearbyDevices();
    if (peers.isEmpty) return false;

    final payload = await _encode(note);
    var delivered = 0;
    for (final peerIp in peers) {
      try {
        await _networkService.sendNote(payload, peerIp);
        delivered++;
      } catch (e) {
        debugPrint('Error sharing with $peerIp: $e');
      }
    }
    return delivered > 0;
  }

  Future<Map<String, dynamic>> _encode(Note note) async {
    final payload = note.toJson();
    final encodedImages = <Map<String, String>>[];
    final encodedAudio = <Map<String, String>>[];
    var budget = _mediaCapBytes;

    Future<void> embed(List<String> paths, List<Map<String, String>> out) async {
      for (final path in paths) {
        try {
          final file = File(path);
          if (!await file.exists()) continue;
          final length = await file.length();
          if (length > budget) continue; // skip oversize, keep the rest
          final bytes = await file.readAsBytes();
          budget -= length;
          out.add({'name': p.basename(path), 'data': base64Encode(bytes)});
        } catch (e) {
          debugPrint('Skipping media $path: $e');
        }
      }
    }

    await embed(note.images, encodedImages);
    await embed(note.audioRecordings, encodedAudio);

    // Replace local file paths with embedded media in the wire payload.
    payload.remove('images');
    payload.remove('audioRecordings');
    payload['mediaImages'] = encodedImages;
    payload['mediaAudio'] = encodedAudio;
    return payload;
  }

  Future<Note> _decode(Map<String, dynamic> payload) async {
    final images = await _writeMedia(payload['mediaImages'], 'images');
    final audio = await _writeMedia(payload['mediaAudio'], 'audio');

    final base = Note.fromJson(payload);
    final now = DateTime.now();
    // Fresh id/timestamps so received notes never overwrite local ones.
    return Note(
      id: const Uuid().v4(),
      title: base.title,
      content: base.content,
      createdAt: now,
      modifiedAt: now,
      color: base.color,
      titleColor: base.titleColor,
      contentColor: base.contentColor,
      drawings: base.drawings,
      images: images,
      audioRecordings: audio,
    );
  }

  Future<List<String>> _writeMedia(dynamic raw, String subDir) async {
    if (raw is! List) return <String>[];
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, subDir));
    if (!await targetDir.exists()) await targetDir.create(recursive: true);

    final paths = <String>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final data = item['data'] as String?;
        if (data == null) continue;
        final ext = p.extension(item['name']?.toString() ?? '');
        final path = p.join(targetDir.path, '${const Uuid().v4()}$ext');
        await File(path).writeAsBytes(base64Decode(data));
        paths.add(path);
      } catch (e) {
        debugPrint('Failed to write received media: $e');
      }
    }
    return paths;
  }

  void dispose() {
    _incomingSub?.cancel();
    _discoveryService.dispose();
    _networkService.dispose();
    _receivedNotesController.close();
    _initialized = false;
  }
}
