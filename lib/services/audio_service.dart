import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class AudioService {
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  String? _currentRecordingPath;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentlyPlayingPath;

  // Add getter for the audio player
  AudioPlayer get player => _audioPlayer;

  Future<bool> checkPermission() async {
    final micStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();

    return micStatus.isGranted && storageStatus.isGranted;
  }

  Future<String?> startRecording() async {
    try {
      if (await checkPermission()) {
        await stopPlaying();

        final dir = await getApplicationDocumentsDirectory();
        final recordingsDir = Directory('${dir.path}/recordings');
        if (!await recordingsDir.exists()) {
          await recordingsDir.create(recursive: true);
        }

        _currentRecordingPath =
            '${recordingsDir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Updated recording configuration
        await _audioRecorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _currentRecordingPath!,
        );

        _isRecording = true;
        return _currentRecordingPath;
      }
    } catch (e) {
      _currentRecordingPath = null;
      _isRecording = false;
      rethrow;
    }
    return null;
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording) return null;

      await _audioRecorder.stop();
      _isRecording = false;

      // Verify the file exists
      if (_currentRecordingPath != null &&
          File(_currentRecordingPath!).existsSync()) {
        return _currentRecordingPath;
      }
    } catch (e) {
      _isRecording = false;
      rethrow;
    }
    return null;
  }

  Future<void> playRecording(String path) async {
    try {
      if (_isPlaying) {
        await stopPlaying();
      }

      if (!File(path).existsSync()) {
        throw Exception('Audio file not found');
      }

      await _audioPlayer.play(DeviceFileSource(path));
      _isPlaying = true;
      _currentlyPlayingPath = path;

      // Listen for playback completion
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _currentlyPlayingPath = null;
      });
    } catch (e) {
      _isPlaying = false;
      _currentlyPlayingPath = null;
      rethrow;
    }
  }

  Future<void> stopPlaying() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentlyPlayingPath = null;
    } catch (e) {
      _isPlaying = false;
      _currentlyPlayingPath = null;
      rethrow;
    }
  }

  Future<void> deleteRecording(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  String? get currentlyPlayingPath => _currentlyPlayingPath;

  Future<void> dispose() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      if (_isPlaying) {
        await stopPlaying();
      }
      await _audioRecorder.dispose();
      await _audioPlayer.dispose();
    } catch (e) {
      // Handle or log disposal errors
    }
  }
}
