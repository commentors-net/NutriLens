import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/api/food_vision_client.dart';
import 'package:foodvision/core/models/analyze_response.dart';
import 'package:foodvision/core/models/synthesize_response.dart';
import 'package:foodvision/core/services/local_ai_service.dart';

class ConsensusState {
  final bool isReachable;
  final bool isCheckingReachability;
  final bool isLocalAnalyzing;
  final bool isSynthesizing;
  final int elapsedSeconds;
  final LocalAiResult? localResult;
  final SynthesizeMealResponse? synthesizedResponse;
  final String? error;

  const ConsensusState({
    this.isReachable = false,
    this.isCheckingReachability = false,
    this.isLocalAnalyzing = false,
    this.isSynthesizing = false,
    this.elapsedSeconds = 0,
    this.localResult,
    this.synthesizedResponse,
    this.error,
  });

  ConsensusState copyWith({
    bool? isReachable,
    bool? isCheckingReachability,
    bool? isLocalAnalyzing,
    bool? isSynthesizing,
    int? elapsedSeconds,
    LocalAiResult? localResult,
    SynthesizeMealResponse? synthesizedResponse,
    String? error,
    bool clearError = false,
    bool clearSynthesized = false,
  }) {
    return ConsensusState(
      isReachable: isReachable ?? this.isReachable,
      isCheckingReachability: isCheckingReachability ?? this.isCheckingReachability,
      isLocalAnalyzing: isLocalAnalyzing ?? this.isLocalAnalyzing,
      isSynthesizing: isSynthesizing ?? this.isSynthesizing,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      localResult: localResult ?? this.localResult,
      synthesizedResponse: clearSynthesized ? null : (synthesizedResponse ?? this.synthesizedResponse),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ConsensusNotifier extends StateNotifier<ConsensusState> {
  final LocalAiService _localAiService;
  final FoodVisionClient _client;
  Timer? _timer;

  ConsensusNotifier({
    required LocalAiService localAiService,
    required FoodVisionClient client,
  })  : _localAiService = localAiService,
        _client = client,
        super(const ConsensusState()) {
    checkAvailability();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> checkAvailability() async {
    state = state.copyWith(isCheckingReachability: true);
    final enabled = await _localAiService.isEnabled();
    if (!enabled) {
      state = state.copyWith(isReachable: false, isCheckingReachability: false);
      return;
    }

    final reachable = await _localAiService.checkReachability();
    state = state.copyWith(
      isReachable: reachable,
      isCheckingReachability: false,
    );
  }

  Future<void> runDeepLocalEvaluation({
    required List<String> imagePaths,
    String? notes,
  }) async {
    state = state.copyWith(
      isLocalAnalyzing: true,
      elapsedSeconds: 0,
      clearError: true,
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });

    try {
      final result = await _localAiService.analyzeMealImages(
        imagePaths: imagePaths,
        userNote: notes,
      );
      _timer?.cancel();
      state = state.copyWith(
        isLocalAnalyzing: false,
        localResult: result,
      );
    } catch (e) {
      _timer?.cancel();
      state = state.copyWith(
        isLocalAnalyzing: false,
        error: 'Local AI Evaluation failed: $e',
      );
    }
  }

  Future<SynthesizeMealResponse?> finalizeConsensus({
    required AnalyzeMealResponse cloudAnalysis,
    String? mealId,
    String? notes,
  }) async {
    if (state.localResult == null) return null;

    state = state.copyWith(isSynthesizing: true, clearError: true);

    try {
      final response = await _client.synthesizeMeal(
        mealId: mealId,
        cloudAnalysis: cloudAnalysis.toJson(),
        localAnalysis: state.localResult!.toJson(),
        notes: notes,
      );

      state = state.copyWith(
        isSynthesizing: false,
        synthesizedResponse: response,
      );
      return response;
    } catch (e) {
      state = state.copyWith(
        isSynthesizing: false,
        error: 'Consensus synthesis failed: $e',
      );
      return null;
    }
  }

  void reset() {
    _timer?.cancel();
    state = const ConsensusState();
    checkAvailability();
  }
}

final consensusProvider =
    StateNotifierProvider<ConsensusNotifier, ConsensusState>((ref) {
  final localAi = ref.watch(localAiServiceProvider);
  final client = ref.watch(foodVisionClientProvider);
  return ConsensusNotifier(localAiService: localAi, client: client);
});
