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

  AnalyzeItem({
    required this.itemId,
    required this.label,
    required this.labelConfidence,
    required this.gramsEstimate,
    required this.gramsRange,
    required this.gramsConfidence,
    required this.macros,
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

  Map<String, dynamic> toJson() {
    return {
      'kcal': kcal,
      'protein_g': proteinG,
      'carbs_g': carbsG,
      'fat_g': fatG,
    };
  }
}
