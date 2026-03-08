import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_service.dart';
import '../config/environment.dart';
import 'meals_service.dart';

final mealsServiceProvider = Provider((ref) {
  final authService = ref.watch(authServiceProvider);
  final apiBaseUrl = ref.watch(apiBaseUrlProvider);
  return MealsService(
    apiBaseUrl: apiBaseUrl,
    authService: authService,
  );
});

// Provider for meal history
final mealHistoryProvider = FutureProvider((ref) async {
  final mealsService = ref.watch(mealsServiceProvider);
  return mealsService.getMealHistory();
});

// Provider for today's nutrition
final todayNutritionProvider = FutureProvider((ref) async {
  final mealsService = ref.watch(mealsServiceProvider);
  return mealsService.getTodayNutrition();
});

// Provider for syncing state
final syncStateProvider = StateProvider<AsyncValue<void>>((ref) {
  return const AsyncValue.data(null);
});

final syncMealsProvider = FutureProvider((ref) async {
  final mealsService = ref.watch(mealsServiceProvider);
  return mealsService.syncMeals();
});
