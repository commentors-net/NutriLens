import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/meal_draft.dart';
import '../../core/storage/meal_draft_db.dart';
import '../../core/api/food_vision_client.dart';
import '../capture/capture_controller.dart';
import '../results/analysis_provider.dart';
import '../../app/router.dart';
import 'meals_provider.dart';

/// Detail screen for viewing and editing a meal draft or saved meal
class MealDetailScreen extends ConsumerStatefulWidget {
  final String? draftId;
  final String? savedMealId;

  const MealDetailScreen({
    Key? key,
    this.draftId,
    this.savedMealId,
  }) : super(key: key);

  @override
  ConsumerState<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends ConsumerState<MealDetailScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (widget.draftId != null) {
      return _buildDraftView(widget.draftId!);
    } else if (widget.savedMealId != null) {
      return _buildSavedMealView(widget.savedMealId!);
    } else {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal Detail')),
        body: const Center(child: Text('No meal specified')),
      );
    }
  }

  Widget _buildDraftView(String draftId) {
    return FutureBuilder<MealDraft?>(
      future: MealDraftDatabase.instance.getDraftById(draftId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final draft = snapshot.data;
        if (draft == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Meal draft not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(draft.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showRenameDialog(draft.name, (newName) {
                  ref
                      .read(mealDraftsControllerProvider.notifier)
                      .updateDraftName(draftId, newName);
                  setState(() {});
                }),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Photos',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: draft.photoPaths.length,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(draft.photoPaths[index]),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${draft.photoPaths.length} photo${draft.photoPaths.length != 1 ? 's' : ''} saved',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              
              // Analyze button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : () => _analyzeDraft(draft),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology),
                    label: Text(_isLoading ? 'Analyzing...' : 'Analyze Meal'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSavedMealView(String mealId) {
    return FutureBuilder<SavedMeal?>(
      future: MealDraftDatabase.instance.getSavedMealById(mealId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Loading...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final meal = snapshot.data;
        if (meal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Not Found')),
            body: const Center(child: Text('Meal not found')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(meal.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showRenameDialog(meal.name, (newName) {
                  ref
                      .read(savedMealsControllerProvider.notifier)
                      .updateMealName(mealId, newName);
                  setState(() {});
                }),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Totals card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Totals',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _MacroColumn('Calories', '${meal.totalKcal.toInt()}', 'kcal'),
                          _MacroColumn('Protein', meal.totalProteinG.toStringAsFixed(1), 'g'),
                          _MacroColumn('Carbs', meal.totalCarbsG.toStringAsFixed(1), 'g'),
                          _MacroColumn('Fat', meal.totalFatG.toStringAsFixed(1), 'g'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Items list
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditItemsDialog(meal),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              ...meal.items.map((item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.label),
                      subtitle: Text('${item.grams.toStringAsFixed(0)}g • ${item.kcal.toInt()} kcal'),
                      trailing: Text(
                        'P:${item.proteinG.toStringAsFixed(1)} C:${item.carbsG.toStringAsFixed(1)} F:${item.fatG.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  void _showRenameDialog(String currentName, Function(String) onSave) {
    final controller = TextEditingController(text: currentName);
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
              onSave(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditItemsDialog(SavedMeal meal) {
    showDialog(
      context: context,
      builder: (context) => _EditItemsDialog(meal: meal, onSave: (items) {
        ref.read(savedMealsControllerProvider.notifier).updateMealItems(meal.id, items);
        setState(() {});
      }),
    );
  }

  Future<void> _analyzeDraft(MealDraft draft) async {
    setState(() => _isLoading = true);

    try {
      // Load photos into capture state
      ref.read(captureProvider.notifier).clear();
      for (final path in draft.photoPaths) {
        ref.read(captureProvider.notifier).addPhoto(path);
      }

      // Trigger analysis
      await ref.read(analysisProvider.notifier).analyze(draft.photoPaths);

      // Navigate to results
      if (mounted) {
        context.push(AppRoutes.results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analysis failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _MacroColumn extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _MacroColumn(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(unit, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}

class _EditItemsDialog extends StatefulWidget {
  final SavedMeal meal;
  final Function(List<MealItem>) onSave;

  const _EditItemsDialog({required this.meal, required this.onSave});

  @override
  State<_EditItemsDialog> createState() => _EditItemsDialogState();
}

class _EditItemsDialogState extends State<_EditItemsDialog> {
  late List<MealItem> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.meal.items);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Items'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return ListTile(
              title: TextField(
                decoration: const InputDecoration(labelText: 'Label'),
                controller: TextEditingController(text: item.label),
                onChanged: (value) {
                  _items[index] = item.copyWith(label: value);
                },
              ),
              subtitle: TextField(
                decoration: const InputDecoration(labelText: 'Grams'),
                controller: TextEditingController(text: item.grams.toStringAsFixed(0)),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  final grams = double.tryParse(value) ?? item.grams;
                  _items[index] = item.copyWith(grams: grams);
                },
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    _items.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            widget.onSave(_items);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
