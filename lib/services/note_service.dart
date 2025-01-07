import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import './storage_service.dart';
import '../models/note.dart';

class NoteService {
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late StreamController<List<Note>> _notesStreamController;
  List<Note> _currentNotes = [];
  bool _isInitialized = false;
  StreamSubscription? _notesSubscription;
  final StorageService _storageService = StorageService();
  String? currentUserId;

  NoteService._internal() {
    _createStreamController();
  }

  void _createStreamController() {
    _notesStreamController = StreamController<List<Note>>.broadcast();
  }

  Future<void> init() async {
    if (_notesStreamController.isClosed) {
      _createStreamController();
    }

    // Cancel existing subscription if any
    await _notesSubscription?.cancel();
    _notesSubscription = null;

    if (currentUserId == null) {
      debugPrint('No user ID set, skipping initialization');
      _notesStreamController.add([]);
      return;
    }

    try {
      debugPrint('Initializing NoteService for user: $currentUserId');

      _notesSubscription = _firestore
          .collection('notes')
          .where('userId', isEqualTo: currentUserId)
          .snapshots()
          .handleError((error) {
        debugPrint('Error in notes stream: $error');
        _notesStreamController.add([]);
      }).listen(
        (snapshot) {
          try {
            final notes = snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return Note.fromJson(data);
            }).toList();

            notes.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            _currentNotes = notes;

            if (!_notesStreamController.isClosed) {
              _notesStreamController.add(_currentNotes);
            }

            debugPrint('Loaded ${notes.length} notes for user $currentUserId');
          } catch (e) {
            debugPrint('Error processing notes: $e');
            _notesStreamController.add(_currentNotes);
          }
        },
        onError: (error) {
          debugPrint('Error listening to notes: $error');
          _notesStreamController.add(_currentNotes);
        },
      );

      _isInitialized = true;
      debugPrint('NoteService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NoteService: $e');
      if (!_notesStreamController.isClosed) {
        _notesStreamController.add([]);
      }
    }
  }

  // Set user ID method
  void setUserId(String uid) async {
    debugPrint('Setting user ID: $uid');
    if (currentUserId != uid) {
      currentUserId = uid;
      _isInitialized = false;
      await init();
      debugPrint('Reinitialized NoteService with new user ID: $uid');
    }
  }

  Stream<List<Note>> get notesStream => _notesStreamController.stream;

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
            final url = await _storageService.uploadImage(file);
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
            final url = await _storageService.uploadAudio(file);
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
          final url = await _storageService.uploadImage(File(imagePath));
          if (url != null) {
            imageUrls.add(url);
          }
        } else {
          imageUrls.add(imagePath);
        }
      }

      for (String audioPath in note.audioRecordings) {
        if (!audioPath.startsWith('http')) {
          final url = await _storageService.uploadAudio(File(audioPath));
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
              await _storageService.deleteFile(url);
            }
          }
          // Delete audio recordings
          if (data['audioRecordings'] != null) {
            for (String url in List<String>.from(data['audioRecordings'])) {
              await _storageService.deleteFile(url);
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

  @override
  Future<void> dispose() async {
    try {
      await _notesSubscription?.cancel();
      if (!_notesStreamController.isClosed) {
        await _notesStreamController.close();
      }
      _isInitialized = false;
      debugPrint('NoteService disposed');
    } catch (e) {
      debugPrint('Error disposing NoteService: $e');
    }
  }
}
