import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../services/note_share_manager.dart';
import '../services/settings_controller.dart';
import '../utils/animations.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final NoteService noteService;
  final SettingsController settings;

  const HomeScreen({
    super.key,
    required this.noteService,
    required this.settings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _shareManager = NoteShareManager();

  @override
  void initState() {
    super.initState();
    _initSharing();
  }

  Future<void> _initSharing() async {
    try {
      await _shareManager.initialize();
      _shareManager.receivedNotes.listen(_onNoteReceived);
    } catch (e) {
      debugPrint('Sharing init failed: $e');
    }
  }

  Future<void> _onNoteReceived(Note note) async {
    if (!mounted) return;
    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Incoming note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('A nearby device wants to share:'),
            const SizedBox(height: 12),
            Text(note.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (note.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(note.content, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (accept != true || !mounted) return;
    try {
      await widget.noteService.addNote(note);
      _snack('Note saved');
    } catch (e) {
      _snack('Could not save the note');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditor([Note? note]) async {
    final result = await Navigator.push(
      context,
      CustomPageRoute(
        child: NoteEditorScreen(note: note, noteService: widget.noteService),
      ),
    );
    // The editor returns the note when it was deleted, so we can offer Undo.
    if (result is Note && mounted) _showUndo(result);
  }

  void _showNoteActions(Note note) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(note.isPinned
                  ? Icons.push_pin_outlined
                  : Icons.push_pin_rounded),
              title: Text(note.isPinned ? 'Unpin' : 'Pin to top'),
              onTap: () {
                Navigator.pop(sheetContext);
                widget.noteService.setPinned(note.id, !note.isPinned);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_full_rounded),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openEditor(note);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded,
                  color: Theme.of(sheetContext).colorScheme.error),
              title: Text('Delete',
                  style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.error)),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteWithUndo(note);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteWithUndo(Note note) async {
    await widget.noteService.removeNote(note.id);
    if (mounted) _showUndo(note);
  }

  void _showUndo(Note note) {
    var undone = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Note deleted'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                undone = true;
                widget.noteService.addNote(note);
              },
            ),
          ),
        )
        .closed
        .then((_) {
      if (!undone) widget.noteService.purgeNoteFiles(note);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NoteHeaven'),
            const SizedBox(width: 6),
            Icon(Icons.auto_awesome,
                size: 18, color: Theme.of(context).colorScheme.primary),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(brightness == Brightness.dark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            tooltip: 'Toggle theme',
            onPressed: () => widget.settings.toggle(brightness),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    SearchScreen(noteService: widget.noteService),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsScreen(settings: widget.settings),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
      body: StreamBuilder<List<Note>>(
        stream: widget.noteService.notesStream,
        initialData: widget.noteService.notes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString());
          }
          final notes = snapshot.data ?? const <Note>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              notes.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notes.isEmpty) return const _EmptyState();
          return _NotesMasonry(
            notes: notes,
            onTap: _openEditor,
            onLongPress: _showNoteActions,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _shareManager.dispose();
    super.dispose();
  }
}

/// Order-preserving masonry: notes are dealt across 2–4 columns based on width.
class _NotesMasonry extends StatelessWidget {
  final List<Note> notes;
  final void Function(Note) onTap;
  final void Function(Note) onLongPress;

  const _NotesMasonry({
    required this.notes,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount = (constraints.maxWidth / 220).floor().clamp(2, 4);
        final columns = List.generate(columnCount, (_) => <Widget>[]);
        for (var i = 0; i < notes.length; i++) {
          final note = notes[i];
          columns[i % columnCount].add(
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoteCard(
                note: note,
                onTap: () => onTap(note),
                onLongPress: () => onLongPress(note),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columnCount; c++) ...[
                if (c > 0) const SizedBox(width: 12),
                Expanded(child: Column(children: columns[c])),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const features = [
      (Icons.mic_none_rounded, 'Record voice notes'),
      (Icons.image_outlined, 'Attach images'),
      (Icons.draw_outlined, 'Sketch ideas'),
      (Icons.auto_awesome, 'Write with AI'),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.edit_note_rounded,
                  size: 52, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 24),
            Text('Your first note awaits',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Capture ideas, sketches, voice and more.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final (icon, label) in features)
                  Chip(
                    avatar: Icon(icon, size: 18),
                    label: Text(label),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            Text('Tap “New note” to begin',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.primary,
                    )),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text('Couldn’t load your notes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
