import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_service.dart';
import 'note_editor_screen.dart';

class SearchScreen extends StatefulWidget {
  final NoteService noteService;

  const SearchScreen({
    super.key,
    required this.noteService,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<Note> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _onSearchChanged() async {
    if (_searchController.text.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final results =
        await widget.noteService.searchNotes(_searchController.text);

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search notes...',
            border: InputBorder.none,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          if (_isSearching)
            const LinearProgressIndicator()
          else if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No results found'),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final note = _searchResults[index];
                  return ListTile(
                    title: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      note.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteEditorScreen(
                            note: note,
                            noteService: widget.noteService,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
