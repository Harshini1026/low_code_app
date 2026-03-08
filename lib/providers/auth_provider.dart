import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  AuthStatus _status = AuthStatus.initial;
  String? _errorMessage;

  // ── Getters ───────────────────────────────────────────────────────────────
  User? get user           => _user;
  AuthStatus get status    => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading       => _status == AuthStatus.loading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ── Constructor: listen to Firebase auth state ────────────────────────────
  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      _user = user;
      _status = user != null
          ? AuthStatus.authenticated
          : AuthStatus.unauthenticated;
      notifyListeners();
    });
  }

  // ── Sign In ───────────────────────────────────────────────────────────────
  Future<void> signIn(String email, String password) async {
    _setLoading();
    try {
      await _authService.signInWithEmail(email, password);
      _clearError();
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('An unexpected error occurred. Please try again.');
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<void> register(String email, String password, String name) async {
    _setLoading();
    try {
      await _authService.registerWithEmail(email, password, name);
      _clearError();
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('Registration failed. Please try again.');
    }
  }

  // ── Google Sign In ────────────────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    _setLoading();
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) {
        // User cancelled Google sign-in
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      } else {
        _clearError();
      }
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('Google sign-in failed. Please try again.');
    }
  }

  // ── Send Password Reset ───────────────────────────────────────────────────
  Future<void> sendPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e.code));
    } catch (e) {
      _setError('Could not send reset email. Please try again.');
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _authService.signOut();
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _setError('Sign out failed. Please try again.');
    }
  }

  // ── Clear error manually ──────────────────────────────────────────────────
  void clearError() => _clearError();

  // ── Internal helpers ──────────────────────────────────────────────────────
  void _setLoading() {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _status = AuthStatus.error;
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'invalid-credential':
        return 'Invalid credentials. Please try again.';
      case 'account-exists-with-different-credential':
        return 'Account exists with a different sign-in method.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }
}