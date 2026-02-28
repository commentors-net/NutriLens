/// Dart model for GET /meals/today response.

class DailyTotals {
  final int totalKcal;
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final int mealCount;

  const DailyTotals({
    required this.totalKcal,
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.mealCount,
  });

  factory DailyTotals.fromJson(Map<String, dynamic> json) {
    return DailyTotals(
      totalKcal: (json['total_kcal'] as num?)?.toInt() ?? 0,
      totalProteinG: (json['total_protein_g'] as num?)?.toDouble() ?? 0.0,
      totalCarbsG: (json['total_carbs_g'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0.0,
      mealCount: (json['meal_count'] as num?)?.toInt() ?? 0,
    );
  }

  DailyTotals copyWith({
    int? totalKcal,
    double? totalProteinG,
    double? totalCarbsG,
    double? totalFatG,
    int? mealCount,
  }) {
    return DailyTotals(
      totalKcal: totalKcal ?? this.totalKcal,
      totalProteinG: totalProteinG ?? this.totalProteinG,
      totalCarbsG: totalCarbsG ?? this.totalCarbsG,
      totalFatG: totalFatG ?? this.totalFatG,
      mealCount: mealCount ?? this.mealCount,
    );
  }
}
