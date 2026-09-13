class NutriLensProfile {
  final int dailyCalorieGoal;
  final double proteinGoalG;
  final double carbsGoalG;
  final double fatGoalG;
  final List<String> dietaryRestrictions;
  final bool notificationsEnabled;
  final String breakfastReminderTime;
  final String lunchReminderTime;
  final String dinnerReminderTime;
  final String feedbackRulesPolicy;

  const NutriLensProfile({
    this.dailyCalorieGoal = 2000,
    this.proteinGoalG = 100.0,
    this.carbsGoalG = 250.0,
    this.fatGoalG = 65.0,
    this.dietaryRestrictions = const [],
    this.notificationsEnabled = false,
    this.breakfastReminderTime = "08:00",
    this.lunchReminderTime = "13:00",
    this.dinnerReminderTime = "19:00",
    this.feedbackRulesPolicy = "inherit",
  });

  factory NutriLensProfile.fromJson(Map<String, dynamic> json) {
    return NutriLensProfile(
      dailyCalorieGoal: (json['daily_calorie_goal'] as num?)?.toInt() ?? 2000,
      proteinGoalG: (json['protein_goal_g'] as num?)?.toDouble() ?? 100.0,
      carbsGoalG: (json['carbs_goal_g'] as num?)?.toDouble() ?? 250.0,
      fatGoalG: (json['fat_goal_g'] as num?)?.toDouble() ?? 65.0,
      dietaryRestrictions: (json['dietary_restrictions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
      breakfastReminderTime: json['breakfast_reminder_time'] as String? ?? "08:00",
      lunchReminderTime: json['lunch_reminder_time'] as String? ?? "13:00",
      dinnerReminderTime: json['dinner_reminder_time'] as String? ?? "19:00",
      feedbackRulesPolicy: json['feedback_rules_policy'] as String? ?? "inherit",
    );
  }

  Map<String, dynamic> toJson() => {
        'daily_calorie_goal': dailyCalorieGoal,
        'protein_goal_g': proteinGoalG,
        'carbs_goal_g': carbsGoalG,
        'fat_goal_g': fatGoalG,
        'dietary_restrictions': dietaryRestrictions,
        'notifications_enabled': notificationsEnabled,
        'breakfast_reminder_time': breakfastReminderTime,
        'lunch_reminder_time': lunchReminderTime,
        'dinner_reminder_time': dinnerReminderTime,
        'feedback_rules_policy': feedbackRulesPolicy,
      };

  NutriLensProfile copyWith({
    int? dailyCalorieGoal,
    double? proteinGoalG,
    double? carbsGoalG,
    double? fatGoalG,
    List<String>? dietaryRestrictions,
    bool? notificationsEnabled,
    String? breakfastReminderTime,
    String? lunchReminderTime,
    String? dinnerReminderTime,
    String? feedbackRulesPolicy,
  }) {
    return NutriLensProfile(
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      proteinGoalG: proteinGoalG ?? this.proteinGoalG,
      carbsGoalG: carbsGoalG ?? this.carbsGoalG,
      fatGoalG: fatGoalG ?? this.fatGoalG,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      breakfastReminderTime: breakfastReminderTime ?? this.breakfastReminderTime,
      lunchReminderTime: lunchReminderTime ?? this.lunchReminderTime,
      dinnerReminderTime: dinnerReminderTime ?? this.dinnerReminderTime,
      feedbackRulesPolicy: feedbackRulesPolicy ?? this.feedbackRulesPolicy,
    );
  }
}
