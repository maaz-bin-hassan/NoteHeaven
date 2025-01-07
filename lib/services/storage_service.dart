import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> uploadImage(File file) async {
    try {
      if (!await file.exists()) {
        debugPrint('File does not exist: ${file.path}');
        return null;
      }

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final String fileName =
          'users/${user.uid}/images/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final Reference ref = _storage.ref().child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/${path.extension(file.path).replaceFirst('.', '')}',
        customMetadata: {
          'userId': user.uid,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Create upload task
      final UploadTask uploadTask = ref.putFile(file, metadata);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('Upload progress: ${progress.toStringAsFixed(2)}%');
        },
        onError: (e) {
          debugPrint('Upload error: $e');
        },
      );

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('File uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('Error uploading file: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<String?> uploadAudio(File file) async {
    try {
      if (!await file.exists()) {
        debugPrint('Audio file does not exist: ${file.path}');
        return null;
      }

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final String fileName =
          'users/${user.uid}/audio/${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
      final Reference ref = _storage.ref().child(fileName);

      final metadata = SettableMetadata(
        contentType: 'audio/m4a',
        customMetadata: {
          'userId': user.uid,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask uploadTask = ref.putFile(file, metadata);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress =
              (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
          debugPrint('Upload progress: ${progress.toStringAsFixed(2)}%');
        },
        onError: (e) {
          debugPrint('Upload error: $e');
        },
      );

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Audio uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('Error uploading audio: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      if (url.isEmpty) return;

      final ref = _storage.refFromURL(url);
      await ref.delete();
      debugPrint('File deleted successfully: $url');
    } catch (e) {
      debugPrint('Error deleting file: $e');
      // Don't rethrow - just log the error
    }
  }
}
