import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart'; // Add this import
import '../models/note.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final String path = join(documentsDirectory.path, 'notes.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            title TEXT,
            content TEXT,
            timestamp TEXT,
            createdAt TEXT,
            modifiedAt TEXT,
            color TEXT,
            titleColor INTEGER,
            contentColor INTEGER,
            images TEXT,
            audioRecordings TEXT
          )
        ''');
      },
    );
  }

  Future<String> copyFileToLocalStorage(File file, String directory) async {
    final String fileName = basename(file.path);
    final Directory appDir = await getApplicationDocumentsDirectory();
    final String newPath = join(appDir.path, directory, fileName);

    // Create directory if it doesn't exist
    final Directory newDir = Directory(dirname(newPath));
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }

    // Copy file to new location
    await file.copy(newPath);
    return newPath;
  }

  Future<List<Note>> getNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('notes', orderBy: 'timestamp DESC');

    return List.generate(maps.length, (i) {
      final Map<String, dynamic> noteMap = maps[i];
      final images = noteMap['images'] != null
          ? noteMap['images']
              .toString()
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];
      final audioRecordings = noteMap['audioRecordings'] != null
          ? noteMap['audioRecordings']
              .toString()
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];

      return Note(
        id: noteMap['id'] ?? '',
        title: noteMap['title'] ?? '',
        content: noteMap['content'] ?? '',
        timestamp: DateTime.parse(
            noteMap['timestamp'] ?? DateTime.now().toIso8601String()),
        createdAt: DateTime.parse(
            noteMap['createdAt'] ?? DateTime.now().toIso8601String()),
        modifiedAt: DateTime.parse(
            noteMap['modifiedAt'] ?? DateTime.now().toIso8601String()),
        images: images,
        color: noteMap['color'] ?? '#FFFFFF',
        audioRecordings: audioRecordings,
        titleColor:
            Color(int.parse(noteMap['titleColor']?.toString() ?? '0xFF000000')),
        contentColor: Color(
            int.parse(noteMap['contentColor']?.toString() ?? '0xFF000000')),
      );
    });
  }

  Future<void> insertNote(
      Note note, List<String> newImages, List<String> newAudioFiles) async {
    final db = await database;

    // Copy new files to app's local storage
    List<String> savedImages = List.from(note.images);
    List<String> savedAudioFiles = List.from(note.audioRecordings);

    // Add new images
    for (String imagePath in newImages) {
      if (await File(imagePath).exists()) {
        final String savedPath =
            await copyFileToLocalStorage(File(imagePath), 'images');
        savedImages.add(savedPath);
      }
    }

    // Add new audio files
    for (String audioPath in newAudioFiles) {
      if (await File(audioPath).exists()) {
        final String savedPath =
            await copyFileToLocalStorage(File(audioPath), 'audio');
        savedAudioFiles.add(savedPath);
      }
    }

    await db.insert(
      'notes',
      {
        'id': note.id,
        'title': note.title,
        'content': note.content,
        'timestamp': DateTime.now().toIso8601String(),
        'createdAt': note.createdAt.toIso8601String(),
        'modifiedAt': DateTime.now().toIso8601String(),
        'color': note.color,
        'titleColor': note.titleColor.value.toString(),
        'contentColor': note.contentColor.value.toString(),
        'images': savedImages.join(','),
        'audioRecordings': savedAudioFiles.join(','),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateNote(Note note) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'title': note.title,
        'content': note.content,
        'modifiedAt': DateTime.now().toIso8601String(),
        'color': note.color,
        'titleColor': note.titleColor.value.toString(),
        'contentColor': note.contentColor.value.toString(),
        'images': note.images.join(','),
        'audioRecordings': note.audioRecordings.join(','),
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<void> deleteNote(String id) async {
    final db = await database;

    // Get note data before deletion to clean up files
    final note = await db.query('notes', where: 'id = ?', whereArgs: [id]);
    if (note.isNotEmpty) {
      final images = note.first['images'].toString().split(',');
      final audioRecordings =
          note.first['audioRecordings'].toString().split(',');

      // Delete associated files
      for (String path in [...images, ...audioRecordings]) {
        if (path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    }

    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
