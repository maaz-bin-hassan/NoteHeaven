import 'package:flutter/material.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing_canvas.dart';

/// Read-only, zoomable view of a saved sketch.
class DrawingPreviewScreen extends StatelessWidget {
  final List<DrawingStroke> drawings;

  const DrawingPreviewScreen({super.key, required this.drawings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sketch')),
      body: Container(
        color: Colors.white,
        child: Hero(
          tag: 'drawing-preview',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: CustomPaint(
              painter: StrokePainter(strokes: drawings),
              size: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height - kToolbarHeight,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
