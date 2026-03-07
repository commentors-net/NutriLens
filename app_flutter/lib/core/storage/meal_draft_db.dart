import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/meal_draft.dart';

/// Local database for storing meal drafts and analyzed meals
class MealDraftDatabase {
  static final MealDraftDatabase instance = MealDraftDatabase._internal();
  static Database? _database;

  MealDraftDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'meal_drafts.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Meal drafts table (photos saved, not yet analyzed)
    await db.execute('''
      CREATE TABLE meal_drafts(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        photo_paths TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        analyzed_at INTEGER,
        analysis_id TEXT,
        is_analyzed INTEGER DEFAULT 0
      )
    ''');

    // Saved meals table (analyzed results)
    await db.execute('''
      CREATE TABLE saved_meals(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        analyzed_at INTEGER NOT NULL,
        items TEXT NOT NULL,
        total_kcal REAL NOT NULL,
        total_protein_g REAL NOT NULL,
        total_carbs_g REAL NOT NULL,
        total_fat_g REAL NOT NULL
      )
    ''');
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Meal Drafts (unanalyzed photos)
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> insertDraft(MealDraft draft) async {
    final db = await database;
    await db.insert(
      'meal_drafts',
      {
        'id': draft.id,
        'name': draft.name,
        'photo_paths': jsonEncode(draft.photoPaths),
        'created_at': draft.createdAt.millisecondsSinceEpoch,
        'analyzed_at': draft.analyzedAt?.millisecondsSinceEpoch,
        'analysis_id': draft.analysisId,
        'is_analyzed': draft.isAnalyzed ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return draft.id;
  }

  Future<List<MealDraft>> getAllDrafts() async {
    final db = await database;
    final maps = await db.query(
      'meal_drafts',
      orderBy: 'created_at DESC',
    );

    return maps.map((map) {
      return MealDraft(
        id: map['id'] as String,
        name: map['name'] as String,
        photoPaths: (jsonDecode(map['photo_paths'] as String) as List)
            .map((e) => e as String)
            .toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        analyzedAt: map['analyzed_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['analyzed_at'] as int)
            : null,
        analysisId: map['analysis_id'] as String?,
        isAnalyzed: (map['is_analyzed'] as int) == 1,
      );
    }).toList();
  }

  Future<MealDraft?> getDraftById(String id) async {
    final db = await database;
    final maps = await db.query(
      'meal_drafts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return MealDraft(
      id: map['id'] as String,
      name: map['name'] as String,
      photoPaths: (jsonDecode(map['photo_paths'] as String) as List)
          .map((e) => e as String)
          .toList(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      analyzedAt: map['analyzed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['analyzed_at'] as int)
          : null,
      analysisId: map['analysis_id'] as String?,
      isAnalyzed: (map['is_analyzed'] as int) == 1,
    );
  }

  Future<void> updateDraft(MealDraft draft) async {
    final db = await database;
    await db.update(
      'meal_drafts',
      {
        'name': draft.name,
        'photo_paths': jsonEncode(draft.photoPaths),
        'analyzed_at': draft.analyzedAt?.millisecondsSinceEpoch,
        'analysis_id': draft.analysisId,
        'is_analyzed': draft.isAnalyzed ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [draft.id],
    );
  }

  Future<void> deleteDraft(String id) async {
    final db = await database;
    await db.delete(
      'meal_drafts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Saved Meals (analyzed results)
  // ──────────────────────────────────────────────────────────────────────────

  Future<String> insertSavedMeal(SavedMeal meal) async {
    final db = await database;
    await db.insert(
      'saved_meals',
      {
        'id': meal.id,
        'name': meal.name,
        'analyzed_at': meal.analyzedAt.millisecondsSinceEpoch,
        'items': jsonEncode(meal.items.map((e) => e.toJson()).toList()),
        'total_kcal': meal.totalKcal,
        'total_protein_g': meal.totalProteinG,
        'total_carbs_g': meal.totalCarbsG,
        'total_fat_g': meal.totalFatG,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return meal.id;
  }

  Future<List<SavedMeal>> getAllSavedMeals() async {
    final db = await database;
    final maps = await db.query(
      'saved_meals',
      orderBy: 'analyzed_at DESC',
    );

    return maps.map((map) {
      final itemsJson = jsonDecode(map['items'] as String) as List;
      return SavedMeal(
        id: map['id'] as String,
        name: map['name'] as String,
        analyzedAt: DateTime.fromMillisecondsSinceEpoch(map['analyzed_at'] as int),
        items: itemsJson
            .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalKcal: map['total_kcal'] as double,
        totalProteinG: map['total_protein_g'] as double,
        totalCarbsG: map['total_carbs_g'] as double,
        totalFatG: map['total_fat_g'] as double,
      );
    }).toList();
  }

  Future<SavedMeal?> getSavedMealById(String id) async {
    final db = await database;
    final maps = await db.query(
      'saved_meals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final itemsJson = jsonDecode(map['items'] as String) as List;
    return SavedMeal(
      id: map['id'] as String,
      name: map['name'] as String,
      analyzedAt: DateTime.fromMillisecondsSinceEpoch(map['analyzed_at'] as int),
      items: itemsJson
          .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalKcal: map['total_kcal'] as double,
      totalProteinG: map['total_protein_g'] as double,
      totalCarbsG: map['total_carbs_g'] as double,
      totalFatG: map['total_fat_g'] as double,
    );
  }

  Future<void> updateSavedMeal(SavedMeal meal) async {
    final db = await database;
    await db.update(
      'saved_meals',
      {
        'name': meal.name,
        'items': jsonEncode(meal.items.map((e) => e.toJson()).toList()),
        'total_kcal': meal.totalKcal,
        'total_protein_g': meal.totalProteinG,
        'total_carbs_g': meal.totalCarbsG,
        'total_fat_g': meal.totalFatG,
      },
      where: 'id = ?',
      whereArgs: [meal.id],
    );
  }

  Future<void> deleteSavedMeal(String id) async {
    final db = await database;
    await db.delete(
      'saved_meals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
