import 'package:foodvision/core/models/analyze_response.dart';

class SynthesizeMealResponse {
  final String consensusSummary;
  final List<String> adjustmentsMade;
  final List<AnalyzeItem> items;
  final Macros totalMacros;
  final double overallConfidence;
  final String consensusMethod;

  const SynthesizeMealResponse({
    required this.consensusSummary,
    required this.adjustmentsMade,
    required this.items,
    required this.totalMacros,
    required this.overallConfidence,
    this.consensusMethod = 'gemini_arbitrated_consensus',
  });

  factory SynthesizeMealResponse.fromJson(Map<String, dynamic> json) {
    return SynthesizeMealResponse(
      consensusSummary: json['consensus_summary'] as String? ?? 'Consensus achieved between Cloud and Local AI.',
      adjustmentsMade: List<String>.from(json['adjustments_made'] as List? ?? []),
      items: (json['items'] as List? ?? [])
          .map((item) => AnalyzeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      totalMacros: json['total_macros'] != null
          ? Macros.fromJson(json['total_macros'] as Map<String, dynamic>)
          : Macros(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0),
      overallConfidence: (json['overall_confidence'] as num?)?.toDouble() ?? 0.85,
      consensusMethod: json['consensus_method'] as String? ?? 'gemini_arbitrated_consensus',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consensus_summary': consensusSummary,
      'adjustments_made': adjustmentsMade,
      'items': items.map((i) => i.toJson()).toList(),
      'total_macros': totalMacros.toJson(),
      'overall_confidence': overallConfidence,
      'consensus_method': consensusMethod,
    };
  }

  AnalyzeMealResponse toAnalyzeMealResponse() {
    return AnalyzeMealResponse(
      overallConfidence: overallConfidence,
      needsMorePhotos: false,
      suggestedNextShots: const [],
      items: items,
      warnings: adjustmentsMade,
    );
  }
}
