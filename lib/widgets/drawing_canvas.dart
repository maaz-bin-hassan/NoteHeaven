import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';

/// Paints a list of completed [DrawingStroke]s (plus an optional in-progress
/// stroke). Used by the canvas, the editor thumbnail and the full-screen
/// preview so they always render identically.
class StrokePainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? active;
  final Color eraseColor;

  StrokePainter({
    required this.strokes,
    this.active,
    this.eraseColor = Colors.white,
  });

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;
    final paint = Paint()
      ..color = stroke.isEraser ? eraseColor : Color(stroke.color)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (stroke.points.length == 1) {
      // A tap: draw a dot.
      canvas.drawCircle(
        stroke.points.first,
        stroke.strokeWidth / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }

    final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (var i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    if (active != null) _drawStroke(canvas, active!);
  }

  @override
  bool shouldRepaint(covariant StrokePainter old) =>
      old.strokes != strokes || old.active != active;
}

/// Interactive freehand drawing surface. Completed strokes are owned by the
/// parent (so undo/clear are trivial); this widget only tracks the stroke
/// currently being drawn and reports it on pen-up.
class DrawingCanvas extends StatefulWidget {
  final List<DrawingStroke> strokes;
  final Color color;
  final double strokeWidth;
  final bool isEraser;
  final Color backgroundColor;
  final ValueChanged<DrawingStroke> onStrokeEnd;

  const DrawingCanvas({
    super.key,
    required this.strokes,
    required this.color,
    required this.strokeWidth,
    required this.onStrokeEnd,
    this.isEraser = false,
    this.backgroundColor = Colors.white,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<Offset> _current = [];

  DrawingStroke? get _activeStroke => _current.isEmpty
      ? null
      : DrawingStroke(
          points: List.of(_current),
          color: widget.color.toARGB32(),
          strokeWidth: widget.isEraser ? widget.strokeWidth * 2.5 : widget.strokeWidth,
          isEraser: widget.isEraser,
        );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => setState(() => _current = [d.localPosition]),
      onPanUpdate: (d) => setState(() => _current = [..._current, d.localPosition]),
      onPanEnd: (_) {
        final stroke = _activeStroke;
        if (stroke != null) widget.onStrokeEnd(stroke);
        setState(() => _current = []);
      },
      child: CustomPaint(
        painter: StrokePainter(
          strokes: widget.strokes,
          active: _activeStroke,
          eraseColor: widget.backgroundColor,
        ),
        size: Size.infinite,
      ),
    );
  }
}
