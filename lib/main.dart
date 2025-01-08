import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/note_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

extension BuildContextExtensions on BuildContext {
  _MyAppState? findAppState() {
    return findAncestorStateOfType<_MyAppState>();
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  final _noteService = NoteService();
  final _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await _prefs;
      final savedMode = prefs.getBool('isDarkMode') ?? false;
      if (mounted && savedMode != _isDarkMode) {
        setState(() {
          _isDarkMode = savedMode;
        });
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> _toggleTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = !_isDarkMode;
      });
      await prefs.setBool('isDarkMode', _isDarkMode);
      debugPrint('Theme toggled: isDarkMode = $_isDarkMode');
    } catch (e) {
      debugPrint('Error toggling theme: $e');
    }
  }

  bool get isDarkMode => _isDarkMode;
  void toggleTheme() => _toggleTheme();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteHeaven',
      debugShowCheckedModeBanner: false,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          primary: const Color(0xFF6B4EFF),
          secondary: const Color(0xFF51E1C3),
          tertiary: const Color(0xFFFF6B6B),
          background: const Color(0xFFF8F9FE),
          surface: const Color(0xFFFFFFFF).withOpacity(0.8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: const Color(0xFFF8F9FE).withOpacity(0.8),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FE),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          elevation: 8,
          selectedItemColor: Color(0xFF6B4EFF),
          unselectedItemColor: Colors.grey,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          primary: const Color(0xFF6B4EFF),
          secondary: const Color(0xFF51E1C3),
          tertiary: const Color(0xFFFF6B6B),
          background: const Color(0xFF1A1A1A),
          surface: const Color(0xFF2A2A2A).withOpacity(0.8),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.8),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black.withOpacity(0.2),
        ),
      ),
      home: HomeScreen(
        onThemeToggle: _toggleTheme,
        isDarkMode: _isDarkMode,
        noteService: _noteService,
      ),
    );
  }

  @override
  void dispose() {
    _noteService.dispose();
    super.dispose();
  }
}
