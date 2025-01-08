import 'package:flutter/material.dart';

class Note {
  final String id;
  String title;
  String content;
  DateTime timestamp;
  DateTime createdAt;
  DateTime modifiedAt;
  List<String> images;
  String color;
  List<String> audioRecordings;
  Color titleColor;
  Color contentColor;

  Note({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    required this.createdAt,
    required this.modifiedAt,
    this.images = const [],
    this.color = '#FFFFFF',
    this.audioRecordings = const [],
    this.titleColor = Colors.black,
    this.contentColor = Colors.black,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        'images': images,
        'color': color,
        'audioRecordings': audioRecordings,
        'titleColor': titleColor.value,
        'contentColor': contentColor.value,
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      modifiedAt: DateTime.parse(
          json['modifiedAt'] ?? DateTime.now().toIso8601String()),
      images: List<String>.from(json['images'] ?? []),
      color: json['color'] ?? '#FFFFFF',
      audioRecordings: List<String>.from(json['audioRecordings'] ?? []),
      titleColor: Color(json['titleColor'] ?? Colors.black.value),
      contentColor: Color(json['contentColor'] ?? Colors.black.value),
    );
  }
}
