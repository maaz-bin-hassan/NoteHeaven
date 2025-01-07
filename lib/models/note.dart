import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  final String id;
  String title;
  String content;
  String userId;
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
    required this.userId,
    required this.timestamp,
    required this.createdAt,
    required this.modifiedAt,
    this.images = const [],
    this.color = '#FFFFFF',
    this.audioRecordings = const [],
    this.titleColor = Colors.black,
    this.contentColor = Colors.black,
  });

  // Convert Note to JSON
  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'userId': userId,
        'timestamp': timestamp,
        'createdAt': createdAt,
        'modifiedAt': modifiedAt,
        'images': images,
        'color': color,
        'audioRecordings': audioRecordings,
        'titleColor': titleColor.value,
        'contentColor': contentColor.value,
      };

  // Create Note from JSON
  factory Note.fromJson(Map<String, dynamic> json) {
    // Handle Firestore timestamp
    DateTime parseTimestamp(dynamic timestamp) {
      if (timestamp is Timestamp) {
        return timestamp.toDate();
      } else if (timestamp == null) {
        return DateTime.now();
      }
      return DateTime.now();
    }

    final note = Note(
      id: json['id'] ?? '', // Firestore document ID
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      userId: json['userId'] ?? '',
      timestamp:
          parseTimestamp(json['timestamp']), // Handle Firestore timestamp
      createdAt: parseTimestamp(json['createdAt'] ?? DateTime.now()),
      modifiedAt: parseTimestamp(json['modifiedAt'] ?? DateTime.now()),
      images: List<String>.from(json['images'] ?? []),
      color: json['color'] ?? '#FFFFFF',
      audioRecordings: List<String>.from(json['audioRecordings'] ?? []),
      titleColor: Color(json['titleColor'] ?? Colors.black.value),
      contentColor: Color(json['contentColor'] ?? Colors.black.value),
    );
    debugPrint('Created note from JSON: ${note.title}');
    return note;
  }

  // Add method to get image URL or local path
  String getImageSource(String imagePath) {
    return imagePath.startsWith('http') ? imagePath : imagePath;
  }
}
