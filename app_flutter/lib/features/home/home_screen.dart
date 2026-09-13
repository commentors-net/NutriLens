import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:foodvision/app/router.dart';
import 'package:foodvision/core/models/daily_totals.dart';
import 'package:foodvision/core/models/nutrilens_profile.dart';
import 'package:foodvision/features/profile/profile_provider.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(dailyTotalsProvider);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodVision'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(dailyTotalsProvider);
              ref.invalidate(profileProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Today's Summary",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: () => context.push(AppRoutes.profile),
                  icon: const Icon(Icons.track_changes, size: 16),
                  label: const Text('Goals', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Daily totals card with profile targets
            totalsAsync.when(
              loading: () => const _SummaryCardShimmer(),
              error: (e, _) => _SummaryCardError(
                onRetry: () => ref.invalidate(dailyTotalsProvider),
              ),
              data: (totals) => _SummaryCard(totals: totals, profile: profile),
            ),

            const Spacer(),

            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.savedMeals),
              icon: const Icon(Icons.bookmark_outline),
              label: const Text('Saved Meals'),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.history),
              icon: const Icon(Icons.history),
              label: const Text('Meal History'),
            ),
            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.capture),
              icon: const Icon(Icons.camera_alt),
              label: const Text('+ New Meal'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card (loaded) ────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final DailyTotals totals;
  final NutriLensProfile? profile;
  const _SummaryCard({required this.totals, this.profile});

  @override
  Widget build(BuildContext context) {
    final calorieGoal = profile?.dailyCalorieGoal ?? 2000;
    final proteinGoal = profile?.proteinGoalG ?? 100.0;
    final carbsGoal = profile?.carbsGoalG ?? 250.0;
    final fatGoal = profile?.fatGoalG ?? 65.0;

    final calFraction = (calorieGoal > 0 ? (totals.totalKcal / calorieGoal) : 0.0).clamp(0.0, 1.0);
    final calPct = calorieGoal > 0 ? ((totals.totalKcal / calorieGoal) * 100).round() : 0;
    final isCalOver = calorieGoal > 0 && totals.totalKcal > calorieGoal;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  totals.mealCount == 0
                      ? 'No meals logged yet today'
                      : '${totals.mealCount} meal${totals.mealCount > 1 ? "s" : ""} logged',
                  style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCalOver ? Colors.red.shade50 : Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$calPct% of goal',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isCalOver ? Colors.red : Colors.deepOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Calorie progress bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                RichText(
                  text: TextSpan(
                    text: '${totals.totalKcal} ',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: '/ $calorieGoal kcal',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(calorieGoal - totals.totalKcal).abs()} kcal ${totals.totalKcal > calorieGoal ? 'over' : 'left'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isCalOver ? Colors.red : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: calFraction,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isCalOver ? Colors.red : Colors.deepOrange,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Macro tiles with progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _MacroProgressTile(
                    label: 'Protein',
                    current: totals.totalProteinG,
                    target: proteinGoal,
                    unit: 'g',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroProgressTile(
                    label: 'Carbs',
                    current: totals.totalCarbsG,
                    target: carbsGoal,
                    unit: 'g',
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroProgressTile(
                    label: 'Fat',
                    current: totals.totalFatG,
                    target: fatGoal,
                    unit: 'g',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroProgressTile extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final String unit;
  final Color color;

  const _MacroProgressTile({
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (target > 0 ? (current / target) : 0.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '${current.toStringAsFixed(0)}/${target.toStringAsFixed(0)}$unit',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading shimmer ──────────────────────────────────────────────────────────

class _SummaryCardShimmer extends StatelessWidget {
  const _SummaryCardShimmer();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _SummaryCardError extends StatelessWidget {
  final VoidCallback onRetry;
  const _SummaryCardError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.wifi_off, size: 40, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('Could not load today\'s totals',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

