import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/environment.dart';

/// Authentication service managing Firebase Auth and backend sync
class AuthService {
  AuthService({required this.baseUrl});

  final String baseUrl;
  FirebaseAuth? get _firebaseAuth {
    try {
      return FirebaseAuth.instance;
    } catch (e) {
      print('FirebaseAuth not initialized: $e');
      return null;
    }
  }
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;
  final Dio _dio = Dio();

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;

    await _googleSignIn.initialize(
      serverClientId: '427212681311-h6dn1ekq5dkplvbq7mkk5hll1l7ld7jk.apps.googleusercontent.com',
    );
    _googleSignInInitialized = true;
  }

  /// Get current user
  User? get currentUser {
    try {
      return _firebaseAuth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get current user ID
  String? get userId => currentUser?.uid;

  /// Get current user email
  String? get userEmail => currentUser?.email;

  /// Get current user ID token for API calls
  Future<String?> getIdToken() async {
    try {
      return await currentUser?.getIdToken();
    } catch (e) {
      print('Error getting ID token: $e');
      return null;
    }
  }

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw Exception('Authentication service is not initialized');
    }
    try {
      return await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw Exception('Authentication service is not initialized');
    }
    try {
      return await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw Exception('Authentication service is not initialized');
    }
    try {
      await _ensureGoogleSignInInitialized();
      print('Google sign-in: starting interactive sign-in flow');

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
        scopeHint: ['email'],
      );

      print('Google sign-in: account selected ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      print(
        'Google sign-in: token fetch complete '
        '(hasIdToken=${googleAuth.idToken?.isNotEmpty == true})',
      );

      if (googleAuth.idToken == null || googleAuth.idToken!.isEmpty) {
        throw Exception('Google sign-in did not return an ID token. Check Firebase OAuth setup.');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await auth.signInWithCredential(credential);
      print('Google sign-in: Firebase credential sign-in succeeded for ${userCredential.user?.uid}');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } on PlatformException catch (e) {
      print('Google sign-in platform exception: code=${e.code}, message=${e.message}, details=${e.details}');
      throw Exception('Google sign-in failed: ${e.message ?? e.code}');
    } catch (e) {
      print('Google sign-in unexpected exception: $e');
      throw Exception('Google sign-in failed: $e');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _ensureGoogleSignInInitialized();
      final auth = _firebaseAuth;
      await Future.wait([
        if (auth != null) auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      print('Error signing out: $e');
      throw Exception('Sign out failed: $e');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw Exception('Authentication service is not initialized');
    }
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  /// Sync user to backend database
  Future<void> syncUserToBackend() async {
    try {
      final user = currentUser;
      if (user == null) {
        return;
      }

      final idToken = await user.getIdToken();
      final response = await _dio.post(
        '$baseUrl/auth/sync',
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
        data: {
          'email': user.email,
          'display_name': user.displayName,
          'photo_url': user.photoURL,
        },
      );

      if (response.statusCode != 200) {
        print('Backend sync skipped: unexpected status ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        print('Backend sync endpoint not available at $baseUrl/auth/sync; continuing without sync.');
        return;
      }
      print('Error syncing user to backend: $e');
    } catch (e) {
      print('Error syncing user to backend: $e');
    }
  }

  /// Verify user has access to NutriLens feature
  Future<bool> canAccessNutriLens() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final idToken = await user.getIdToken();
      final response = await _dio.get(
        '$baseUrl/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $idToken'}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = response.data;
        final allowedSystems = data['allowed_systems'] as List?;
        return allowedSystems?.contains('nutrilens') ?? false;
      }
      return false;
    } catch (e) {
      print('Error checking NutriLens access: $e');
      return false;
    }
  }

  /// Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak.';
      case 'email-already-in-use':
        return 'Account already exists for that email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'User account has been disabled.';
      case 'user-not-found':
        return 'User not found.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'operation-not-allowed':
        return 'Authentication method not enabled.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}

/// Riverpod provider for AuthService
final authServiceProvider = Provider((ref) {
  final apiBaseUrl = ref.watch(apiBaseUrlProvider);
  return AuthService(baseUrl: apiBaseUrl);
});

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  final auth = authService._firebaseAuth;
  if (auth == null) {
    return Stream<User?>.value(null);
  }
  return auth.authStateChanges();
});

final currentUserProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});
