import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import './note_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final NoteService _noteService = NoteService();

  // Getters for auth state
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('Google Sign In was cancelled by user');
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Set user ID in NoteService
      if (userCredential.user != null) {
        _noteService.setUserId(userCredential.user!.uid);
        debugPrint(
            'Successfully signed in: ${userCredential.user!.displayName}');
      }

      return userCredential;
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
      _noteService.setUserId('');
      debugPrint('Successfully signed out');
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw Exception('Failed to sign out');
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return currentUser != null;
  }

  // Get user display name
  String? getUserName() {
    return currentUser?.displayName;
  }

  // Get user email
  String? getUserEmail() {
    return currentUser?.email;
  }

  // Get user photo URL
  String? getUserPhotoUrl() {
    return currentUser?.photoURL;
  }
}
