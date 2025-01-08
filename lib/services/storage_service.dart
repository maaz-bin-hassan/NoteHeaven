import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Future<String?> uploadFile(File file, String directory) async {
    try {
      if (!await file.exists()) {
        debugPrint('File does not exist: ${file.path}');
        return null;
      }

      final appDir = await getApplicationDocumentsDirectory();
      final storageDir = Directory('${appDir.path}/$directory');

      if (!await storageDir.exists()) {
        await storageDir.create(recursive: true);
      }

      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final String newPath = path.join(storageDir.path, fileName);

      // Copy file to app storage
      final File newFile = await file.copy(newPath);
      debugPrint('File saved locally: ${newFile.path}');

      return newFile.path;
    } catch (e, stackTrace) {
      debugPrint('Error saving file: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('File deleted successfully: $filePath');
      }
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  Future<String?> uploadImage(File file) async {
    return uploadFile(file, 'images');
  }

  Future<String?> uploadAudio(File file) async {
    return uploadFile(file, 'audio');
  }
}
