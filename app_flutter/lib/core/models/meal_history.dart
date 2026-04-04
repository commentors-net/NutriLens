class MealHistoryItem {
  final String mealId;
  final DateTime timestamp;
  final int itemCount;
  final int totalKcal;
  final List<MealHistoryFoodItem> items;
  final String notes;
  final List<String> imageUrls;

  MealHistoryItem({
    required this.mealId,
    required this.timestamp,
    required this.itemCount,
    required this.totalKcal,
    required this.items,
    required this.notes,
    this.imageUrls = const [],
  });

  factory MealHistoryItem.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? []);
    final rawImageUrls = (json['image_urls'] as List<dynamic>? ?? []);
    return MealHistoryItem(
      mealId: json['meal_id'] as String? ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      itemCount: (json['item_count'] as num?)?.toInt() ?? rawItems.length,
      totalKcal: (json['total_kcal'] as num?)?.toInt() ?? 0,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map(MealHistoryFoodItem.fromJson)
          .toList(),
      notes: json['notes'] as String? ?? '',
      imageUrls: rawImageUrls.whereType<String>().toList(),
    );
  }
}

class MealHistoryFoodItem {
  final String label;
  final double grams;
  final int kcal;

  MealHistoryFoodItem({
    required this.label,
    required this.grams,
    required this.kcal,
  });

  factory MealHistoryFoodItem.fromJson(Map<String, dynamic> json) {
    return MealHistoryFoodItem(
      label: json['label'] as String? ?? 'food',
      grams: (json['grams'] as num?)?.toDouble() ?? 0,
      kcal: (json['kcal'] as num?)?.toInt() ?? 0,
    );
  }
}

class MealHistoryResponse {
  final int totalKcal;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final int mealCount;
  final List<MealHistoryItem> meals;

  MealHistoryResponse({
    required this.totalKcal,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.mealCount,
    required this.meals,
  });

  factory MealHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawMeals = (json['meals'] as List<dynamic>? ?? []);
    return MealHistoryResponse(
      totalKcal: (json['total_kcal'] as num?)?.toInt() ?? 0,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0,
      mealCount: (json['meal_count'] as num?)?.toInt() ?? rawMeals.length,
      meals: rawMeals
          .whereType<Map<String, dynamic>>()
          .map(MealHistoryItem.fromJson)
          .toList(),
    );
  }
}
