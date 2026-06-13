import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';
import 'services/note_service.dart';
import 'services/settings_controller.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The .env file is optional — the app is fully usable without an AI key.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('No .env loaded (AI features will be disabled): $e');
  }

  final settings = SettingsController();
  await settings.load();

  runApp(NoteHeavenApp(settings: settings));
}

class NoteHeavenApp extends StatefulWidget {
  final SettingsController settings;

  const NoteHeavenApp({super.key, required this.settings});

  @override
  State<NoteHeavenApp> createState() => _NoteHeavenAppState();
}

class _NoteHeavenAppState extends State<NoteHeavenApp> {
  final _noteService = NoteService();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'NoteHeaven',
          debugShowCheckedModeBanner: false,
          themeMode: widget.settings.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: HomeScreen(
            noteService: _noteService,
            settings: widget.settings,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _noteService.dispose();
    super.dispose();
  }
}
