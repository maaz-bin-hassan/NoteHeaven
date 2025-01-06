import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

class NoteService {
  static final NoteService _instance = NoteService._internal();
  factory NoteService() => _instance;
  NoteService._internal();

  static const String _storageKey = 'notes_data';
  final List<Note> _notes = [];
  final _notesStreamController = StreamController<List<Note>>.broadcast();
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadNotes();
      _isInitialized = true;
      debugPrint('NoteService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NoteService: $e');
    }
  }

  Stream<List<Note>> get notesStream => _notesStreamController.stream;

  Future<void> _loadNotes() async {
    try {
      final String? notesJson = _prefs.getString(_storageKey);
      debugPrint('Loading notes from storage: $notesJson');

      if (notesJson != null) {
        final List<dynamic> decoded = jsonDecode(notesJson);
        _notes.clear();
        _notes.addAll(
          decoded.map((noteJson) => Note.fromJson(noteJson)).toList(),
        );
        _notesStreamController.add(_notes);
        debugPrint('Loaded ${_notes.length} notes');
      }
    } catch (e) {
      debugPrint('Error loading notes: $e');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final String notesJson =
          jsonEncode(_notes.map((note) => note.toJson()).toList());
      await _prefs.setString(_storageKey, notesJson);
      debugPrint('Saved ${_notes.length} notes to storage');

      // Verify save
      final saved = _prefs.getString(_storageKey);
      debugPrint('Verification - Notes in storage: $saved');
    } catch (e) {
      debugPrint('Error saving notes: $e');
      rethrow;
    }
  }

  Future<void> addNote(Note note) async {
    try {
      _notes.add(note);
      _notesStreamController.add(_notes);
      await _saveNotes();
      debugPrint('Added note: ${note.title}');
    } catch (e) {
      debugPrint('Error adding note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
        _notesStreamController.add(_notes);
        await _saveNotes();
        debugPrint('Updated note: ${note.title}');
      }
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      _notes.removeWhere((note) => note.id == id);
      _notesStreamController.add(_notes);
      await _saveNotes();
      debugPrint('Deleted note with id: $id');
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  Future<void> dispose() async {
    try {
      await _saveNotes();
      _notesStreamController.close();
      debugPrint('NoteService disposed');
    } catch (e) {
      debugPrint('Error disposing NoteService: $e');
    }
  }
}
