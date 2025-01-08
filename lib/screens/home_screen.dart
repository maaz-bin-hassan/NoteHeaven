import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/note.dart';
import 'note_editor_screen.dart';
import '../services/note_service.dart';
import '../utils/animations.dart';
import 'search_screen.dart';
import '../services/note_share_manager.dart';

class HomeScreen extends StatefulWidget {
  final Function() onThemeToggle;
  final bool isDarkMode;
  final NoteService noteService;

  const HomeScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.noteService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final _shareManager = NoteShareManager();
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _initializeSharing();
  }

  Future<void> _initializeSharing() async {
    await _shareManager.initialize();

    _shareManager.receivedNotes.listen((note) {
      _showNoteReceiveDialog(note);
    });
  }

  Future<void> _showNoteReceiveDialog(Note note) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receive Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Someone wants to share a note:'),
            const SizedBox(height: 8),
            Text(
              note.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              note.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      try {
        await widget.noteService.addNote(note);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note received and saved')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save received note: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: StreamBuilder<List<Note>>(
          stream: widget.noteService.notesStream,
          initialData: const [],
          key: const PageStorageKey('notes_stream'),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              debugPrint('Error loading notes: ${snapshot.error}');
              return Center(
                child: Text('Error loading notes: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '📝',
                      style: TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ready to take notes!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your creative journey starts here',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground
                                .withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '✨',
                      style: TextStyle(fontSize: 64),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Create Your First Note!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your creative journey starts here',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onBackground
                                .withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic, size: 20),
                            const SizedBox(width: 8),
                            Text('Record voice notes',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 20),
                            const SizedBox(width: 8),
                            Text('Attach images',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.color_lens, size: 20),
                            const SizedBox(width: 8),
                            Text('Change Colors',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.draw, size: 20),
                            const SizedBox(width: 8),
                            Text('Draw & sketch ideas',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Tap the + button to get started',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              );
            }

            return PageStorage(
              bucket: PageStorageBucket(),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: snapshot.hasData
                    ? GridView.builder(
                        key: const PageStorageKey('notes_grid'),
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          return FadeScaleTransition(
                            animation:
                                Tween<double>(begin: 0.0, end: 1.0).animate(
                              CurvedAnimation(
                                parent: ModalRoute.of(context)!.animation!,
                                curve: Interval((index * 0.1).clamp(0, 1), 1.0,
                                    curve: Curves.easeOut),
                              ),
                            ),
                            child: NoteCard(
                              note: snapshot.data![index],
                              noteService: widget.noteService,
                            ),
                          );
                        },
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            );
          },
        ),
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'NoteHeaven',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.auto_awesome,
              color: Colors.amber,
              size: 20,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: widget.onThemeToggle,
            tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          ),
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    noteService: widget.noteService,
                  ),
                ),
              );
            },
            tooltip: 'Search notes',
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _fabController.forward(from: 0);
          Navigator.push(
            context,
            CustomPageRoute(
              child: NoteEditorScreen(noteService: widget.noteService),
            ),
          );
        },
        child: const Icon(Icons.add_rounded),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  @override
  void dispose() {
    _fabController.dispose();
    _shareManager.dispose();
    super.dispose();
  }
}

class NoteCard extends StatelessWidget {
  final Note note;
  final NoteService noteService;

  const NoteCard({
    super.key,
    required this.note,
    required this.noteService,
  });

  Color _getDarkerColor(Color baseColor) {
    final HSLColor hsl = HSLColor.fromColor(baseColor);
    return hsl.withLightness((hsl.lightness * 0.8).clamp(0.0, 1.0)).toColor();
  }

  Color _getContrastingTextColor(Color backgroundColor) {
    double luminance = backgroundColor.computeLuminance();

    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        Color(int.parse(note.color.substring(1, 7), radix: 16) + 0xFF000000);
    final cardColor = isDarkMode ? _getDarkerColor(baseColor) : baseColor;
    final textColor = _getContrastingTextColor(cardColor);

    return Hero(
      tag: 'note-${note.id}',
      child: Material(
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).shadowColor.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                CustomPageRoute(
                  child: NoteEditorScreen(
                    note: note,
                    noteService: noteService,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          note.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDate(note.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      note.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: textColor.withOpacity(0.8),
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (note.images.isNotEmpty) ...[
                          Icon(Icons.image,
                              size: 16, color: textColor.withOpacity(0.6)),
                          const SizedBox(width: 4),
                        ],
                        if (note.audioRecordings.isNotEmpty) ...[
                          Icon(Icons.mic,
                              size: 16, color: textColor.withOpacity(0.6)),
                          const SizedBox(width: 4),
                        ],
                        if (note.images.isNotEmpty ||
                            note.audioRecordings.isNotEmpty)
                          Flexible(
                            child: Text(
                              _getAttachmentsCount(),
                              style: TextStyle(
                                fontSize: 12,
                                color: textColor.withOpacity(0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getAttachmentsCount() {
    final total = note.images.length + note.audioRecordings.length;
    return '$total attachment${total > 1 ? 's' : ''}';
  }
}
