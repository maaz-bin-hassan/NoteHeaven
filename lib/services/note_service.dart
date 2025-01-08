import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import 'database_helper.dart';

class NoteService {
  final DatabaseHelper _db = DatabaseHelper();
  List<Note> _cachedNotes = [];
  StreamController<List<Note>>? _notesController;

  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  Stream<List<Note>> get notesStream {
    _notesController ??= StreamController<List<Note>>.broadcast();
    _refreshNotes();
    return _notesController!.stream;
  }

  Future<void> _refreshNotes() async {
    try {
      _cachedNotes = await _db.getNotes();
      _notesController?.add(_cachedNotes);
    } catch (e) {
      debugPrint('Error refreshing notes: $e');
      _notesController?.addError(e);
    }
  }

  Future<void> addNote(Note note) async {
    try {
      List<String> newImages =
          note.images.where((path) => !path.startsWith('/')).toList();
      List<String> newAudioFiles =
          note.audioRecordings.where((path) => !path.startsWith('/')).toList();

      await _db.insertNote(note, newImages, newAudioFiles);
      await _refreshNotes();
    } catch (e) {
      debugPrint('Error adding note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      await _db.updateNote(note);
      await _refreshNotes();
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      await _db.deleteNote(id);
      await _refreshNotes();
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  Future<List<Note>> searchNotes(String query) async {
    try {
      final allNotes = await _db.getNotes();
      if (query.isEmpty) return allNotes;

      final lowercaseQuery = query.toLowerCase();
      return allNotes.where((note) {
        return note.title.toLowerCase().contains(lowercaseQuery) ||
            note.content.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      debugPrint('Error searching notes: $e');
      return [];
    }
  }

  void dispose() {
    _notesController?.close();
    _notesController = null;
    _cachedNotes = [];
  }
}
