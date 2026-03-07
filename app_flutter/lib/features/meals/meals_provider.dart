import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/models/meal_draft.dart';
import '../../core/storage/meal_draft_db.dart';

/// Provider for meal draft database
final mealDraftDbProvider = Provider<MealDraftDatabase>((ref) {
  return MealDraftDatabase.instance;
});

/// Provider for all meal drafts
final mealDraftsProvider = StreamProvider<List<MealDraft>>((ref) async* {
  final db = ref.watch(mealDraftDbProvider);
  
  // Initial load
  yield await db.getAllDrafts();
  
  // For real-time updates, we'd need a stream. For now, refresh on read.
  while (true) {
    await Future.delayed(const Duration(seconds: 2));
    yield await db.getAllDrafts();
  }
});

/// Provider for all saved (analyzed) meals
final savedMealsProvider = StreamProvider<List<SavedMeal>>((ref) async* {
  final db = ref.watch(mealDraftDbProvider);
  
  yield await db.getAllSavedMeals();
  
  while (true) {
    await Future.delayed(const Duration(seconds: 2));
    yield await db.getAllSavedMeals();
  }
});

/// Controller for managing meal drafts
class MealDraftsController extends StateNotifier<AsyncValue<void>> {
  final MealDraftDatabase _db;
  final Ref _ref;

  MealDraftsController(this._db, this._ref) : super(const AsyncValue.data(null));

  /// Save a new draft
  Future<String> saveDraft({
    required String name,
    required List<String> photoPaths,
  }) async {
    state = const AsyncValue.loading();
    try {
      final draft = MealDraft(
        id: const Uuid().v4(),
        name: name,
        photoPaths: photoPaths,
        createdAt: DateTime.now(),
      );
      
      await _db.insertDraft(draft);
      state = const AsyncValue.data(null);
      
      // Refresh the list
      _ref.invalidate(mealDraftsProvider);
      
      return draft.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update draft name
  Future<void> updateDraftName(String id, String newName) async {
    final draft = await _db.getDraftById(id);
    if (draft == null) return;
    
    await _db.updateDraft(draft.copyWith(name: newName));
    _ref.invalidate(mealDraftsProvider);
  }

  /// Delete a draft
  Future<void> deleteDraft(String id) async {
    await _db.deleteDraft(id);
    _ref.invalidate(mealDraftsProvider);
  }

  /// Mark draft as analyzed
  Future<void> markAsAnalyzed(String id, String analysisId) async {
    final draft = await _db.getDraftById(id);
    if (draft == null) return;
    
    await _db.updateDraft(draft.copyWith(
      isAnalyzed: true,
      analyzedAt: DateTime.now(),
      analysisId: analysisId,
    ));
    _ref.invalidate(mealDraftsProvider);
  }
}

final mealDraftsControllerProvider =
    StateNotifierProvider<MealDraftsController, AsyncValue<void>>((ref) {
  return MealDraftsController(ref.watch(mealDraftDbProvider), ref);
});

/// Controller for managing saved meals
class SavedMealsController extends StateNotifier<AsyncValue<void>> {
  final MealDraftDatabase _db;
  final Ref _ref;

  SavedMealsController(this._db, this._ref) : super(const AsyncValue.data(null));

  /// Save analyzed meal
  Future<String> saveMeal(SavedMeal meal) async {
    state = const AsyncValue.loading();
    try {
      await _db.insertSavedMeal(meal);
      state = const AsyncValue.data(null);
      _ref.invalidate(savedMealsProvider);
      return meal.id;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update meal name
  Future<void> updateMealName(String id, String newName) async {
    final meal = await _db.getSavedMealById(id);
    if (meal == null) return;
    
    await _db.updateSavedMeal(meal.copyWith(name: newName));
    _ref.invalidate(savedMealsProvider);
  }

  /// Update meal items
  Future<void> updateMealItems(String id, List<MealItem> items) async {
    final meal = await _db.getSavedMealById(id);
    if (meal == null) return;
    
    await _db.updateSavedMeal(meal.copyWith(items: items));
    _ref.invalidate(savedMealsProvider);
  }

  /// Delete a saved meal
  Future<void> deleteMeal(String id) async {
    await _db.deleteSavedMeal(id);
    _ref.invalidate(savedMealsProvider);
  }
}

final savedMealsControllerProvider =
    StateNotifierProvider<SavedMealsController, AsyncValue<void>>((ref) {
  return SavedMealsController(ref.watch(mealDraftDbProvider), ref);
});
