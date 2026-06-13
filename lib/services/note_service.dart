import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/note.dart';
import 'database_helper.dart';

/// Singleton facade over note CRUD with a broadcast stream of the current list.
class NoteService {
  final DatabaseHelper _db = DatabaseHelper();
  List<Note> _cachedNotes = [];
  final StreamController<List<Note>> _notesController =
      StreamController<List<Note>>.broadcast();
  bool _loaded = false;

  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  List<Note> get notes => List.unmodifiable(_cachedNotes);

  Stream<List<Note>> get notesStream {
    if (!_loaded) {
      _loaded = true;
      _refreshNotes();
    }
    return _notesController.stream;
  }

  Future<void> _refreshNotes() async {
    try {
      _cachedNotes = await _db.getNotes();
      if (!_notesController.isClosed) _notesController.add(_cachedNotes);
    } catch (e) {
      debugPrint('Error refreshing notes: $e');
      if (!_notesController.isClosed) _notesController.addError(e);
    }
  }

  Future<void> addNote(Note note) async {
    try {
      await _db.insertNote(note);
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

  Future<void> setPinned(String id, bool pinned) async {
    try {
      await _db.setPinned(id, pinned);
      await _refreshNotes();
    } catch (e) {
      debugPrint('Error updating pin: $e');
      rethrow;
    }
  }

  /// Removes the note from the database but keeps its media files on disk so
  /// the deletion can be undone. Call [purgeNoteFiles] once the undo window
  /// has elapsed.
  Future<void> removeNote(String id) async {
    try {
      await _db.deleteNoteRow(id);
      await _refreshNotes();
    } catch (e) {
      debugPrint('Error removing note: $e');
      rethrow;
    }
  }

  /// Permanently deletes a note's media (images, audio). Safe to ignore errors.
  Future<void> purgeNoteFiles(Note note) async {
    await _db.deleteNoteFiles(note);
  }

  Future<List<Note>> searchNotes(String query) async {
    final trimmed = query.trim().toLowerCase();
    final source = _loaded ? _cachedNotes : await _db.getNotes();
    if (trimmed.isEmpty) return source;
    return source.where((note) {
      return note.title.toLowerCase().contains(trimmed) ||
          note.content.toLowerCase().contains(trimmed);
    }).toList();
  }

  void dispose() {
    _notesController.close();
    _cachedNotes = [];
  }
}
