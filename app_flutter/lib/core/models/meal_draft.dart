/// Local meal draft model for offline storage
class MealDraft {
  final String id;
  final String name;
  final List<String> photoPaths;
  final DateTime createdAt;
  final DateTime? analyzedAt;
  final String? analysisId;
  final bool isAnalyzed;

  const MealDraft({
    required this.id,
    required this.name,
    required this.photoPaths,
    required this.createdAt,
    this.analyzedAt,
    this.analysisId,
    this.isAnalyzed = false,
  });

  MealDraft copyWith({
    String? name,
    List<String>? photoPaths,
    DateTime? analyzedAt,
    String? analysisId,
    bool? isAnalyzed,
  }) {
    return MealDraft(
      id: id,
      name: name ?? this.name,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt,
      analyzedAt: analyzedAt ?? this.analyzedAt,
      analysisId: analysisId ?? this.analysisId,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
    );
  }
}

/// Analyzed meal item (after API response)
class MealItem {
  final String itemId;
  final String label;
  final double grams;
  final double kcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const MealItem({
    required this.itemId,
    required this.label,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      itemId: json['item_id'] as String,
      label: json['label'] as String,
      grams: (json['grams_estimate'] as num).toDouble(),
      kcal: (json['macros']['kcal'] as num).toDouble(),
      proteinG: (json['macros']['protein_g'] as num).toDouble(),
      carbsG: (json['macros']['carbs_g'] as num).toDouble(),
      fatG: (json['macros']['fat_g'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item_id': itemId,
      'label': label,
      'grams_estimate': grams,
      'macros': {
        'kcal': kcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      },
    };
  }

  MealItem copyWith({
    String? label,
    double? grams,
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
  }) {
    return MealItem(
      itemId: itemId,
      label: label ?? this.label,
      grams: grams ?? this.grams,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      carbsG: carbsG ?? this.carbsG,
      fatG: fatG ?? this.fatG,
    );
  }
}

/// Saved meal with analysis results
class SavedMeal {
  final String id;
  final String name;
  final DateTime analyzedAt;
  final List<MealItem> items;
  final double totalKcal;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;

  const SavedMeal({
    required this.id,
    required this.name,
    required this.analyzedAt,
    required this.items,
    required this.totalKcal,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
  });

  factory SavedMeal.fromJson(Map<String, dynamic> json) {
    return SavedMeal(
      id: json['id'] as String,
      name: json['name'] as String,
      analyzedAt: DateTime.parse(json['analyzed_at'] as String),
      items: (json['items'] as List)
          .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalKcal: (json['total_kcal'] as num).toDouble(),
      totalProteinG: (json['total_protein_g'] as num).toDouble(),
      totalCarbsG: (json['total_carbs_g'] as num).toDouble(),
      totalFatG: (json['total_fat_g'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'analyzed_at': analyzedAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
      'total_kcal': totalKcal,
      'total_protein_g': totalProteinG,
      'total_carbs_g': totalCarbsG,
      'total_fat_g': totalFatG,
    };
  }

  SavedMeal copyWith({
    String? name,
    List<MealItem>? items,
  }) {
    // Recalculate totals if items changed
    final newItems = items ?? this.items;
    final newTotalKcal = newItems.fold<double>(0, (sum, item) => sum + item.kcal);
    final newTotalProteinG = newItems.fold<double>(0, (sum, item) => sum + item.proteinG);
    final newTotalCarbsG = newItems.fold<double>(0, (sum, item) => sum + item.carbsG);
    final newTotalFatG = newItems.fold<double>(0, (sum, item) => sum + item.fatG);

    return SavedMeal(
      id: id,
      name: name ?? this.name,
      analyzedAt: analyzedAt,
      items: newItems,
      totalKcal: newTotalKcal,
      totalProteinG: newTotalProteinG,
      totalCarbsG: newTotalCarbsG,
      totalFatG: newTotalFatG,
    );
  }
}
