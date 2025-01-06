import 'package:flutter/material.dart';
import '../widgets/drawing_canvas.dart';

class DrawingScreen extends StatefulWidget {
  final List<DrawingPoint> initialDrawings;
  final Function(List<DrawingPoint>) onDrawingComplete;

  const DrawingScreen({
    super.key,
    this.initialDrawings = const [],
    required this.onDrawingComplete,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  Color _selectedColor = Colors.black;
  double _strokeWidth = 3.0;
  late List<DrawingPoint> _drawings;

  @override
  void initState() {
    super.initState();
    _drawings = List.from(widget.initialDrawings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              widget.onDrawingComplete(_drawings);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Color picker section
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Colors.black,
                        Colors.red,
                        Colors.blue,
                        Colors.green,
                        Colors.yellow,
                        Colors.purple,
                      ]
                          .map((color) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedColor = color),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _selectedColor == color
                                            ? Colors.white
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        if (_selectedColor == color)
                                          BoxShadow(
                                            color: color.withOpacity(0.3),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                // Stroke width slider section
                Expanded(
                  flex: 1,
                  child: Slider(
                    value: _strokeWidth,
                    min: 1,
                    max: 10,
                    onChanged: (value) => setState(() => _strokeWidth = value),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: DrawingCanvas(
                selectedColor: _selectedColor,
                strokeWidth: _strokeWidth,
                backgroundColor: Colors.white,
                onDrawingComplete: (points) {
                  _drawings = points;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
