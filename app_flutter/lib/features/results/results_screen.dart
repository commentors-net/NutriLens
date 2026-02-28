import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router.dart';
import '../../core/models/analyze_response.dart';
import '../capture/capture_controller.dart';
import 'analysis_provider.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisState = ref.watch(analysisProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Analysis'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(analysisProvider.notifier).reset();
            ref.read(captureProvider.notifier).clear();
            context.go(AppRoutes.home);
          },
        ),
      ),
      body: analysisState.when(
        loading: () => const _LoadingView(),
        error: (e, _) => _ErrorView(
          error: e.toString(),
          onRetry: () => context.go(AppRoutes.review),
        ),
        data: (response) {
          if (response == null) {
            return _ErrorView(
              error: 'No analysis results.',
              onRetry: () => context.go(AppRoutes.review),
            );
          }
          return _ResultsView(response: response);
        },
      ),
    );
  }
}

// ─── Loading ─────────────────────────────────────────────────────────────────

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 20),
          Text('Analyzing your meal…', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          Text(
            'This may take a few seconds',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ─── Error ────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Analysis failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              error.contains('SocketException') || error.contains('Connection')
                  ? 'Cannot reach the backend.\nMake sure the server is running on your PC.'
                  : error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Review'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Results ─────────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  final AnalyzeMealResponse response;
  const _ResultsView({required this.response});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalKcal = response.items.fold<int>(0, (sum, i) => sum + i.macros.kcal);
    final totalProtein =
        response.items.fold<double>(0, (sum, i) => sum + i.macros.proteinG);
    final totalCarbs =
        response.items.fold<double>(0, (sum, i) => sum + i.macros.carbsG);
    final totalFat =
        response.items.fold<double>(0, (sum, i) => sum + i.macros.fatG);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Confidence banner
        _ConfidenceBanner(response: response),
        const SizedBox(height: 16),

        // Total macros card
        _MacrosTotalCard(
          kcal: totalKcal,
          protein: totalProtein,
          carbs: totalCarbs,
          fat: totalFat,
        ),
        const SizedBox(height: 16),

        // Per-item cards
        const Text(
          'Detected Items',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ...response.items.map((item) => _ItemCard(item: item)),

        // Warnings
        if (response.warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...response.warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                const SizedBox(width: 6),
                Text(w, style: const TextStyle(color: Colors.orange, fontSize: 13)),
              ]),
            ),
          ),
        ],

        const SizedBox(height: 24),

        // Actions
        if (response.needsMorePhotos)
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.capture),
            icon: const Icon(Icons.add_a_photo),
            label: const Text('Add More Photos for Better Accuracy'),
          ),
        const SizedBox(height: 12),

        // Save Meal button — watches save state
        _SaveMealButton(response: response),
        const SizedBox(height: 10),

        // Discard — go home without saving
        OutlinedButton.icon(
          onPressed: () {
            ref.read(saveMealProvider.notifier).reset();
            ref.read(analysisProvider.notifier).reset();
            ref.read(captureProvider.notifier).clear();
            context.go(AppRoutes.home);
          },
          icon: const Icon(Icons.close),
          label: const Text('Discard & Go Home'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Confidence Banner ────────────────────────────────────────────────────────

class _ConfidenceBanner extends StatelessWidget {
  final AnalyzeMealResponse response;
  const _ConfidenceBanner({required this.response});

  @override
  Widget build(BuildContext context) {
    final pct = (response.overallConfidence * 100).round();
    final color = pct >= 70 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            response.needsMorePhotos ? Icons.info_outline : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              response.needsMorePhotos
                  ? 'Confidence $pct% — more photos would improve accuracy'
                  : 'Confidence $pct% — analysis looks good!',
              style: TextStyle(color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Macros Total Card ────────────────────────────────────────────────────────

class _MacrosTotalCard extends StatelessWidget {
  final int kcal;
  final double protein, carbs, fat;
  const _MacrosTotalCard(
      {required this.kcal,
      required this.protein,
      required this.carbs,
      required this.fat});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Total Meal',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroChip(label: 'kcal', value: '$kcal', color: Colors.deepOrange),
                _MacroChip(
                    label: 'protein', value: '${protein.toStringAsFixed(1)}g', color: Colors.blue),
                _MacroChip(
                    label: 'carbs', value: '${carbs.toStringAsFixed(1)}g', color: Colors.amber),
                _MacroChip(
                    label: 'fat', value: '${fat.toStringAsFixed(1)}g', color: Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MacroChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

// ─── Per-item Card ────────────────────────────────────────────────────────────

class _ItemCard extends StatelessWidget {
  final AnalyzeItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final confidencePct = (item.labelConfidence * 100).round();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$confidencePct% sure',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${item.gramsEstimate}g  (range: ${item.gramsRange.min}–${item.gramsRange.max}g)',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroChip(
                    label: 'kcal',
                    value: '${item.macros.kcal}',
                    color: Colors.deepOrange),
                _MacroChip(
                    label: 'protein',
                    value: '${item.macros.proteinG.toStringAsFixed(1)}g',
                    color: Colors.blue),
                _MacroChip(
                    label: 'carbs',
                    value: '${item.macros.carbsG.toStringAsFixed(1)}g',
                    color: Colors.amber),
                _MacroChip(
                    label: 'fat',
                    value: '${item.macros.fatG.toStringAsFixed(1)}g',
                    color: Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Save Meal Button ─────────────────────────────────────────────────────────

class _SaveMealButton extends ConsumerWidget {
  final AnalyzeMealResponse response;
  const _SaveMealButton({required this.response});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saveState = ref.watch(saveMealProvider);

    return saveState.when(
      loading: () => const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Column(
        children: [
          Text(
            'Could not save — tap to retry',
            style: TextStyle(color: Colors.red.shade400, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          FilledButton.icon(
            onPressed: () =>
                ref.read(saveMealProvider.notifier).save(response),
            icon: const Icon(Icons.save),
            label: const Text('Save Meal'),
          ),
        ],
      ),
      data: (mealId) {
        if (mealId != null) {
          // Already saved — show "Go Home" button
          return FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            onPressed: () {
              ref.read(saveMealProvider.notifier).reset();
              ref.read(analysisProvider.notifier).reset();
              ref.read(captureProvider.notifier).clear();
              context.go(AppRoutes.home);
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Meal Saved — Go Home'),
          );
        }
        // Not yet saved
        return FilledButton.icon(
          onPressed: () =>
              ref.read(saveMealProvider.notifier).save(response),
          icon: const Icon(Icons.save),
          label: const Text('Save Meal'),
        );
      },
    );
  }
}
