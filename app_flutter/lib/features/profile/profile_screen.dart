import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodvision/core/models/nutrilens_profile.dart';
import 'package:foodvision/features/profile/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  final TextEditingController _customRestrictionController = TextEditingController();

  List<String> _restrictions = [];
  bool _notificationsEnabled = false;
  String _breakfastTime = '08:00';
  String _lunchTime = '13:00';
  String _dinnerTime = '19:00';
  bool _initialized = false;
  bool _isSaving = false;

  final List<String> _presetRestrictions = [
    'Vegetarian',
    'Vegan',
    'Halal',
    'Kosher',
    'Gluten-Free',
    'Dairy-Free',
    'Keto',
    'Low-Carb',
  ];

  @override
  void initState() {
    super.initState();
    _caloriesController = TextEditingController();
    _proteinController = TextEditingController();
    _carbsController = TextEditingController();
    _fatController = TextEditingController();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _customRestrictionController.dispose();
    super.dispose();
  }

  void _populate(NutriLensProfile p) {
    if (_initialized) return;
    _caloriesController.text = p.dailyCalorieGoal.toString();
    _proteinController.text = p.proteinGoalG.toStringAsFixed(0);
    _carbsController.text = p.carbsGoalG.toStringAsFixed(0);
    _fatController.text = p.fatGoalG.toStringAsFixed(0);
    _restrictions = List.from(p.dietaryRestrictions);
    _notificationsEnabled = p.notificationsEnabled;
    _breakfastTime = p.breakfastReminderTime;
    _lunchTime = p.lunchReminderTime;
    _dinnerTime = p.dinnerReminderTime;
    _initialized = true;
  }

  Future<void> _selectTime(String current, ValueChanged<String> onSelected) async {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      onSelected(formatted);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updated = NutriLensProfile(
        dailyCalorieGoal: int.tryParse(_caloriesController.text) ?? 2000,
        proteinGoalG: double.tryParse(_proteinController.text) ?? 100.0,
        carbsGoalG: double.tryParse(_carbsController.text) ?? 250.0,
        fatGoalG: double.tryParse(_fatController.text) ?? 65.0,
        dietaryRestrictions: _restrictions,
        notificationsEnabled: _notificationsEnabled,
        breakfastReminderTime: _breakfastTime,
        lunchReminderTime: _lunchTime,
        dinnerReminderTime: _dinnerTime,
      );

      await ref.read(profileProvider.notifier).updateProfile(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile and goals updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutritional Goals & Profile'),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading profile: $e'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.read(profileProvider.notifier).loadProfile(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (profile) {
          _populate(profile);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Daily Goals Card ──────────────────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.track_changes, color: Colors.deepOrange),
                            SizedBox(width: 8),
                            Text(
                              'Daily Nutrition Targets',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _caloriesController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Daily Calories (kcal)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.local_fire_department, color: Colors.deepOrange),
                          ),
                          validator: (v) {
                            final val = int.tryParse(v ?? '');
                            if (val == null || val < 500 || val > 10000) {
                              return 'Enter a realistic calorie target (500 - 10,000)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _proteinController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Protein (g)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.fitness_center, color: Colors.blue),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _carbsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Carbs (g)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.grain, color: Colors.amber),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _fatController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Fat (g)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.opacity, color: Colors.purple),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Dietary Restrictions Card ────────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.no_meals, color: Colors.teal),
                            SizedBox(width: 8),
                            Text(
                              'Dietary Preferences & Allergens',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_restrictions.isNotEmpty)
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _restrictions.map((r) {
                              return Chip(
                                label: Text(r),
                                onDeleted: () {
                                  setState(() => _restrictions.remove(r));
                                },
                                backgroundColor: Colors.teal.shade50,
                              );
                            }).toList(),
                          )
                        else
                          const Text('No dietary restrictions selected',
                              style: TextStyle(color: Colors.grey, fontSize: 13)),
                        const SizedBox(height: 12),
                        const Text('Quick Add Presets:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _presetRestrictions.where((p) => !_restrictions.contains(p)).map((p) {
                            return ActionChip(
                              label: Text('+ $p', style: const TextStyle(fontSize: 12)),
                              onPressed: () {
                                setState(() => _restrictions.add(p));
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _customRestrictionController,
                                decoration: const InputDecoration(
                                  hintText: 'Add custom (e.g. Peanut Allergy)',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                final text = _customRestrictionController.text.trim();
                                if (text.isNotEmpty && !_restrictions.contains(text)) {
                                  setState(() {
                                    _restrictions.add(text);
                                    _customRestrictionController.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Meal Reminders Card ──────────────────────────────────────
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.alarm, color: Colors.indigo),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Meal Reminders',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                            Switch(
                              value: _notificationsEnabled,
                              onChanged: (v) => setState(() => _notificationsEnabled = v),
                            ),
                          ],
                        ),
                        if (_notificationsEnabled) ...[
                          const Divider(),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Breakfast Reminder'),
                            trailing: OutlinedButton(
                              onPressed: () => _selectTime(_breakfastTime, (t) => setState(() => _breakfastTime = t)),
                              child: Text(_breakfastTime),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Lunch Reminder'),
                            trailing: OutlinedButton(
                              onPressed: () => _selectTime(_lunchTime, (t) => setState(() => _lunchTime = t)),
                              child: Text(_lunchTime),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Dinner Reminder'),
                            trailing: OutlinedButton(
                              onPressed: () => _selectTime(_dinnerTime, (t) => setState(() => _dinnerTime = t)),
                              child: Text(_dinnerTime),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Save Button ──────────────────────────────────────────────
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving Changes...' : 'Save Goals & Profile'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
