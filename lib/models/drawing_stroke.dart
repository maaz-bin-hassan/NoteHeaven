import 'dart:ui';

/// A single continuous stroke (pen-down to pen-up) on the drawing canvas.
///
/// Storing strokes as a list of points — rather than a flat list of points
/// with a [Paint] each — fixes two problems with the old model:
///   * It is fully JSON-serializable, so drawings can be persisted with a note.
///   * Lifting the pen starts a new stroke, so separate strokes are no longer
///     joined by a stray connecting line.
class DrawingStroke {
  final List<Offset> points;
  final int color; // ARGB32
  final double strokeWidth;
  final bool isEraser;

  const DrawingStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });

  Map<String, dynamic> toJson() => {
        'points': points
            .map((p) => {'x': p.dx, 'y': p.dy})
            .toList(growable: false),
        'color': color,
        'strokeWidth': strokeWidth,
        'isEraser': isEraser,
      };

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    final rawPoints = (json['points'] as List<dynamic>? ?? const []);
    return DrawingStroke(
      points: rawPoints
          .map((p) => Offset(
                (p['x'] as num?)?.toDouble() ?? 0,
                (p['y'] as num?)?.toDouble() ?? 0,
              ))
          .toList(),
      color: (json['color'] as num?)?.toInt() ?? 0xFF000000,
      strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 3.0,
      isEraser: json['isEraser'] as bool? ?? false,
    );
  }
}
