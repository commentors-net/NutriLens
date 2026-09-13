import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/api/food_vision_client.dart';
import 'package:foodvision/core/models/daily_totals.dart';

/// Fetches today's nutrition totals from GET /meals/today.
/// Auto-disposed; call ref.invalidate(dailyTotalsProvider) to force refresh.
final dailyTotalsProvider = FutureProvider.autoDispose<DailyTotals>((ref) {
  final client = ref.watch(foodVisionClientProvider);
  return client.getMealsToday();
});
