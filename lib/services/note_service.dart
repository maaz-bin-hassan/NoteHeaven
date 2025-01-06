import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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

  // Initialize shared preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadNotes();
  }

  Stream<List<Note>> get notesStream => _notesStreamController.stream;

  // Load notes from local storage
  Future<void> _loadNotes() async {
    final String? notesJson = _prefs.getString(_storageKey);
    if (notesJson != null) {
      final List<dynamic> decoded = jsonDecode(notesJson);
      _notes.clear();
      _notes.addAll(
        decoded.map((noteJson) => Note.fromJson(noteJson)).toList(),
      );
      _notesStreamController.add(_notes);
    }
  }

  // Save notes to local storage
  Future<void> _saveNotes() async {
    final String notesJson =
        jsonEncode(_notes.map((note) => note.toJson()).toList());
    await _prefs.setString(_storageKey, notesJson);
  }

  void addNote(
      String title, String content, String color, List<String> images) {
    final note = Note(
      id: const Uuid().v4(),
      title: title,
      content: content,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      images: images,
      color: color,
    );
    _notes.add(note);
    _notesStreamController.add(_notes);
    _saveNotes();
  }

  void updateNote(Note note) {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      _notesStreamController.add(_notes);
      _saveNotes();
    }
  }

  void deleteNote(String id) {
    _notes.removeWhere((note) => note.id == id);
    _notesStreamController.add(_notes);
    _saveNotes();
  }

  void dispose() {
    _notesStreamController.close();
  }
}
