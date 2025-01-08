import 'package:flutter/material.dart';
import '../widgets/drawing_canvas.dart';

class DrawingPreviewScreen extends StatelessWidget {
  final List<DrawingPoint> drawings;

  const DrawingPreviewScreen({
    super.key,
    required this.drawings,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        color: Colors.white,
        child: Hero(
          tag: 'drawing-preview',
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: CustomPaint(
              painter: DrawingDisplayPainter(points: drawings),
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
