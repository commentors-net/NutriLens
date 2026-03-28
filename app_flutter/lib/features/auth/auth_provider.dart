import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/auth/auth_service.dart';

/// Authentication state provider
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService authService;

  AuthNotifier(this.authService)
      : super(AsyncValue.data(authService.currentUser));

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await authService.signUpWithEmail(email: email, password: password);
      await authService.syncUserToBackend();
      state = AsyncValue.data(authService.currentUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      await authService.signInWithEmail(email: email, password: password);
      await authService.syncUserToBackend();
      state = AsyncValue.data(authService.currentUser);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      await authService.signInWithGoogle();
      await authService.syncUserToBackend();
      state = AsyncValue.data(authService.currentUser);
    } catch (e, st) {
      final errorText = e.toString();
      var currentUser = authService.currentUser;

      // Work around known GoogleSignIn Android Pigeon cast issue that can
      // occur even after Firebase auth has already completed successfully.
      if (errorText.contains('PigeonUserDetails')) {
        // Firebase state can be set a moment after the plugin throws.
        for (var i = 0; i < 6 && currentUser == null; i++) {
          await Future.delayed(const Duration(milliseconds: 200));
          currentUser = authService.currentUser;
        }

        if (currentUser != null) {
          await authService.syncUserToBackend();
          state = AsyncValue.data(currentUser);
          return;
        }
      }

      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await authService.signOut();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

/// Provider to check NutriLens access
final nutrilensAccessProvider = FutureProvider((ref) async {
  final authService = ref.watch(authServiceProvider);
  return authService.canAccessNutriLens();
});
