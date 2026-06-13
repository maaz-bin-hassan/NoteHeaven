import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import '../theme/app_palette.dart';
import 'note_editor_screen.dart';

class SearchScreen extends StatefulWidget {
  final NoteService noteService;

  const SearchScreen({super.key, required this.noteService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Note> _results = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  Future<void> _onChanged() async {
    final query = _controller.text;
    final results = await widget.noteService.searchNotes(query);
    if (mounted) {
      setState(() {
        _query = query.trim();
        _results = query.trim().isEmpty ? [] : results;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search notes…',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _controller.clear(),
              tooltip: 'Clear',
            ),
        ],
      ),
      body: _query.isEmpty
          ? _hint(scheme, Icons.search_rounded, 'Search by title or content')
          : _results.isEmpty
              ? _hint(scheme, Icons.search_off_rounded,
                  'No notes match “$_query”')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _SearchTile(note: _results[index], query: _query, onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NoteEditorScreen(
                          note: _results[index],
                          noteService: widget.noteService,
                        ),
                      ),
                    );
                  }),
                ),
    );
  }

  Widget _hint(ColorScheme scheme, IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: scheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(text,
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _SearchTile extends StatelessWidget {
  final Note note;
  final String query;
  final VoidCallback onTap;

  const _SearchTile({
    required this.note,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppPalette.resolve(note.color, Brightness.light),
          radius: 6,
        ),
        title: _Highlighted(
          text: note.title.isEmpty ? 'Untitled' : note.title,
          query: query,
          base: Theme.of(context).textTheme.titleMedium!,
          highlight: scheme.primary,
        ),
        subtitle: note.content.trim().isEmpty
            ? null
            : _Highlighted(
                text: note.content.trim(),
                query: query,
                base: Theme.of(context).textTheme.bodySmall!,
                highlight: scheme.primary,
                maxLines: 2,
              ),
        trailing: note.isPinned
            ? const Icon(Icons.push_pin_rounded, size: 16)
            : null,
        onTap: onTap,
      ),
    );
  }
}

/// Renders [text] with case-insensitive matches of [query] emphasised.
class _Highlighted extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle base;
  final Color highlight;
  final int maxLines;

  const _Highlighted({
    required this.text,
    required this.query,
    required this.base,
    required this.highlight,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final q = query.toLowerCase();
    var start = 0;
    if (q.isNotEmpty) {
      var idx = lower.indexOf(q, start);
      while (idx >= 0) {
        if (idx > start) {
          spans.add(TextSpan(text: text.substring(start, idx)));
        }
        spans.add(TextSpan(
          text: text.substring(idx, idx + q.length),
          style: TextStyle(color: highlight, fontWeight: FontWeight.w700),
        ));
        start = idx + q.length;
        idx = lower.indexOf(q, start);
      }
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: spans),
    );
  }
}
