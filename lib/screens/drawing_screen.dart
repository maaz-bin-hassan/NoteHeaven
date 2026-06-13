import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/drawing_stroke.dart';
import '../widgets/drawing_canvas.dart';

/// Full-screen freehand sketch editor with colours, brush size, eraser, undo
/// and clear. Returns the resulting strokes to the caller.
class DrawingScreen extends StatefulWidget {
  final List<DrawingStroke> initialDrawings;
  final ValueChanged<List<DrawingStroke>> onDrawingComplete;

  const DrawingScreen({
    super.key,
    this.initialDrawings = const [],
    required this.onDrawingComplete,
  });

  @override
  State<DrawingScreen> createState() => _DrawingScreenState();
}

class _DrawingScreenState extends State<DrawingScreen> {
  late List<DrawingStroke> _strokes;
  Color _color = Colors.black;
  double _strokeWidth = 4;
  bool _isEraser = false;

  static const _canvasBg = Colors.white;
  static const _palette = [
    Colors.black,
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFB8C00),
    Color(0xFF8E24AA),
    Color(0xFF00ACC1),
    Color(0xFFEC407A),
  ];

  @override
  void initState() {
    super.initState();
    _strokes = List.of(widget.initialDrawings);
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() => _strokes = []);
  }

  void _save() {
    widget.onDrawingComplete(_strokes);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Sketch'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Cancel',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo_rounded),
            onPressed: _strokes.isEmpty ? null : _undo,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: _strokes.isEmpty ? null : _clear,
            tooltip: 'Clear',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _canvasBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: DrawingCanvas(
                strokes: _strokes,
                color: _color,
                strokeWidth: _strokeWidth,
                isEraser: _isEraser,
                backgroundColor: _canvasBg,
                onStrokeEnd: (stroke) => setState(() => _strokes.add(stroke)),
              ),
            ),
          ),
          _buildToolbar(scheme),
        ],
      ),
    );
  }

  Widget _buildToolbar(ColorScheme scheme) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in _palette) _colorDot(c),
                  const SizedBox(width: 8),
                  _eraserButton(scheme),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.line_weight_rounded, size: 20),
                Expanded(
                  child: Slider(
                    value: _strokeWidth,
                    min: 1,
                    max: 24,
                    onChanged: (v) => setState(() => _strokeWidth = v),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Center(
                    child: Container(
                      width: _strokeWidth.clamp(2, 24),
                      height: _strokeWidth.clamp(2, 24),
                      decoration: BoxDecoration(
                        color: _isEraser ? scheme.outline : _color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(Color color) {
    final selected = !_isEraser && _color.toARGB32() == color.toARGB32();
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _color = color;
          _isEraser = false;
        });
      },
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.black12,
            width: selected ? 3 : 1,
          ),
        ),
      ),
    );
  }

  Widget _eraserButton(ColorScheme scheme) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _isEraser = true);
      },
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isEraser ? scheme.primary : Colors.black12,
            width: _isEraser ? 3 : 1,
          ),
        ),
        child: Icon(Icons.cleaning_services_rounded,
            size: 18, color: scheme.onSurfaceVariant),
      ),
    );
  }
}
