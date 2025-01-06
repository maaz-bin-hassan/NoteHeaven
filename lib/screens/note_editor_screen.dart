import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../widgets/drawing_canvas.dart';
import '../services/audio_service.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final List<String> _images = [];
  String _selectedColor = '#FFFFFF';
  final _noteService = NoteService();
  late AnimationController _colorPickerController;
  bool _isEdited = false;
  Color _drawingColor = Colors.black;
  double _strokeWidth = 3.0;
  List<DrawingPoint> _drawings = [];
  bool _isDrawingMode = false;
  final AudioService _audioService = AudioService();
  final List<String> _audioRecordings = [];
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _selectedColor = widget.note?.color ?? '#FFFFFF';
    if (widget.note?.images != null) {
      _images.addAll(widget.note!.images);
    }

    _colorPickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _titleController.addListener(_markAsEdited);
    _contentController.addListener(_markAsEdited);
  }

  void _markAsEdited() {
    setState(() => _isEdited = true);
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _images.add(image.path);
          _isEdited = true;
        });
      }
    } catch (e) {
      _showError('Failed to pick image');
    }
  }

  void _showColorPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => AnimatedBuilder(
        animation: _colorPickerController,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          transform: Matrix4.translationValues(
            0,
            50 * (1 - _colorPickerController.value),
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(
                'Choose Note Color',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  '#FFFFFF',
                  '#F8D7DA',
                  '#D4EDDA',
                  '#CCE5FF',
                  '#FFF3CD',
                  '#E2E3E5',
                ].map(_buildColorButton).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ).then((_) => _colorPickerController.reverse());
    _colorPickerController.forward();
  }

  Widget _buildColorButton(String color) {
    final bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          _selectedColor = color;
          _isEdited = true;
        });
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 50,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color:
              Color(int.parse(color.substring(1, 7), radix: 16) + 0xFF000000),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_isEdited) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('Do you want to save your changes before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              _saveNote();
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _saveNote() {
    if (_titleController.text.isEmpty) {
      _showError('Please add a title');
      return;
    }

    try {
      if (widget.note == null) {
        _noteService.addNote(
          _titleController.text,
          _contentController.text,
          _selectedColor,
          _images,
        );
      } else {
        _noteService.updateNote(
          Note(
            id: widget.note!.id,
            title: _titleController.text,
            content: _contentController.text,
            createdAt: widget.note!.createdAt,
            modifiedAt: DateTime.now(),
            images: _images,
            color: _selectedColor,
          ),
        );
      }
      Navigator.pop(context);
    } catch (e) {
      _showError('Failed to save note');
    }
  }

  void _toggleDrawingMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
    });
    if (!_isDrawingMode) {
      _isEdited = true;
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      final path = await _audioService.startRecording();
      if (path != null) {
        setState(() {
          _isRecording = true;
          _isEdited = true;
        });
      } else {
        _showError('Failed to start recording');
      }
    } else {
      final path = await _audioService.stopRecording();
      if (path != null) {
        setState(() {
          _audioRecordings.add(path);
          _isRecording = false;
        });
      }
    }
  }

  Widget _buildColorPicker() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.5,
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
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () => setState(() => _drawingColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _drawingColor == color
                                ? Colors.white
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildStrokeWidthSlider() {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.3,
      child: Slider(
        value: _strokeWidth,
        min: 1,
        max: 10,
        onChanged: (value) => setState(() => _strokeWidth = value),
      ),
    );
  }

  Widget _buildDrawingTools() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Drawing Tools',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildColorPicker(),
                    _buildStrokeWidthSlider(),
                  ],
                ),
              ],
            ),
          ),
          DrawingCanvas(
            selectedColor: _drawingColor,
            strokeWidth: _strokeWidth,
            height: MediaQuery.of(context).size.height * 0.4,
            backgroundColor: Colors.white,
            onDrawingComplete: (points) {
              _drawings = points;
              setState(() => _isEdited = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAudioRecordings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_audioRecordings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Recordings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _audioRecordings.length,
            itemBuilder: (context, index) {
              return Card(
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(
                      _audioService.isPlaying ? Icons.stop : Icons.play_arrow,
                    ),
                    onPressed: () async {
                      if (_audioService.isPlaying) {
                        await _audioService.stopPlaying();
                      } else {
                        await _audioService
                            .playRecording(_audioRecordings[index]);
                      }
                      setState(() {});
                    },
                  ),
                  title: Text('Recording ${index + 1}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () {
                      setState(() {
                        _audioRecordings.removeAt(index);
                        _isEdited = true;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  Color _getDarkerColor(Color baseColor) {
    final HSLColor hsl = HSLColor.fromColor(baseColor);
    return hsl.withLightness((hsl.lightness * 0.8).clamp(0.0, 1.0)).toColor();
  }

  Color _getTextColor(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    if (isDarkMode) {
      return Colors.white;
    }

    final backgroundColorInt =
        int.parse(_selectedColor.substring(1, 7), radix: 16) + 0xFF000000;
    final backgroundColor = Color(backgroundColorInt);
    final backgroundBrightness = backgroundColor.computeLuminance();
    return backgroundBrightness > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = Color(
        int.parse(_selectedColor.substring(1, 7), radix: 16) + 0xFF000000);
    final backgroundColor = isDarkMode ? _getDarkerColor(baseColor) : baseColor;
    final textColor = _getTextColor(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: textColor),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _onWillPop()) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.save, color: textColor),
              onPressed: _saveNote,
              tooltip: 'Save note',
            ),
            IconButton(
              icon: Icon(Icons.share, color: textColor),
              onPressed: () {
                HapticFeedback.lightImpact();
                final text =
                    '${_titleController.text}\n\n${_contentController.text}';
                Share.share(text);
              },
              tooltip: 'Share note',
            ),
            IconButton(
              icon: Icon(Icons.image, color: textColor),
              onPressed: _pickImage,
              tooltip: 'Add image',
            ),
            IconButton(
              icon: Icon(Icons.color_lens, color: textColor),
              onPressed: _showColorPicker,
              tooltip: 'Change color',
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                backgroundColor,
                backgroundColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ),
                if (_images.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _images.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(_images[index]),
                                  height: 100,
                                  width: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () {
                                  setState(() {
                                    _images.removeAt(index);
                                    _isEdited = true;
                                  });
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(4),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                if (!_isDrawingMode) ...[
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    style: TextStyle(
                      fontSize: 16,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start writing...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ),
                ] else ...[
                  _buildDrawingTools(),
                ],
                if (_drawings.isNotEmpty && !_isDrawingMode)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CustomPaint(
                      painter: DrawingDisplayPainter(points: _drawings),
                      size: const Size(double.infinity, 200),
                    ),
                  ),
                if (_audioRecordings.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _buildAudioRecordings(),
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(_isDrawingMode ? Icons.edit : Icons.draw),
                onPressed: _toggleDrawingMode,
                tooltip:
                    _isDrawingMode ? 'Switch to text' : 'Switch to drawing',
                color: Theme.of(context).colorScheme.primary,
              ),
              IconButton(
                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                onPressed: _toggleRecording,
                color: _isRecording
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary,
                tooltip: _isRecording ? 'Stop recording' : 'Start recording',
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _colorPickerController.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
