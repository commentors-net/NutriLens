import 'package:go_router/go_router.dart';
import '../features/capture/capture_screen.dart';
import '../features/capture/review_screen.dart';
import '../features/results/results_screen.dart';
import '../features/home/home_screen.dart';
import '../features/meals/saved_meals_screen.dart';

/// Named route constants — use these instead of raw strings
class AppRoutes {
  static const home = '/';
  static const capture = '/capture';
  static const review = '/review';
  static const results = '/results';
  static const savedMeals = '/saved-meals';
}

final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
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
  ],
);
