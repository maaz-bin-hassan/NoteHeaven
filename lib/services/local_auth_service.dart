import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthService {
  static final LocalAuthService _instance = LocalAuthService._internal();
  factory LocalAuthService() => _instance;
  LocalAuthService._internal();

  final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
  bool _isAuthenticated = false;
  String? _username;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;

  Future<bool> login(
      String username, String password, BuildContext context) async {
    // For demo purposes, accept any non-empty username/password
    if (username.isNotEmpty && password.isNotEmpty) {
      final prefs = await _prefs;
      await prefs.setString('username', username);
      _username = username;
      _isAuthenticated = true;

      // Use Navigator.pushReplacementNamed instead of pushNamed
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final prefs = await _prefs;
    await prefs.remove('username');
    _username = null;
    _isAuthenticated = false;
  }

  Future<void> checkAuthState() async {
    final prefs = await _prefs;
    _username = prefs.getString('username');
    _isAuthenticated = _username != null;
  }
}
