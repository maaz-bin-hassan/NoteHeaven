import 'package:flutter_test/flutter_test.dart';
import 'package:noteheaven/models/note.dart';
import 'package:noteheaven/models/drawing_stroke.dart';

void main() {
  Note sample() => Note(
        id: 'abc',
        title: 'Title',
        content: 'Body line 1\nBody line 2',
        createdAt: DateTime.parse('2024-01-01T10:00:00.000'),
        modifiedAt: DateTime.parse('2024-02-02T12:00:00.000'),
        images: const ['/data/app/with space/img,1.png', '/data/app/img2.jpg'],
        audioRecordings: const ['/data/app/rec1.m4a'],
        drawings: const [
          DrawingStroke(
            points: [Offset(1, 2), Offset(3, 4)],
            color: 0xFF112233,
            strokeWidth: 5,
          ),
        ],
        color: '#FFE5EC',
        titleColor: 0xFFB3261E,
        contentColor: 0xFF1565C0,
        isPinned: true,
      );

  group('DrawingStroke', () {
    test('round-trips through JSON', () {
      const stroke = DrawingStroke(
        points: [Offset(1.5, 2.5), Offset(9, 10)],
        color: 0xFF00FF00,
        strokeWidth: 7,
        isEraser: true,
      );
      final restored = DrawingStroke.fromJson(stroke.toJson());
      expect(restored.points, stroke.points);
      expect(restored.color, stroke.color);
      expect(restored.strokeWidth, stroke.strokeWidth);
      expect(restored.isEraser, isTrue);
    });
  });

  group('Note JSON (network share)', () {
    test('round-trips all fields including drawings', () {
      final note = sample();
      final restored = Note.fromJson(note.toJson());
      expect(restored.id, note.id);
      expect(restored.title, note.title);
      expect(restored.content, note.content);
      expect(restored.images, note.images);
      expect(restored.audioRecordings, note.audioRecordings);
      expect(restored.color, note.color);
      expect(restored.titleColor, note.titleColor);
      expect(restored.contentColor, note.contentColor);
      expect(restored.isPinned, isTrue);
      expect(restored.drawings.length, 1);
      expect(restored.drawings.first.color, 0xFF112233);
    });
  });

  group('Note DB map', () {
    test('round-trips and preserves paths containing commas/spaces', () {
      final note = sample();
      final restored = Note.fromDbMap(note.toDbMap());
      expect(restored.images, note.images);
      expect(restored.audioRecordings, note.audioRecordings);
      expect(restored.drawings.first.points.length, 2);
      expect(restored.isPinned, isTrue);
      expect(restored.titleColor, 0xFFB3261E);
    });

    test('reads legacy comma-separated media paths', () {
      final restored = Note.fromDbMap({
        'id': 'x',
        'title': 't',
        'content': 'c',
        'createdAt': '2024-01-01T00:00:00.000',
        'modifiedAt': '2024-01-01T00:00:00.000',
        'color': '#FFFFFF',
        'titleColor': 0xFF000000,
        'contentColor': 0xFF000000,
        'images': '/a/one.png,/a/two.png',
        'audioRecordings': '',
        'drawings': '',
        'isPinned': 0,
      });
      expect(restored.images, ['/a/one.png', '/a/two.png']);
      expect(restored.audioRecordings, isEmpty);
      expect(restored.drawings, isEmpty);
      expect(restored.isPinned, isFalse);
    });

    test('tolerates missing/garbage fields without throwing', () {
      final restored = Note.fromDbMap({'id': 'only-id'});
      expect(restored.id, 'only-id');
      expect(restored.title, '');
      expect(restored.titleColor, 0xFF000000);
      expect(restored.drawings, isEmpty);
    });
  });

  group('Note helpers', () {
    test('isEmpty / hasAttachments', () {
      final empty = Note(
        id: '1',
        title: '   ',
        content: '',
        createdAt: DateTime(2024),
        modifiedAt: DateTime(2024),
      );
      expect(empty.isEmpty, isTrue);
      expect(empty.hasAttachments, isFalse);
      expect(sample().hasAttachments, isTrue);
      expect(sample().isEmpty, isFalse);
    });

    test('copyWith keeps identity but updates fields', () {
      final updated = sample().copyWith(title: 'New', isPinned: false);
      expect(updated.id, 'abc');
      expect(updated.title, 'New');
      expect(updated.isPinned, isFalse);
      expect(updated.content, sample().content);
    });
  });
}
