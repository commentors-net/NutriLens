import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/food_vision_client.dart';
import '../../core/models/meal_history.dart';

class MealHistoryScreen extends StatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  State<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends State<MealHistoryScreen> {
  final FoodVisionClient _client = FoodVisionClient();
  late DateTime _startDate;
  late DateTime _endDate;
  late Future<MealHistoryResponse> _historyFuture;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = DateTime(today.year, today.month, today.day);
    _startDate = _endDate.subtract(const Duration(days: 6));
    _historyFuture = _fetch();
  }

  Future<MealHistoryResponse> _fetch() {
    return _client.getMealsByRange(
      start: _toDate(_startDate),
      end: _toDate(_endDate),
    );
  }

  String _toDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  void _setRange(int days) {
    final today = DateTime.now();
    setState(() {
      _endDate = DateTime(today.year, today.month, today.day);
      _startDate = _endDate.subtract(Duration(days: days - 1));
      _historyFuture = _fetch();
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null) {
      return;
    }

    setState(() {
      if (isStart) {
        _startDate = DateTime(picked.year, picked.month, picked.day);
        if (_startDate.isAfter(_endDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = DateTime(picked.year, picked.month, picked.day);
        if (_endDate.isBefore(_startDate)) {
          _startDate = _endDate;
        }
      }
      _historyFuture = _fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RangeChip(
                      label: 'Today',
                      onTap: () => _setRange(1),
                    ),
                    _RangeChip(
                      label: '7 days',
                      onTap: () => _setRange(7),
                    ),
                    _RangeChip(
                      label: '30 days',
                      onTap: () => _setRange(30),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(true),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text('Start: ${_toDate(_startDate)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _pickDate(false),
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text('End: ${_toDate(_endDate)}'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: FutureBuilder<MealHistoryResponse>(
              future: _historyFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.grey, size: 36),
                          const SizedBox(height: 8),
                          Text('Could not load meal history: ${snapshot.error}'),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _historyFuture = _fetch();
                              });
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final history = snapshot.data;
                if (history == null || history.meals.isEmpty) {
                  return const Center(
                    child: Text('No meals found for this date range.'),
                  );
                }

                final grouped = <String, List<MealHistoryItem>>{};
                for (final meal in history.meals) {
                  final key = _toDate(meal.timestamp.toLocal());
                  grouped.putIfAbsent(key, () => []).add(meal);
                }
                final sortedDates = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Meals: ${history.mealCount}'),
                            Text('Calories: ${history.totalKcal} kcal'),
                            Text(
                              'Protein ${history.totalProteinG.toStringAsFixed(1)}g • '
                              'Carbs ${history.totalCarbsG.toStringAsFixed(1)}g • '
                              'Fat ${history.totalFatG.toStringAsFixed(1)}g',
                            ),
                          ],
                        ),
                      ),
                    ),
                    ...sortedDates.map((dateKey) {
                      final meals = grouped[dateKey]!
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                      return _DaySection(dateKey: dateKey, meals: meals);
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RangeChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.date_range, size: 16),
      label: Text(label),
      onPressed: onTap,
    );
  }
}

class _DaySection extends StatelessWidget {
  final String dateKey;
  final List<MealHistoryItem> meals;

  const _DaySection({required this.dateKey, required this.meals});

  @override
  Widget build(BuildContext context) {
    final dayTotal = meals.fold<int>(0, (sum, meal) => sum + meal.totalKcal);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$dateKey • ${meals.length} meal${meals.length == 1 ? '' : 's'} • $dayTotal kcal',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...meals.map((meal) {
              final time = DateFormat('HH:mm').format(meal.timestamp.toLocal());
              return ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('$time  •  ${meal.totalKcal} kcal'),
                subtitle: Text(
                  meal.items.isEmpty
                      ? '${meal.itemCount} item${meal.itemCount == 1 ? '' : 's'}'
                      : meal.items
                          .map((it) => '${it.label} (${it.grams.toStringAsFixed(0)}g)')
                          .join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: meal.notes.trim().isNotEmpty
                    ? Tooltip(
                        message: meal.notes,
                        child: const Icon(Icons.notes, size: 18),
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}
