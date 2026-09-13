import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/models/analyze_response.dart';
import 'package:foodvision/features/capture/capture_controller.dart';
import 'package:foodvision/features/results/analysis_provider.dart';
import 'package:foodvision/features/results/consensus_provider.dart';
import 'package:foodvision/features/settings/settings_screen.dart';

class ConsensusCard extends ConsumerWidget {
  final AnalyzeMealResponse cloudAnalysis;

  const ConsensusCard({
    super.key,
    required this.cloudAnalysis,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consensusState = ref.watch(consensusProvider);
    final consensusNotifier = ref.read(consensusProvider.notifier);
    final captureState = ref.watch(captureProvider);

    // If user does not have Deep Local AI permission, hide the consensus card entirely.
    // The mobile experience strictly relies on Gemini cloud vision as it did prior to hybrid implementation.
    if (!consensusState.hasPermission) {
      return const SizedBox.shrink();
    }

    // If consensus is already finalized, show the verified banner
    if (consensusState.synthesizedResponse != null) {
      final syn = consensusState.synthesizedResponse!;
      return Card(
        color: Colors.green.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.green.shade300),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.verified, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Consensus Verified by Gemini Arbitrator',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                syn.consensusSummary,
                style: TextStyle(fontSize: 13, color: Colors.green.shade900),
              ),
              if (syn.adjustmentsMade.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Arbitrated Adjustments:',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                ...syn.adjustmentsMade.map(
                  (adj) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: Colors.green.shade700)),
                        Expanded(
                          child: Text(
                            adj,
                            style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(analysisProvider.notifier).updateWithResponse(
                        syn.toAnalyzeMealResponse(),
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Consensus items applied to active meal!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Apply Consensus to Meal'),
              ),
            ],
          ),
        ),
      );
    }

    // If local AI is currently analyzing
    if (consensusState.isLocalAnalyzing) {
      return Card(
        color: Colors.indigo.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Deep Local AI Agent Evaluating...',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ),
                  Text(
                    '${consensusState.elapsedSeconds}s',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Inspecting food surface texture, gloss/sheen for cooking oils/ghee, and layered ingredients on your local Ollama server...',
                style: TextStyle(fontSize: 12, color: Colors.indigo.shade700),
              ),
            ],
          ),
        ),
      );
    }

    // If local AI completed and waiting to re-sync
    if (consensusState.localResult != null) {
      final local = consensusState.localResult!;
      return Card(
        color: Colors.indigo.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.indigo.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.hub, color: Colors.indigo.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local AI Evaluation Complete',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.indigo.shade900,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      '${local.latencySeconds.toStringAsFixed(1)}s',
                      style: const TextStyle(fontSize: 11, color: Colors.indigo),
                    ),
                    backgroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                local.notes,
                style: TextStyle(fontSize: 13, color: Colors.indigo.shade900),
              ),
              const SizedBox(height: 10),
              Text(
                'Local Model Findings (${local.items.length} items):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.indigo.shade800,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: local.items.map((i) {
                  return Chip(
                    label: Text('${i.label} (${i.gramsEstimate}g)'),
                    avatar: Icon(
                      i.visualCue != null ? Icons.visibility : Icons.fastfood,
                      size: 14,
                      color: Colors.indigo.shade700,
                    ),
                    backgroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
              if (local.detectedOilSheen) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wb_sunny, size: 16, color: Colors.amber.shade900),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Oil/Butter sheen detected by local vision model.',
                          style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (consensusState.isSynthesizing)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => consensusNotifier.finalizeConsensus(
                      cloudAnalysis: cloudAnalysis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('Re-Sync & Finalize Consensus (Gemini Arbitrator)'),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Default: Check reachability / Prompt for Deep Local AI
    if (consensusState.isReachable) {
      return Card(
        color: Colors.blue.shade50,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deep AI Second Opinion Available',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'LAN Connected',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Run a detailed second-opinion evaluation via your local AI agent (${consensusState.hostDisplay}) to inspect texture, hidden cooking fats, and portion weight.',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final photos = captureState.photoPaths;
                    if (photos.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No photo files found to analyze.')),
                      );
                      return;
                    }
                    consensusNotifier.runDeepLocalEvaluation(imagePaths: photos);
                  },
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Request Deep Local AI Evaluation'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // If unreachable on LAN
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Local AI Agent (${consensusState.hostDisplay}) unreachable. Verify Wi-Fi or update host in Settings.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
          TextButton(
            onPressed: () => consensusNotifier.checkAvailability(),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: const Text('Retry', style: TextStyle(fontSize: 11)),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 16),
            tooltip: 'Configure Local AI Host',
            visualDensity: VisualDensity.compact,
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              consensusNotifier.checkAvailability();
            },
          ),
        ],
      ),
    );
  }
}
