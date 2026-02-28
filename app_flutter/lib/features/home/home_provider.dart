import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/food_vision_client.dart';
import '../../core/api/api_config.dart';
import '../../core/models/daily_totals.dart';

/// Fetches today's nutrition totals from GET /meals/today.
/// Auto-disposed; call ref.invalidate(dailyTotalsProvider) to force refresh.
final dailyTotalsProvider = FutureProvider.autoDispose<DailyTotals>((ref) {
  final client = FoodVisionClient(baseUrl: kBackendBaseUrl);
  return client.getMealsToday();
});
