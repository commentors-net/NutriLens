import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/meal_draft.dart';
import 'meals_provider.dart';
import 'meal_detail_screen.dart';

/// Screen showing saved meal drafts and analyzed meals
class SavedMealsScreen extends ConsumerWidget {
  const SavedMealsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draftsAsync = ref.watch(mealDraftsProvider);
    final savedAsync = ref.watch(savedMealsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Meals'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.photo_library), text: 'Drafts'),
              Tab(icon: Icon(Icons.check_circle), text: 'Analyzed'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Drafts tab
            draftsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (drafts) => _DraftsListView(drafts: drafts),
            ),
            // Analyzed meals tab
            savedAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (meals) => _SavedMealsListView(meals: meals),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Drafts List ─────────────────────────────────────────────────────────────

class _DraftsListView extends ConsumerWidget {
  final List<MealDraft> drafts;

  const _DraftsListView({required this.drafts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (drafts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No saved meals yet', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 8),
            Text('Take photos and save for later',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: drafts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final draft = drafts[index];
        return _DraftCard(draft: draft);
      },
    );
  }
}

class _DraftCard extends ConsumerWidget {
  final MealDraft draft;

  const _DraftCard({required this.draft});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MealDetailScreen(draftId: draft.id),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo preview
            SizedBox(
              height: 120,
              child: draft.photoPaths.isEmpty
                  ? Container(color: Colors.grey[300])
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: draft.photoPaths.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Image.file(
                            File(draft.photoPaths[index]),
                            fit: BoxFit.cover,
                            width: 120,
                            errorBuilder: (_, __, ___) => Container(
                              width: 120,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          draft.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'rename') {
                            _showRenameDialog(context, ref, draft);
                          } else if (value == 'delete') {
                            _confirmDelete(context, ref, draft);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            child: Text('Rename'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${draft.photoPaths.length} photo${draft.photoPaths.length != 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    _formatDate(draft.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, MealDraft draft) {
    final controller = TextEditingController(text: draft.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Meal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Meal Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(mealDraftsControllerProvider.notifier)
                  .updateDraftName(draft.id, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MealDraft draft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text('Are you sure you want to delete this meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(mealDraftsControllerProvider.notifier).deleteDraft(draft.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inDays == 0) {
      return 'Today, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// ─── Saved Meals List ────────────────────────────────────────────────────────

class _SavedMealsListView extends ConsumerWidget {
  final List<SavedMeal> meals;

  const _SavedMealsListView({required this.meals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (meals.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No analyzed meals yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: meals.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final meal = meals[index];
        return _SavedMealCard(meal: meal);
      },
    );
  }
}

class _SavedMealCard extends ConsumerWidget {
  final SavedMeal meal;

  const _SavedMealCard({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MealDetailScreen(savedMealId: meal.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meal.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'rename') {
                        _showRenameDialog(context, ref, meal);
                      } else if (value == 'edit') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MealDetailScreen(savedMealId: meal.id),
                          ),
                        );
                      } else if (value == 'delete') {
                        _confirmDelete(context, ref, meal);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'rename', child: Text('Rename')),
                      const PopupMenuItem(value: 'edit', child: Text('Edit Items')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _MacroChip(label: '${meal.totalKcal.toInt()} kcal', color: Colors.orange),
                  const SizedBox(width: 8),
                  _MacroChip(label: 'P: ${meal.totalProteinG.toStringAsFixed(1)}g'),
                  const SizedBox(width: 8),
                  _MacroChip(label: 'C: ${meal.totalCarbsG.toStringAsFixed(1)}g'),
                  const SizedBox(width: 8),
                  _MacroChip(label: 'F: ${meal.totalFatG.toStringAsFixed(1)}g'),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${meal.items.length} item${meal.items.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, SavedMeal meal) {
    final controller = TextEditingController(text: meal.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Meal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Meal Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(savedMealsControllerProvider.notifier)
                  .updateMealName(meal.id, controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, SavedMeal meal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Meal'),
        content: const Text('Are you sure you want to delete this meal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(savedMealsControllerProvider.notifier).deleteMeal(meal.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _MacroChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? Colors.blue).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color ?? Colors.blue,
        ),
      ),
    );
  }
}
