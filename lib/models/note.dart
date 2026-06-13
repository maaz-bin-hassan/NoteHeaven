import 'dart:convert';
import 'package:flutter/material.dart';
import 'drawing_stroke.dart';

/// Core note data model.
///
/// [color] is the note background, stored as a `#RRGGBB` hex string.
/// [titleColor] / [contentColor] are stored as ARGB32 ints.
class Note {
  final String id;
  String title;
  String content;
  DateTime createdAt;
  DateTime modifiedAt;
  List<String> images;
  String color;
  List<String> audioRecordings;
  List<DrawingStroke> drawings;
  int titleColor;
  int contentColor;
  bool isPinned;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.modifiedAt,
    this.images = const [],
    this.color = '#FFFFFF',
    this.audioRecordings = const [],
    this.drawings = const [],
    this.titleColor = 0xFF000000,
    this.contentColor = 0xFF000000,
    this.isPinned = false,
  });

  bool get hasAttachments =>
      images.isNotEmpty || audioRecordings.isNotEmpty || drawings.isNotEmpty;

  bool get isEmpty =>
      title.trim().isEmpty &&
      content.trim().isEmpty &&
      !hasAttachments;

  Note copyWith({
    String? title,
    String? content,
    DateTime? modifiedAt,
    List<String>? images,
    String? color,
    List<String>? audioRecordings,
    List<DrawingStroke>? drawings,
    int? titleColor,
    int? contentColor,
    bool? isPinned,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      images: images ?? this.images,
      color: color ?? this.color,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      drawings: drawings ?? this.drawings,
      titleColor: titleColor ?? this.titleColor,
      contentColor: contentColor ?? this.contentColor,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  /// JSON used for peer-to-peer sharing over the network.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'images': images,
        'color': color,
        'audioRecordings': audioRecordings,
        'drawings': drawings.map((d) => d.toJson()).toList(),
        'titleColor': titleColor,
        'contentColor': contentColor,
        'isPinned': isPinned,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return Note(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      createdAt: _parseDate(json['createdAt'] ?? json['timestamp'], now),
      modifiedAt: _parseDate(json['modifiedAt'] ?? json['timestamp'], now),
      images: _stringList(json['images']),
      color: json['color']?.toString() ?? '#FFFFFF',
      audioRecordings: _stringList(json['audioRecordings']),
      drawings: _drawingList(json['drawings']),
      titleColor: _colorInt(json['titleColor']),
      contentColor: _colorInt(json['contentColor']),
      isPinned: json['isPinned'] == true || json['isPinned'] == 1,
    );
  }

  /// Row map for SQLite persistence (drawings encoded as a JSON string).
  Map<String, dynamic> toDbMap() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'color': color,
        'titleColor': titleColor,
        'contentColor': contentColor,
        'images': images.join('\n'),
        'audioRecordings': audioRecordings.join('\n'),
        'drawings': jsonEncode(drawings.map((d) => d.toJson()).toList()),
        'isPinned': isPinned ? 1 : 0,
      };

  factory Note.fromDbMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return Note(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      createdAt: _parseDate(map['createdAt'], now),
      modifiedAt: _parseDate(map['modifiedAt'] ?? map['timestamp'], now),
      color: map['color']?.toString() ?? '#FFFFFF',
      titleColor: _colorInt(map['titleColor']),
      contentColor: _colorInt(map['contentColor']),
      images: _splitPaths(map['images']),
      audioRecordings: _splitPaths(map['audioRecordings']),
      drawings: _decodeDrawings(map['drawings']),
      isPinned: (map['isPinned'] as int? ?? 0) == 1,
    );
  }

  static DateTime _parseDate(dynamic value, DateTime fallback) {
    if (value == null) return fallback;
    return DateTime.tryParse(value.toString()) ?? fallback;
  }

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    return <String>[];
  }

  // Paths are joined with a NUL separator so that file paths containing commas
  // (legacy data used commas) never split incorrectly. Falls back to comma
  // splitting for rows written by older versions of the app.
  static List<String> _splitPaths(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return <String>[];
    final separator = raw.contains('\n') ? '\n' : ',';
    return raw.split(separator).where((s) => s.isNotEmpty).toList();
  }

  static List<DrawingStroke> _drawingList(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .map(DrawingStroke.fromJson)
          .toList();
    }
    return <DrawingStroke>[];
  }

  static List<DrawingStroke> _decodeDrawings(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.isEmpty) return <DrawingStroke>[];
    try {
      return _drawingList(jsonDecode(raw));
    } catch (_) {
      return <DrawingStroke>[];
    }
  }

  static int _colorInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value?.toString();
    if (raw == null || raw.isEmpty) return 0xFF000000;
    return int.tryParse(raw) ??
        int.tryParse(raw.replaceFirst('0x', ''), radix: 16) ??
        0xFF000000;
  }

  Color get titleColorValue => Color(titleColor);
  Color get contentColorValue => Color(contentColor);
}
