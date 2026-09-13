import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/features/capture/capture_screen.dart';
import 'package:foodvision/features/capture/review_screen.dart';
import 'package:foodvision/features/results/results_screen.dart';
import 'package:foodvision/features/home/home_screen.dart';
import 'package:foodvision/features/meals/saved_meals_screen.dart';
import 'package:foodvision/features/meals/meal_history_screen.dart';
import 'package:foodvision/features/auth/login_screen.dart';
import 'package:foodvision/features/auth/signup_screen.dart';
import 'package:foodvision/features/auth/auth_provider.dart';
import 'package:foodvision/features/settings/settings_screen.dart';
import 'package:foodvision/features/profile/profile_screen.dart';

/// Named route constants — use these instead of raw strings
class AppRoutes {
  static const login = '/login';
  static const signup = '/signup';
  static const home = '/home';
  static const capture = '/capture';
  static const review = '/review';
  static const results = '/results';
  static const savedMeals = '/saved-meals';
  static const history = '/history';
  static const settings = '/settings';
  static const profile = '/profile';
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
        builder: (context, state) => CaptureScreen(
          suggestedShotPrompt: state.extra as String?,
        ),
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
        path: AppRoutes.history,
        builder: (context, state) => const MealHistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});
