import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/models/daily_totals.dart';
import 'home_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalsAsync = ref.watch(dailyTotalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodVision'),
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(dailyTotalsProvider),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Today's Summary",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            // Daily totals card
            totalsAsync.when(
              loading: () => const _SummaryCardShimmer(),
              error: (e, _) => _SummaryCardError(
                onRetry: () => ref.invalidate(dailyTotalsProvider),
              ),
              data: (totals) => _SummaryCard(totals: totals),
            ),

            const Spacer(),

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
  const _SummaryCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    if (totals.mealCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            children: const [
              Icon(Icons.restaurant, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text(
                'No meals logged yet today',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
              SizedBox(height: 4),
              Text(
                'Tap + New Meal to get started',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${totals.mealCount} meal${totals.mealCount > 1 ? "s" : ""} logged',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroTile(
                    label: 'kcal',
                    value: '${totals.totalKcal}',
                    color: Colors.deepOrange),
                _MacroTile(
                    label: 'protein',
                    value: '${totals.totalProteinG.toStringAsFixed(1)}g',
                    color: Colors.blue),
                _MacroTile(
                    label: 'carbs',
                    value: '${totals.totalCarbsG.toStringAsFixed(1)}g',
                    color: Colors.amber),
                _MacroTile(
                    label: 'fat',
                    value: '${totals.totalFatG.toStringAsFixed(1)}g',
                    color: Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
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

