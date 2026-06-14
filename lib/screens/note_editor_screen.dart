import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../models/drawing_stroke.dart';
import '../services/note_service.dart';
import '../services/audio_service.dart';
import '../services/note_share_manager.dart';
import '../services/deepseek_service.dart';
import '../theme/app_palette.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/image_preview.dart';
import 'drawing_screen.dart';
import 'drawing_preview_screen.dart';

class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  final NoteService noteService;

  const NoteEditorScreen({
    super.key,
    this.note,
    required this.noteService,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  final _images = <String>[];
  final _audioRecordings = <String>[];
  var _drawings = <DrawingStroke>[];
  String _selectedColor = '#FFFFFF';
  int _titleColor = 0xFF000000;
  int _contentColor = 0xFF000000;
  bool _isPinned = false;

  final AudioService _audioService = AudioService();
  final _shareManager = NoteShareManager();
  final DeepSeekService _deepSeek = DeepSeekService();

  bool _isEdited = false;
  bool _isSaving = false;
  bool _isRecording = false;
  bool _isAiProcessing = false;
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTimer;

  bool get _isNew => widget.note == null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _selectedColor = note?.color ?? '#FFFFFF';
    _titleColor = note?.titleColor ?? 0xFF000000;
    _contentColor = note?.contentColor ?? 0xFF000000;
    _isPinned = note?.isPinned ?? false;
    if (note != null) {
      _images.addAll(note.images);
      _audioRecordings.addAll(note.audioRecordings);
      _drawings = List.of(note.drawings);
    }
    _titleController.addListener(_markEdited);
    _contentController.addListener(_markEdited);
  }

  void _markEdited() {
    if (!_isEdited) setState(() => _isEdited = true);
  }

  // ---------------------------------------------------------------- helpers

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Note _buildNote() {
    var title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty) {
      title = content.isNotEmpty
          ? content.split('\n').first.trim()
          : 'Untitled';
      if (title.length > 60) title = '${title.substring(0, 60)}…';
    }
    return Note(
      id: widget.note?.id ?? const Uuid().v4(),
      title: title,
      content: content,
      createdAt: widget.note?.createdAt ?? DateTime.now(),
      modifiedAt: DateTime.now(),
      images: List.of(_images),
      audioRecordings: List.of(_audioRecordings),
      drawings: List.of(_drawings),
      color: _selectedColor,
      titleColor: _titleColor,
      contentColor: _contentColor,
      isPinned: _isPinned,
    );
  }

  bool get _isBlank =>
      _titleController.text.trim().isEmpty &&
      _contentController.text.trim().isEmpty &&
      _images.isEmpty &&
      _audioRecordings.isEmpty &&
      _drawings.isEmpty;

  /// Saves the note. Returns true if it is safe to leave the screen.
  Future<bool> _saveNote() async {
    if (_isBlank) {
      // Nothing worth keeping — leave without creating an empty note.
      return true;
    }
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    try {
      final note = _buildNote();
      if (_isNew) {
        await widget.noteService.addNote(note);
      } else {
        await widget.noteService.updateNote(note);
      }
      _showMessage(_isNew ? 'Note created' : 'Note saved');
      return true;
    } catch (e) {
      _showMessage('Failed to save note');
      debugPrint('Save error: $e');
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _onSavePressed() async {
    if (await _saveNote() && mounted) Navigator.pop(context);
  }

  Future<void> _handleBack() async {
    if (!_isEdited) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('Keep your changes to this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted || action == null || action == 'cancel') return;
    if (action == 'discard') {
      Navigator.pop(context);
    } else if (action == 'save') {
      await _onSavePressed();
    }
  }

  // ---------------------------------------------------------------- media

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        setState(() {
          _images.add(picked.path);
          _isEdited = true;
        });
      }
    } catch (e) {
      _showMessage('Failed to pick image');
    }
  }

  Future<void> _toggleRecording() async {
    if (!_isRecording) {
      final path = await _audioService.startRecording();
      if (path == null) {
        _showMessage('Microphone permission is required to record');
        return;
      }
      setState(() {
        _isRecording = true;
        _isEdited = true;
        _recordElapsed = Duration.zero;
      });
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordElapsed += const Duration(seconds: 1));
        }
      });
    } else {
      _recordTimer?.cancel();
      final path = await _audioService.stopRecording();
      setState(() {
        _isRecording = false;
        if (path != null) _audioRecordings.add(path);
      });
      if (path == null) _showMessage('Recording failed');
    }
  }

  Future<void> _openDrawing() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrawingScreen(
          initialDrawings: _drawings,
          onDrawingComplete: (strokes) =>
              setState(() {
            _drawings = strokes;
            _isEdited = true;
          }),
        ),
      ),
    );
  }

  void _previewDrawing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrawingPreviewScreen(drawings: _drawings),
      ),
    );
  }

  // ---------------------------------------------------------------- sharing

  Future<void> _shareAsText() async {
    final note = _buildNote();
    final buffer = StringBuffer()
      ..writeln(note.title)
      ..writeln()
      ..write(note.content);
    final files =
        _images.where((p) => File(p).existsSync()).map((p) => XFile(p)).toList();
    try {
      await SharePlus.instance.share(
        ShareParams(text: buffer.toString(), files: files.isEmpty ? null : files),
      );
    } catch (e) {
      _showMessage('Could not open share sheet');
    }
  }

  Future<void> _shareNearby() async {
    if (_isBlank) {
      _showMessage('Add something to the note before sharing');
      return;
    }
    _showMessage('Looking for nearby devices…');
    try {
      final ok = await _shareManager.shareNote(_buildNote());
      _showMessage(ok ? 'Note sent to nearby devices' : 'No nearby devices found');
    } catch (e) {
      _showMessage('Failed to share note');
    }
  }

  // ---------------------------------------------------------------- AI

  Future<void> _runAi(String instruction) async {
    if (instruction.trim().isEmpty) return;
    setState(() => _isAiProcessing = true);
    try {
      final context = _contentController.text.trim();
      final result = await _deepSeek.chat(
        systemMessage:
            'You are a concise writing assistant inside a note-taking app. '
            'Return only the requested text with no preamble.',
        userMessage: context.isEmpty
            ? instruction
            : '$instruction\n\n---\nNote content:\n$context',
      );
      _insertAtCursor(result);
      setState(() => _isEdited = true);
    } on AiUnconfiguredException {
      _showMessage('AI is disabled — no API key configured');
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isAiProcessing = false);
    }
  }

  void _insertAtCursor(String text) {
    final controller = _contentController;
    final value = controller.value;
    final sel = value.selection;
    final base = value.text;
    final prefix = base.isEmpty || base.endsWith('\n') ? '' : '\n';
    final insertion = '$prefix$text';
    if (sel.isValid) {
      final newText = base.replaceRange(sel.start, sel.end, insertion);
      controller.value = TextEditingValue(
        text: newText,
        selection:
            TextSelection.collapsed(offset: sel.start + insertion.length),
      );
    } else {
      final newText = base + insertion;
      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    }
  }

  void _openAiSheet() {
    if (!_deepSeek.isConfigured) {
      _showMessage('AI is disabled — set AI_PROXY_URL to enable it');
      return;
    }
    final promptController = TextEditingController();
    const actions = <(String, String, IconData)>[
      ('Summarize', 'Summarize this note in a few bullet points.', Icons.subject_rounded),
      ('Improve', 'Rewrite this note to be clearer and better structured.', Icons.auto_fix_high_rounded),
      ('Fix grammar', 'Fix spelling and grammar in this note. Keep the meaning.', Icons.spellcheck_rounded),
      ('Continue', 'Continue writing this note naturally from where it ends.', Icons.notes_rounded),
      ('To list', 'Turn this note into a clear checklist.', Icons.checklist_rounded),
    ];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Theme.of(sheetContext).colorScheme.primary),
                const SizedBox(width: 8),
                Text('AI assistant',
                    style: Theme.of(sheetContext).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, prompt, icon) in actions)
                  ActionChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _runAi(prompt);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: promptController,
              autofocus: false,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              decoration: InputDecoration(
                hintText: 'Ask AI anything…',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () {
                    final text = promptController.text;
                    Navigator.pop(sheetContext);
                    _runAi(text);
                  },
                ),
              ),
              onSubmitted: (text) {
                Navigator.pop(sheetContext);
                _runAi(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- colours

  void _showNoteColorPicker() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Note colour',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final hex in AppPalette.noteColors)
                  _swatch(
                    AppPalette.fromHex(hex),
                    selected: _selectedColor == hex,
                    onTap: () {
                      setState(() {
                        _selectedColor = hex;
                        _isEdited = true;
                      });
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTextColorPicker({required bool isTitle}) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isTitle ? 'Title colour' : 'Text colour',
                style: Theme.of(sheetContext).textTheme.titleLarge),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final color in AppPalette.textColors)
                  _swatch(
                    color,
                    selected: (isTitle ? _titleColor : _contentColor) ==
                        color.toARGB32(),
                    onTap: () {
                      setState(() {
                        if (isTitle) {
                          _titleColor = color.toARGB32();
                        } else {
                          _contentColor = color.toARGB32();
                        }
                        _isEdited = true;
                      });
                      Navigator.pop(sheetContext);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(Color color,
      {required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(Icons.check, color: AppPalette.onColor(color), size: 20)
            : null,
      ),
    );
  }

  Color _legible(int chosen, Color background, Color fallback) {
    if (chosen == 0xFF000000) return fallback; // user left the default
    final c = Color(chosen);
    final diff = (c.computeLuminance() - background.computeLuminance()).abs();
    return diff < 0.25 ? fallback : c;
  }

  // ---------------------------------------------------------------- delete

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This note will be moved out of your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Remove now (media retained) and return the note so the home screen can
      // offer an Undo before the files are purged.
      await widget.noteService.removeNote(widget.note!.id);
      if (mounted) Navigator.pop(context, widget.note);
    }
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    final background = AppPalette.resolve(_selectedColor, brightness);
    final onBackground = AppPalette.onColor(background);
    final titleColor = _legible(_titleColor, background, onBackground);
    final contentColor = _legible(_contentColor, background, onBackground);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          backgroundColor: background,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: onBackground),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _handleBack,
          ),
          actions: [
            if (_isAiProcessing)
              const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.auto_awesome_rounded),
                tooltip: 'AI assistant',
                color: onBackground,
                onPressed: _openAiSheet,
              ),
            IconButton(
              icon: Icon(_isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined),
              tooltip: _isPinned ? 'Unpin' : 'Pin',
              color: onBackground,
              onPressed: () => setState(() {
                _isPinned = !_isPinned;
                _isEdited = true;
              }),
            ),
            PopupMenuButton<String>(
              iconColor: onBackground,
              onSelected: (value) {
                switch (value) {
                  case 'share':
                    _shareAsText();
                  case 'nearby':
                    _shareNearby();
                  case 'delete':
                    _confirmDelete();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.ios_share_rounded),
                    title: Text('Share'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'nearby',
                  child: ListTile(
                    leading: Icon(Icons.wifi_tethering_rounded),
                    title: Text('Send to nearby'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (!_isNew)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Delete'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                onPressed: _isSaving ? null : _onSavePressed,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (_isRecording) _recordingBanner(scheme),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _titleField(titleColor, onBackground),
                    if (_images.isNotEmpty) _imageStrip(),
                    _contentField(contentColor, onBackground),
                    if (_drawings.isNotEmpty) _drawingCard(scheme, onBackground),
                    if (_audioRecordings.isNotEmpty) _recordingsList(onBackground),
                  ],
                ),
              ),
              _toolbar(onBackground, background),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordingBanner(ColorScheme scheme) {
    final m = _recordElapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _recordElapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.fiber_manual_record_rounded,
              color: scheme.error, size: 16),
          const SizedBox(width: 8),
          Text('Recording  $m:$s',
              style: TextStyle(color: scheme.onErrorContainer)),
          const Spacer(),
          TextButton(onPressed: _toggleRecording, child: const Text('Stop')),
        ],
      ),
    );
  }

  Widget _titleField(Color titleColor, Color onBackground) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _titleController,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
              filled: false,
              isCollapsed: true,
              hintStyle: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: onBackground.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.format_color_text_rounded),
          color: onBackground.withValues(alpha: 0.7),
          tooltip: 'Title colour',
          onPressed: () => _showTextColorPicker(isTitle: true),
        ),
      ],
    );
  }

  Widget _contentField(Color contentColor, Color onBackground) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _contentController,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              keyboardType: TextInputType.multiline,
              style: TextStyle(fontSize: 16, height: 1.5, color: contentColor),
              decoration: InputDecoration(
                hintText: 'Start writing…',
                border: InputBorder.none,
                filled: false,
                isCollapsed: true,
                hintStyle: TextStyle(
                  fontSize: 16,
                  color: onBackground.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.format_color_text_rounded),
            color: onBackground.withValues(alpha: 0.7),
            tooltip: 'Text colour',
            onPressed: () => _showTextColorPicker(isTitle: false),
          ),
        ],
      ),
    );
  }

  Widget _imageStrip() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 110,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _images.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final path = _images[index];
            return Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImagePreview(imagePath: path),
                    ),
                  ),
                  child: Hero(
                    tag: 'image-$path',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(path),
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 110,
                          height: 110,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _removeBadge(() => setState(() {
                        _images.removeAt(index);
                        _isEdited = true;
                      })),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _removeBadge(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _drawingCard(ColorScheme scheme, Color onBackground) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _previewDrawing,
          child: Column(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(painter: StrokePainter(strokes: _drawings)),
              ),
              Container(
                color: scheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.draw_rounded, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Sketch')),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded),
                      tooltip: 'Edit sketch',
                      onPressed: _openDrawing,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: 'Remove sketch',
                      onPressed: () => setState(() {
                        _drawings = [];
                        _isEdited = true;
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordingsList(Color onBackground) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recordings',
              style: TextStyle(
                  color: onBackground, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < _audioRecordings.length; i++)
            AudioPlayerWidget(
              key: ValueKey(_audioRecordings[i]),
              audioPath: _audioRecordings[i],
              audioService: _audioService,
              index: i,
              onDelete: () => setState(() {
                _audioRecordings.removeAt(i);
                _isEdited = true;
              }),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(Color onBackground, Color background) {
    final barColor = Color.alphaBlend(
      Theme.of(context).colorScheme.surfaceTint.withValues(alpha: 0.04),
      background,
    );
    return Material(
      color: barColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _toolButton(Icons.add_photo_alternate_outlined, 'Add image',
                  onBackground, _pickImage),
              _toolButton(Icons.palette_outlined, 'Note colour', onBackground,
                  _showNoteColorPicker),
              _toolButton(
                _isRecording ? Icons.stop_circle_rounded : Icons.mic_none_rounded,
                _isRecording ? 'Stop' : 'Record',
                _isRecording ? Theme.of(context).colorScheme.error : onBackground,
                _toggleRecording,
              ),
              _toolButton(Icons.draw_outlined, 'Sketch', onBackground,
                  _openDrawing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolButton(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon),
      color: color,
      tooltip: tooltip,
      iconSize: 26,
      onPressed: onTap,
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioService.dispose();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }
}
