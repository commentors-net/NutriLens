import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/api/food_vision_client.dart';
import 'package:foodvision/core/auth/auth_service.dart';
import 'package:foodvision/core/models/analyze_response.dart';
import 'package:foodvision/core/models/synthesize_response.dart';
import 'package:foodvision/core/services/local_ai_service.dart';

class ConsensusState {
  final bool hasPermission;
  final bool isReachable;
  final bool isCheckingReachability;
  final bool isLocalAnalyzing;
  final bool isSynthesizing;
  final int elapsedSeconds;
  final String configuredUrl;
  final LocalAiResult? localResult;
  final SynthesizeMealResponse? synthesizedResponse;
  final String? error;

  const ConsensusState({
    this.hasPermission = false,
    this.isReachable = false,
    this.isCheckingReachability = false,
    this.isLocalAnalyzing = false,
    this.isSynthesizing = false,
    this.elapsedSeconds = 0,
    this.configuredUrl = '',
    this.localResult,
    this.synthesizedResponse,
    this.error,
  });

  String get hostDisplay {
    if (configuredUrl.isEmpty) return 'Local Agent';
    try {
      final uri = Uri.parse(configuredUrl);
      if (uri.host.isNotEmpty) {
        return uri.port != 0 && uri.port != 80 && uri.port != 443
            ? '${uri.host}:${uri.port}'
            : uri.host;
      }
      return configuredUrl;
    } catch (_) {
      return configuredUrl;
    }
  }

  ConsensusState copyWith({
    bool? hasPermission,
    bool? isReachable,
    bool? isCheckingReachability,
    bool? isLocalAnalyzing,
    bool? isSynthesizing,
    int? elapsedSeconds,
    String? configuredUrl,
    LocalAiResult? localResult,
    SynthesizeMealResponse? synthesizedResponse,
    String? error,
    bool clearError = false,
    bool clearSynthesized = false,
  }) {
    return ConsensusState(
      hasPermission: hasPermission ?? this.hasPermission,
      isReachable: isReachable ?? this.isReachable,
      isCheckingReachability: isCheckingReachability ?? this.isCheckingReachability,
      isLocalAnalyzing: isLocalAnalyzing ?? this.isLocalAnalyzing,
      isSynthesizing: isSynthesizing ?? this.isSynthesizing,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      configuredUrl: configuredUrl ?? this.configuredUrl,
      localResult: localResult ?? this.localResult,
      synthesizedResponse: clearSynthesized ? null : (synthesizedResponse ?? this.synthesizedResponse),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ConsensusNotifier extends StateNotifier<ConsensusState> {
  final LocalAiService _localAiService;
  final FoodVisionClient _client;
  final AuthService _authService;
  Timer? _timer;

  ConsensusNotifier({
    required LocalAiService localAiService,
    required FoodVisionClient client,
    required AuthService authService,
  })  : _localAiService = localAiService,
        _client = client,
        _authService = authService,
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
    final hasPermission = await _authService.canAccessDeepLocalAi();
    if (!hasPermission) {
      state = state.copyWith(
        hasPermission: false,
        isReachable: false,
        isCheckingReachability: false,
      );
      return;
    }

    final url = await _localAiService.getBaseUrl();
    final enabled = await _localAiService.isEnabled();
    if (!enabled) {
      state = state.copyWith(
        hasPermission: true,
        isReachable: false,
        isCheckingReachability: false,
        configuredUrl: url,
      );
      return;
    }

    final reachable = await _localAiService.checkReachability();
    state = state.copyWith(
      hasPermission: true,
      isReachable: reachable,
      isCheckingReachability: false,
      configuredUrl: url,
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
  final authService = ref.watch(authServiceProvider);
  return ConsensusNotifier(
    localAiService: localAi,
    client: client,
    authService: authService,
  );
});
