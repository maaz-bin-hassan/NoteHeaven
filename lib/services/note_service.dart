import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/note.dart';

class NoteService {
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _auth = FirebaseAuth.instance;

  List<Note> _cachedNotes = [];
  StreamController<List<Note>>? _notesController;
  String? _currentUserId;

  // Singleton pattern
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal() {
    // Initialize auth state listener
    _auth.authStateChanges().listen((user) {
      _currentUserId = user?.uid;
      _resetStream();
    });
  }

  String? get currentUserId => _currentUserId;

  void _resetStream() {
    _notesController?.close();
    _notesController = null;
    _cachedNotes = [];
  }

  Stream<List<Note>> get notesStream {
    _notesController ??= StreamController<List<Note>>.broadcast();

    if (_currentUserId == null) {
      _notesController!.add([]);
      return _notesController!.stream;
    }

    if (_cachedNotes.isNotEmpty) {
      _notesController!.add(_cachedNotes);
    }

    _firestore
        .collection('notes')
        .where('userId', isEqualTo: _currentUserId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        _cachedNotes = snapshot.docs
            .map((doc) => Note.fromJson({...doc.data(), 'id': doc.id}))
            .toList();
        _notesController!.add(_cachedNotes);
      },
      onError: (error) {
        debugPrint('Error fetching notes: $error');
        _notesController!.addError(error);
      },
    );

    return _notesController!.stream;
  }

  // Upload file helper method
  Future<String?> _uploadFile(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading file: $e');
      return null;
    }
  }

  // Delete file helper method
  Future<void> _deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  Future<void> addNote(Note note) async {
    try {
      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      List<String> imageUrls = [];
      List<String> audioUrls = [];

      // Upload images with verification
      for (String imagePath in note.images) {
        if (!imagePath.startsWith('http')) {
          final file = File(imagePath);
          if (await file.exists()) {
            final url =
                await _uploadFile(file, 'images/${file.uri.pathSegments.last}');
            if (url != null) {
              imageUrls.add(url);
              debugPrint('Image uploaded successfully: $url');
            }
          } else {
            debugPrint('Image file not found: $imagePath');
          }
        } else {
          imageUrls.add(imagePath);
        }
      }

      // Upload audio recordings
      for (String audioPath in note.audioRecordings) {
        if (!audioPath.startsWith('http')) {
          final file = File(audioPath);
          if (await file.exists()) {
            final url =
                await _uploadFile(file, 'audio/${file.uri.pathSegments.last}');
            if (url != null) {
              audioUrls.add(url);
              debugPrint('Audio file uploaded: $url');
            }
          } else {
            debugPrint('Audio file not found: $audioPath');
          }
        } else {
          audioUrls.add(audioPath);
        }
      }

      final noteData = {
        'title': note.title,
        'content': note.content,
        'userId': currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': note.createdAt.toIso8601String(),
        'modifiedAt': DateTime.now().toIso8601String(),
        'images': imageUrls,
        'color': note.color,
        'audioRecordings': audioUrls,
        'titleColor': note.titleColor.value,
        'contentColor': note.contentColor.value,
      };

      final docRef = await _firestore.collection('notes').add(noteData);
      debugPrint(
          'Added note with ID: ${docRef.id}, Images: $imageUrls, Audio: $audioUrls');
    } catch (e) {
      debugPrint('Error adding note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      // Similar changes as addNote method
      List<String> imageUrls = [];
      List<String> audioUrls = [];

      for (String imagePath in note.images) {
        if (!imagePath.startsWith('http')) {
          final url = await _uploadFile(File(imagePath),
              'images/${File(imagePath).uri.pathSegments.last}');
          if (url != null) {
            imageUrls.add(url);
          }
        } else {
          imageUrls.add(imagePath);
        }
      }

      for (String audioPath in note.audioRecordings) {
        if (!audioPath.startsWith('http')) {
          final url = await _uploadFile(File(audioPath),
              'audio/${File(audioPath).uri.pathSegments.last}');
          if (url != null) {
            audioUrls.add(url);
          }
        } else {
          audioUrls.add(audioPath);
        }
      }

      await _firestore.collection('notes').doc(note.id).update({
        'title': note.title,
        'content': note.content,
        'modifiedAt': DateTime.now().toIso8601String(),
        'images': imageUrls,
        'color': note.color,
        'audioRecordings': audioUrls,
        'titleColor': note.titleColor.value,
        'contentColor': note.contentColor.value,
      });
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      // Get the note first to get image URLs
      final noteDoc = await _firestore.collection('notes').doc(id).get();
      if (noteDoc.exists) {
        final data = noteDoc.data();
        if (data != null) {
          // Delete images
          if (data['images'] != null) {
            for (String url in List<String>.from(data['images'])) {
              await _deleteFile(url);
            }
          }
          // Delete audio recordings
          if (data['audioRecordings'] != null) {
            for (String url in List<String>.from(data['audioRecordings'])) {
              await _deleteFile(url);
            }
          }
        }
      }

      await _firestore.collection('notes').doc(id).delete();
      debugPrint('Deleted note with id: $id');
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  void dispose() {
    _notesController?.close();
    _notesController = null;
    _cachedNotes = [];
  }
}
