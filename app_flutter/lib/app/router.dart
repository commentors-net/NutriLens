import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/capture/capture_screen.dart';
import '../features/capture/review_screen.dart';
import '../features/results/results_screen.dart';
import '../features/home/home_screen.dart';
import '../features/meals/saved_meals_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/auth/auth_provider.dart';
import '../features/settings/settings_screen.dart';

/// Named route constants — use these instead of raw strings
class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const capture = '/capture';
  static const review = '/review';
  static const results = '/results';
  static const savedMeals = '/saved-meals';
  static const settings = '/settings';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();

// Riverpod provider for router
final goRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authNotifierProvider);
  
  return GoRouter(
    initialLocation: AppRoutes.login,
    navigatorKey: _rootNavigatorKey,
    redirect: (context, state) {
      final isLoggingIn = state.uri.path == AppRoutes.login;
      final isSigningUp = state.uri.path == AppRoutes.signup;
      final isAuthenticated = authNotifier.maybeWhen(
        data: (user) => user != null,
        orElse: () => false,
      );

      // If not authenticated and not on login/signup pages, redirect to login
      if (!isAuthenticated && !isLoggingIn && !isSigningUp) {
        return AppRoutes.login;
      }

      // If authenticated and on login/signup pages, redirect to home
      if (isAuthenticated && (isLoggingIn || isSigningUp)) {
        return AppRoutes.home;
      }

      return null;
    },
    routes: [
      // Auth routes
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (context, state) => const SignUpScreen(),
      ),
      // Protected app routes
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.capture,
        builder: (context, state) => const CaptureScreen(),
      ),
      GoRoute(
        path: AppRoutes.review,
        builder: (context, state) => const ReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.results,
        builder: (context, state) => const ResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.savedMeals,
        builder: (context, state) => const SavedMealsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
});
