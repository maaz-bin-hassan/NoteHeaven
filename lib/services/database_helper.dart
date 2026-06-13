import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static const _dbVersion = 2;
  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'notes.db');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            createdAt TEXT,
            modifiedAt TEXT,
            color TEXT,
            titleColor INTEGER,
            contentColor INTEGER,
            images TEXT,
            audioRecordings TEXT,
            drawings TEXT,
            isPinned INTEGER DEFAULT 0
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(db, 'drawings', 'TEXT');
          await _addColumnIfMissing(db, 'isPinned', 'INTEGER DEFAULT 0');
        }
      },
    );
  }

  Future<void> _addColumnIfMissing(
      Database db, String column, String type) async {
    final info = await db.rawQuery('PRAGMA table_info(notes)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE notes ADD COLUMN $column $type');
    }
  }

  Future<String> _appDirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<String> copyFileToLocalStorage(File file, String subDir) async {
    final appDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(join(appDir.path, subDir));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    // Preserve the original extension; generate a collision-free name.
    final ext = extension(file.path);
    final newPath = join(targetDir.path, '${const Uuid().v4()}$ext');
    await file.copy(newPath);
    return newPath;
  }

  /// Copies any media that isn't already inside the app's permanent storage,
  /// dropping references to files that no longer exist. Returns a note whose
  /// media paths are all permanent.
  Future<Note> _persistMedia(Note note) async {
    final appDir = await _appDirPath();
    final images = await _localize(note.images, 'images', appDir);
    final audio = await _localize(note.audioRecordings, 'audio', appDir);
    return note.copyWith(images: images, audioRecordings: audio);
  }

  Future<List<String>> _localize(
      List<String> paths, String subDir, String appDir) async {
    final result = <String>[];
    for (final path in paths) {
      if (path.isEmpty) continue;
      if (path.startsWith(appDir)) {
        result.add(path);
        continue;
      }
      final file = File(path);
      if (await file.exists()) {
        try {
          result.add(await copyFileToLocalStorage(file, subDir));
        } catch (e) {
          debugPrint('Failed to copy media $path: $e');
        }
      }
    }
    return result;
  }

  Future<List<Note>> getNotes() async {
    try {
      final db = await database;
      final maps = await db.query(
        'notes',
        orderBy: 'isPinned DESC, modifiedAt DESC',
      );
      return maps.map(Note.fromDbMap).toList();
    } catch (e) {
      debugPrint('Error getting notes: $e');
      return [];
    }
  }

  Future<Note> insertNote(Note note) async {
    final db = await database;
    final persisted = await _persistMedia(note);
    await db.insert(
      'notes',
      persisted.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return persisted;
  }

  Future<Note> updateNote(Note note) async {
    final db = await database;
    final persisted = await _persistMedia(note);

    // Clean up media files that were removed during this edit.
    final existing = await db.query('notes',
        columns: ['images', 'audioRecordings'],
        where: 'id = ?',
        whereArgs: [note.id]);
    if (existing.isNotEmpty) {
      final oldFiles = <String>{
        ..._split(existing.first['images']),
        ..._split(existing.first['audioRecordings']),
      };
      final keep = <String>{...persisted.images, ...persisted.audioRecordings};
      for (final path in oldFiles.difference(keep)) {
        await _deleteFile(path);
      }
    }

    await db.update(
      'notes',
      persisted.toDbMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    return persisted;
  }

  Future<void> setPinned(String id, bool pinned) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'isPinned': pinned ? 1 : 0,
        'modifiedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Removes only the database row. Media files are left on disk so the delete
  /// can be undone; call [deleteNoteFiles] to reclaim the space afterwards.
  Future<void> deleteNoteRow(String id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Permanently deletes the media files associated with [note].
  Future<void> deleteNoteFiles(Note note) async {
    for (final path in [...note.images, ...note.audioRecordings]) {
      await _deleteFile(path);
    }
  }

  List<String> _split(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return const [];
    final separator = raw.contains('\n') ? '\n' : ',';
    return raw.split(separator).where((s) => s.isNotEmpty).toList();
  }

  Future<void> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('Failed to delete file $path: $e');
    }
  }
}
