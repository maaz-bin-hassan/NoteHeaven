import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'screens/home_screen.dart';
import 'services/note_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final authService = AuthService();
    final noteService = NoteService();

    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user != null) {
        debugPrint('User is signed in with ID: ${user.uid}');
        noteService.setUserId(user.uid);
      } else {
        debugPrint('User is signed out');
        noteService.setUserId('');
      }
    });

    debugPrint('App initialized successfully');
    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error initializing app: $e');
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  final _noteService = NoteService();

  // Make isDarkMode accessible
  bool get isDarkMode => _isDarkMode;

  static _MyAppState of(BuildContext context) {
    return context.findAncestorStateOfType<_MyAppState>()!;
  }

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _noteService.init();

    // Initialize with current user if exists
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _noteService.setUserId(currentUser.uid);
    }
  }

  void toggleTheme() {
    setState(() {
      _isDarkMode = !_isDarkMode;
      debugPrint('Theme toggled: isDarkMode = $_isDarkMode'); // Add debug print
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteHeaven',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          primary: const Color(0xFF6B4EFF),
          secondary: const Color(0xFF51E1C3),
          background: const Color(0xFFF8F9FE),
          brightness: Brightness.light, // Changed this
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        appBarTheme: AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor:
              _isDarkMode ? const Color(0xFF1A1A1A) : const Color(0xFFF8F9FE),
        ),
        cardTheme: CardTheme(
          elevation: 4,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: Colors.black26,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6B4EFF),
          primary: const Color(0xFF6B4EFF),
          secondary: const Color(0xFF51E1C3),
          background: const Color(0xFF1A1A1A),
          brightness: Brightness.dark, // Make sure this is set
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasData) {
            _noteService.setUserId(snapshot.data!.uid);
            return HomeScreen(
              onThemeToggle: toggleTheme,
              isDarkMode: _isDarkMode,
              noteService: _noteService,
            );
          }

          return LoginScreen();
        },
      ),
    );
  }

  @override
  void dispose() {
    _noteService.dispose();
    super.dispose();
  }
}

// Create a way to access the state from anywhere
extension BuildContextExtension on BuildContext {
  _MyAppState? findAppState() {
    try {
      return findRootAncestorStateOfType<_MyAppState>();
    } catch (e) {
      debugPrint('Error finding app state: $e');
      return null;
    }
  }
}
