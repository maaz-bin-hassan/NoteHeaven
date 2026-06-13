import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

/// Handles audio recording and coordinates playback so that only one clip
/// plays at a time.
///
/// Recording into the app's private documents directory does NOT require the
/// storage permission. The previous implementation also requested
/// `Permission.storage`, which is permanently denied on Android 13+ and so
/// silently blocked all recording on modern devices. We now rely solely on the
/// recorder's own microphone-permission check.
class AudioService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;

  /// Id of the player widget that is currently allowed to play. Each
  /// [AudioPlayerWidget] owns its own player and pauses itself when this
  /// changes to another id, giving single-clip playback without the cross-talk
  /// of a single shared player.
  final ValueNotifier<int> activePlayerId = ValueNotifier<int>(-1);
  int _idCounter = 0;
  int nextPlayerId() => _idCounter++;

  Future<bool> hasPermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Mic permission check failed: $e');
      return false;
    }
  }

  Future<String?> startRecording() async {
    try {
      if (kIsWeb) return null;
      if (!await hasPermission()) return null;

      final dir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${dir.path}/recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final path =
          '${recordingsDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );
      _currentRecordingPath = path;
      return path;
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _currentRecordingPath = null;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      final result = path ?? _currentRecordingPath;
      _currentRecordingPath = null;
      if (result != null && File(result).existsSync()) {
        return result;
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }
    return null;
  }

  Future<bool> get isRecording async {
    try {
      return await _recorder.isRecording();
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    try {
      await _recorder.dispose();
    } catch (_) {}
    activePlayerId.dispose();
  }
}
