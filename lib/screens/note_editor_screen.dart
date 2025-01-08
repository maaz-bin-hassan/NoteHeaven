import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../services/local_auth_service.dart';
import '../widgets/drawing_canvas.dart';
import '../services/audio_service.dart';
import 'drawing_screen.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/image_preview.dart';
import 'drawing_preview_screen.dart';
import '../services/note_share_manager.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final NoteService noteService; // Add this line

  const NoteEditorScreen({
    super.key,
    this.note,
    required this.noteService, // Add this line
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen>
    with SingleTickerProviderStateMixin {
  bool _isSaving = false;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  final List<String> _images = [];
  String _selectedColor = '#FFFFFF';
  // Remove this line as we'll use widget.noteService instead
  // final _noteService = NoteService();
  late AnimationController _colorPickerController;
  bool _isEdited = false;
  List<DrawingPoint> _drawings = [];
  bool _showDrawingCanvas = false;
  final AudioService _audioService = AudioService();
  final List<String> _audioRecordings = [];
  bool _isRecording = false;

  // Add new properties for text colors
  Color _titleColor = Colors.black;
  Color _contentColor = Colors.black;
  bool _isDrawingVisible = false; // Add this property
  final _shareManager = NoteShareManager(); // Add property

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController =
        TextEditingController(text: widget.note?.content ?? '');
    _selectedColor = widget.note?.color ?? '#FFFFFF';
    _titleColor = widget.note?.titleColor ?? Colors.black;
    _contentColor = widget.note?.contentColor ?? Colors.black;

    // Initialize audio recordings from existing note
    if (widget.note?.audioRecordings != null) {
      _audioRecordings.addAll(widget.note!.audioRecordings);
    }
    // Initialize images from existing note
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

  Future<void> _saveNote() async {
    if (_titleController.text.isEmpty) {
      _showError('Please add a title');
      return;
    }

    try {
      setState(() => _isSaving = true); // Set loading state

      final note = Note(
        id: widget.note?.id ??
            const Uuid().v4(), // Generate new UUID for new notes
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        timestamp: DateTime.now(),
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        modifiedAt: DateTime.now(),
        images: _images,
        color: _selectedColor,
        titleColor: _titleColor,
        contentColor: _contentColor,
        audioRecordings: _audioRecordings,
      );

      debugPrint(
          'Saving note with recordings: ${note.audioRecordings}'); // Debug log

      if (widget.note == null) {
        await widget.noteService.addNote(note);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note created successfully')),
          );
        }
      } else {
        await widget.noteService.updateNote(note);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note updated successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving note: $e');
      if (mounted) {
        _showError('Failed to save note: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
          _isEdited = true; // Mark as edited when recording is added
        });
        debugPrint('Added recording: $path'); // Debug log
      }
    }
  }

  void _openDrawingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrawingScreen(
          initialDrawings: _drawings,
          onDrawingComplete: (drawings) {
            setState(() {
              _drawings = drawings;
              _isEdited = true;
            });
          },
        ),
      ),
    );
  }

  void _toggleDrawingVisibility() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrawingPreviewScreen(drawings: _drawings),
      ),
    );
  }

  Widget _buildAudioRecordings() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_audioRecordings.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Recordings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  // Use white text in dark mode
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _audioRecordings.length,
            itemBuilder: (context, index) {
              return AudioPlayerWidget(
                audioPath: _audioRecordings[index],
                audioService: _audioService,
                onDelete: () {
                  setState(() {
                    _audioRecordings.removeAt(index);
                    _isEdited = true;
                  });
                },
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

  // Add color selection method
  void _showTextColorPicker(bool isTitle) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isTitle ? 'Choose Title Color' : 'Choose Text Color',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Colors.black,
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.purple,
                Colors.orange,
                Colors.teal,
                Colors.pink,
                Colors.indigo,
                Colors.amber,
              ]
                  .map((color) => GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isTitle) {
                              _titleColor = color;
                            } else {
                              _contentColor = color;
                            }
                            _isEdited = true;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: (isTitle ? _titleColor : _contentColor) ==
                                      color
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(Color textColor) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title section
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _titleController,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _titleColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.format_color_text_rounded,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                onPressed: () => _showTextColorPicker(true),
                tooltip: 'Change title color',
              ),
            ],
          ),

          // Images section
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                itemBuilder: (context, index) => _buildImageItem(index),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Content section
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _contentController,
                  maxLines: null,
                  style: TextStyle(
                    fontSize: 16,
                    color: _contentColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Start writing...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.format_color_text_rounded,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                onPressed: () => _showTextColorPicker(false),
                tooltip: 'Change text color',
              ),
            ],
          ),

          // Drawings section - simplified
          if (_drawings.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  'Drawing attached',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.visibility_rounded,
                      color: Colors.black87),
                  onPressed: _toggleDrawingVisibility,
                  tooltip: 'View drawing',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_rounded, color: Colors.black87),
                  onPressed: _openDrawingScreen,
                  tooltip: 'Edit drawing',
                ),
              ],
            ),
          ],

          // Audio recordings section
          if (_audioRecordings.isNotEmpty) _buildAudioRecordings(),
        ],
      ),
    );
  }

  Widget _buildImageItem(int index) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreview(imagePath: _images[index]),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: FileImage(File(_images[index])),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await widget.noteService.deleteNote(widget.note!.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          _showError('Failed to delete note: ${e.toString()}');
        }
      }
    }
  }

  Future<void> _shareWithNearby() async {
    if (_titleController.text.isEmpty) {
      _showError('Please add a title before sharing');
      return;
    }

    try {
      setState(() => _isSaving = true);

      final note = Note(
        id: widget.note?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        timestamp: DateTime.now(),
        createdAt: widget.note?.createdAt ?? DateTime.now(),
        modifiedAt: DateTime.now(),
        images: _images,
        color: _selectedColor,
        titleColor: _titleColor,
        contentColor: _contentColor,
        audioRecordings: _audioRecordings,
      );

      await _shareManager.shareNote(note);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note shared with nearby devices')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to share note: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = _getTextColor(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? Theme.of(context).colorScheme.background
        : Color(
            int.parse(_selectedColor.substring(1, 7), radix: 16) + 0xFF000000);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Note'),
          actions: [
            // Change the icon to wifi_tethering or share_arrival_time
            IconButton(
              icon:
                  const Icon(Icons.wifi_tethering), // Changed from nearby_share
              onPressed: _shareWithNearby,
              tooltip: 'Share with nearby devices',
            ),
            if (widget.note != null) // Only show delete for existing notes
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _showDeleteDialog,
                tooltip: 'Delete note',
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _isSaving ? null : _saveNote,
            ),
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () {
                final text =
                    '${_titleController.text}\n\n${_contentController.text}';
                Share.share(text);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            color: backgroundColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(
                    child: _buildMainContent(textColor),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          onPressed: _pickImage,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          tooltip: 'Add Image',
                        ),
                        IconButton(
                          icon: const Icon(Icons.color_lens_rounded),
                          onPressed: _showColorPicker,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          tooltip: 'Change Note Color',
                        ),
                        IconButton(
                          icon: Icon(
                            _isRecording
                                ? Icons.stop_rounded
                                : Icons.mic_rounded,
                            color: _isRecording
                                ? Colors.red
                                : (isDarkMode ? Colors.white : Colors.black87),
                          ),
                          onPressed: _toggleRecording,
                          tooltip:
                              _isRecording ? 'Stop Recording' : 'Record Audio',
                        ),
                        IconButton(
                          icon: const Icon(Icons.draw_rounded),
                          onPressed: _openDrawingScreen,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          tooltip: 'Add Drawing',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
