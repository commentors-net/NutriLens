import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/food_vision_client.dart';
import '../../core/api/api_config.dart';
import '../../core/models/analyze_response.dart';

final _client = FoodVisionClient(baseUrl: kBackendBaseUrl);

// ─── Analysis provider ────────────────────────────────────────────────────────

/// Holds the state of the meal analysis API call.
class AnalysisNotifier extends StateNotifier<AsyncValue<AnalyzeMealResponse?>> {
  AnalysisNotifier() : super(const AsyncValue.data(null));

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

  void reset() => state = const AsyncValue.data(null);
}

final analysisProvider =
    StateNotifierProvider<AnalysisNotifier, AsyncValue<AnalyzeMealResponse?>>(
  (ref) => AnalysisNotifier(),
);

// ─── Save meal provider ───────────────────────────────────────────────────────

/// Tracks the state of saving a meal to the backend after the user confirms.
class SaveMealNotifier extends StateNotifier<AsyncValue<String?>> {
  SaveMealNotifier() : super(const AsyncValue.data(null));

  Future<void> save(AnalyzeMealResponse analysis) async {
    state = const AsyncValue.loading();
    try {
      final mealId = await _client.saveMealFromAnalysis(analysis);
      state = AsyncValue.data(mealId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void reset() => state = const AsyncValue.data(null);
}

final saveMealProvider =
    StateNotifierProvider<SaveMealNotifier, AsyncValue<String?>>(
  (ref) => SaveMealNotifier(),
);

