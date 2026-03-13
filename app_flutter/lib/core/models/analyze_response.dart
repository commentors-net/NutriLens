/// Strongly-typed models for analyze meal response.
/// Corresponds to shared/schemas/analyze_meal_response.schema.json

class AnalyzeMealResponse {
  final double overallConfidence;
  final bool needsMorePhotos;
  final List<String> suggestedNextShots;
  final List<AnalyzeItem> items;
  final List<String> warnings;

  AnalyzeMealResponse({
    required this.overallConfidence,
    required this.needsMorePhotos,
    required this.suggestedNextShots,
    required this.items,
    required this.warnings,
  });

  factory AnalyzeMealResponse.fromJson(Map<String, dynamic> json) {
    return AnalyzeMealResponse(
      overallConfidence: (json['overall_confidence'] as num).toDouble(),
      needsMorePhotos: json['needs_more_photos'] as bool,
      suggestedNextShots: List<String>.from(json['suggested_next_shots'] as List),
      items: (json['items'] as List)
          .map((item) => AnalyzeItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      warnings: List<String>.from(json['warnings'] as List? ?? []),
    );
  }

  AnalyzeMealResponse copyWith({
    double? overallConfidence,
    bool? needsMorePhotos,
    List<String>? suggestedNextShots,
    List<AnalyzeItem>? items,
    List<String>? warnings,
  }) {
    return AnalyzeMealResponse(
      overallConfidence: overallConfidence ?? this.overallConfidence,
      needsMorePhotos: needsMorePhotos ?? this.needsMorePhotos,
      suggestedNextShots: suggestedNextShots ?? this.suggestedNextShots,
      items: items ?? this.items,
      warnings: warnings ?? this.warnings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'overall_confidence': overallConfidence,
      'needs_more_photos': needsMorePhotos,
      'suggested_next_shots': suggestedNextShots,
      'items': items.map((item) => item.toJson()).toList(),
      'warnings': warnings,
    };
  }
}

class AnalyzeItem {
  final String itemId;
  final String label;
  final double labelConfidence;
  final int gramsEstimate;
  final GramsRange gramsRange;
  final double gramsConfidence;
  final Macros macros;
  final String originalLabel;
  final int originalGramsEstimate;

  AnalyzeItem({
    required this.itemId,
    required this.label,
    required this.labelConfidence,
    required this.gramsEstimate,
    required this.gramsRange,
    required this.gramsConfidence,
    required this.macros,
    required this.originalLabel,
    required this.originalGramsEstimate,
  });

  factory AnalyzeItem.fromJson(Map<String, dynamic> json) {
    return AnalyzeItem(
      itemId: json['item_id'] as String,
      label: json['label'] as String,
      labelConfidence: (json['label_confidence'] as num).toDouble(),
      gramsEstimate: json['grams_estimate'] as int,
      gramsRange: GramsRange.fromJson(json['grams_range'] as Map<String, dynamic>),
      gramsConfidence: (json['grams_confidence'] as num).toDouble(),
      macros: Macros.fromJson(json['macros'] as Map<String, dynamic>),
      originalLabel: json['original_label'] as String? ?? json['label'] as String,
      originalGramsEstimate:
          json['original_grams_estimate'] as int? ?? json['grams_estimate'] as int,
    );
  }

  bool get isCorrected =>
      label != originalLabel || gramsEstimate != originalGramsEstimate;

  AnalyzeItem copyWith({
    String? label,
    double? labelConfidence,
    int? gramsEstimate,
    GramsRange? gramsRange,
    double? gramsConfidence,
    Macros? macros,
    String? originalLabel,
    int? originalGramsEstimate,
  }) {
    return AnalyzeItem(
      itemId: itemId,
      label: label ?? this.label,
      labelConfidence: labelConfidence ?? this.labelConfidence,
      gramsEstimate: gramsEstimate ?? this.gramsEstimate,
      gramsRange: gramsRange ?? this.gramsRange,
      gramsConfidence: gramsConfidence ?? this.gramsConfidence,
      macros: macros ?? this.macros,
      originalLabel: originalLabel ?? this.originalLabel,
      originalGramsEstimate: originalGramsEstimate ?? this.originalGramsEstimate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'label': label,
      'label_confidence': labelConfidence,
      'grams_estimate': gramsEstimate,
      'grams_range': gramsRange.toJson(),
      'grams_confidence': gramsConfidence,
      'macros': macros.toJson(),
      'original_label': originalLabel,
      'original_grams_estimate': originalGramsEstimate,
    };
  }
}

class GramsRange {
  final int min;
  final int max;

  GramsRange({required this.min, required this.max});

  factory GramsRange.fromJson(Map<String, dynamic> json) {
    return GramsRange(
      min: json['min'] as int,
      max: json['max'] as int,
    );
  }

  GramsRange copyWith({int? min, int? max}) {
    return GramsRange(
      min: min ?? this.min,
      max: max ?? this.max,
    );
  }

  Map<String, dynamic> toJson() {
    return {'min': min, 'max': max};
  }
}

class Macros {
  final int kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  Macros({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory Macros.fromJson(Map<String, dynamic> json) {
    return Macros(
      kcal: json['kcal'] as int,
      proteinG: (json['protein_g'] as num).toDouble(),
      carbsG: (json['carbs_g'] as num).toDouble(),
      fatG: (json['fat_g'] as num).toDouble(),
    );
  }

  Macros copyWith({
    int? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) {
    return Macros(
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kcal': kcal,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
    };
  }
}
