import 'package:firebase_auth/firebase_auth.dart';

extension UserExtension on User {
  String get displayName => this.displayName ?? 'User';
  String get photoURL => this.photoURL ?? '';
  bool get hasDisplayName =>
      this.displayName != null && this.displayName!.isNotEmpty;
}
