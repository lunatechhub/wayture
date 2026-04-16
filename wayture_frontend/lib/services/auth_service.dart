import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Auth service — wraps Firebase Auth with demo fallback.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _demoName = '';
  String _demoEmail = '';
  bool _useDemoMode = false;

  bool get isLoggedIn => _auth.currentUser != null || _useDemoMode;

  String get displayName {
    if (_useDemoMode) return _demoName.isNotEmpty ? _demoName : 'Luna Bhattarai';
    return _auth.currentUser?.displayName ?? 'User';
  }

  String get displayEmail {
    if (_useDemoMode) return _demoEmail.isNotEmpty ? _demoEmail : 'luna@wayture.com';
    return _auth.currentUser?.email ?? '';
  }

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (_) {
      _useDemoMode = true;
      _demoEmail = email;
      _demoName = 'Luna Bhattarai';
      notifyListeners();
      return null;
    }
  }

  Future<String?> signUp(String name, String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(name);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (_) {
      _useDemoMode = true;
      _demoName = name;
      _demoEmail = email;
      notifyListeners();
      return null;
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      // Sign out first so the account chooser always appears,
      // letting the user pick which Google account to use.
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return 'Sign-in cancelled';

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      debugPrint('Google sign-in FirebaseAuthException: ${e.code} ${e.message}');
      return _mapError(e.code);
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return 'Google sign-in failed: $e';
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    } catch (_) {
      return 'Could not send reset email. Please try again.';
    }
  }

  Future<void> signOut() async {
    try { await GoogleSignIn().signOut(); } catch (_) {}
    try { await _auth.signOut(); } catch (_) {}
    _useDemoMode = false;
    _demoName = '';
    _demoEmail = '';
    notifyListeners();
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found with this email.';
      case 'wrong-password': return 'Incorrect password.';
      case 'email-already-in-use': return 'Email already in use.';
      case 'weak-password': return 'Password too weak (min 6 chars).';
      case 'invalid-email': return 'Invalid email address.';
      default: return 'Authentication failed.';
    }
  }
}
