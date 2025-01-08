import 'package:flutter/material.dart';
import 'dart:ui';

class DrawingPoint {
  Offset point;
  Paint paint;
  DrawingPoint({required this.point, required this.paint});
}

class DrawingCanvas extends StatefulWidget {
  final Color selectedColor;
  final double strokeWidth;
  final Function(List<DrawingPoint>) onDrawingComplete;
  final Color backgroundColor;

  const DrawingCanvas({
    super.key,
    required this.selectedColor,
    this.strokeWidth = 3,
    required this.onDrawingComplete,
    this.backgroundColor = Colors.white,
  });

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  List<DrawingPoint> points = [];
  late Size _canvasSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanStart: (details) {
            setState(() {
              points.add(
                DrawingPoint(
                  point: details.localPosition,
                  paint: Paint()
                    ..color = widget.selectedColor
                    ..isAntiAlias = true
                    ..strokeWidth = widget.strokeWidth
                    ..strokeCap = StrokeCap.round,
                ),
              );
            });
          },
          onPanUpdate: (details) {
            setState(() {
              points.add(
                DrawingPoint(
                  point: details.localPosition,
                  paint: Paint()
                    ..color = widget.selectedColor
                    ..isAntiAlias = true
                    ..strokeWidth = widget.strokeWidth
                    ..strokeCap = StrokeCap.round,
                ),
              );
            });
          },
          onPanEnd: (details) {
            widget.onDrawingComplete(points);
          },
          child: CustomPaint(
            painter: _DrawingPainter(points: points),
            size: _canvasSize,
          ),
        );
      },
    );
  }
}

class _DrawingPainter extends CustomPainter {
  final List<DrawingPoint> points;
  _DrawingPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(
        points[i].point,
        points[i + 1].point,
        points[i].paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DrawingDisplayPainter extends CustomPainter {
  final List<DrawingPoint> points;
  DrawingDisplayPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(
        points[i].point,
        points[i + 1].point,
        points[i].paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
