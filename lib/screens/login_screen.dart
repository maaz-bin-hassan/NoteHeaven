import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/note_service.dart';
import 'home_screen.dart';
import '../main.dart'; // Add this import

class LoginScreen extends StatelessWidget {
  final AuthService _authService = AuthService();
  final NoteService _noteService = NoteService();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo/icon
              const Icon(
                Icons.note_alt_outlined,
                size: 64,
                color: Color(0xFF6B4EFF),
              ),
              const SizedBox(height: 24),
              // App name
              const Text(
                'NoteHeaven',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              // Sign in button
              ElevatedButton(
                onPressed: () async {
                  try {
                    final userCredential =
                        await _authService.signInWithGoogle();
                    if (userCredential != null && context.mounted) {
                      // Use the extension method to find app state
                      final appState = context.findAppState();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(
                            onThemeToggle: appState?.toggleTheme ?? () {},
                            isDarkMode: appState?.isDarkMode ?? false,
                            noteService: _noteService,
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error signing in: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/google_logo.png', height: 24),
                    const SizedBox(width: 12),
                    const Text(
                      'Sign in with Google',
                      style: TextStyle(fontSize: 16),
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
}
