import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/api/food_vision_client.dart';
import '../../core/config/environment.dart';
import '../../core/models/analyze_response.dart';
import '../../core/models/meal_draft.dart';
import '../meals/meals_provider.dart';

// ─── Analysis provider ────────────────────────────────────────────────────────

/// Holds the state of the meal analysis API call.
class AnalysisNotifier extends StateNotifier<AsyncValue<AnalyzeMealResponse?>> {
  AnalysisNotifier(this._client) : super(const AsyncValue.data(null));

  final FoodVisionClient _client;

  /// Sends captured photo paths to backend and stores the result.
  Future<void> analyze(List<String> photoPaths) async {
    state = const AsyncValue.loading();
    try {
      final result = await _client.analyzeMeal(
        imagePaths: photoPaths,
        platform: 'android',
        appVersion: '0.1.0',
        photoCount: photoPaths.length,
        locale: 'en_MY',
        timestamp: DateTime.now(),
      );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateItem(int index, AnalyzeItem updatedItem) {
    final current = state.valueOrNull;
    if (current == null || index < 0 || index >= current.items.length) {
      return;
    }

    final updatedItems = [...current.items];
    updatedItems[index] = updatedItem;
    state = AsyncValue.data(current.copyWith(items: updatedItems));
  }

  void reset() => state = const AsyncValue.data(null);
}

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AsyncValue<AnalyzeMealResponse?>>(
  (ref) {
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    return AnalysisNotifier(FoodVisionClient(baseUrl: apiBaseUrl));
  },
);

// ─── Save meal provider ───────────────────────────────────────────────────────

/// Tracks the state of saving a meal to the backend + local DB after the user confirms.
class SaveMealNotifier extends StateNotifier<AsyncValue<String?>> {
  final Ref _ref;
  final FoodVisionClient _client;

  SaveMealNotifier(this._ref, this._client) : super(const AsyncValue.data(null));

  Future<void> save(AnalyzeMealResponse analysis) async {
    state = const AsyncValue.loading();
    try {
      // Save to backend
      final mealId = await _client.saveMealFromAnalysis(analysis);
      
      // Also save to local database
      final savedMeal = SavedMeal(
        id: mealId ?? const Uuid().v4(),
        name: 'Meal ${DateTime.now().toString().substring(5, 16)}',
        analyzedAt: DateTime.now(),
        items: analysis.items.map((item) => MealItem.fromJson({
          'item_id': item.itemId,
          'label': item.label,
          'grams_estimate': item.gramsEstimate,
          'macros': {
            'kcal': item.macros.kcal,
            'protein_g': item.macros.proteinG,
            'carbs_g': item.macros.carbsG,
            'fat_g': item.macros.fatG,
          },
        })).toList(),
        totalKcal: analysis.items.fold<double>(0, (sum, i) => sum + i.macros.kcal.toDouble()),
        totalProteinG: analysis.items.fold<double>(0, (sum, i) => sum + i.macros.proteinG),
        totalCarbsG: analysis.items.fold<double>(0, (sum, i) => sum + i.macros.carbsG),
        totalFatG: analysis.items.fold<double>(0, (sum, i) => sum + i.macros.fatG),
      );
      
      await _ref.read(savedMealsControllerProvider.notifier).saveMeal(savedMeal);
      
      state = AsyncValue.data(mealId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final saveMealProvider =
    StateNotifierProvider<SaveMealNotifier, AsyncValue<String?>>(
  (ref) {
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    return SaveMealNotifier(ref, FoodVisionClient(baseUrl: apiBaseUrl));
  },
);

