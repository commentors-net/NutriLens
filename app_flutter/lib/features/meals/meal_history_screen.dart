import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import 'package:foodvision/core/api/food_vision_client.dart';
import 'package:foodvision/core/models/meal_history.dart';

class MealHistoryScreen extends ConsumerStatefulWidget {
  const MealHistoryScreen({super.key});

  @override
  ConsumerState<MealHistoryScreen> createState() => _MealHistoryScreenState();
}

class _MealHistoryScreenState extends ConsumerState<MealHistoryScreen> {
  late DateTime _startDate;
  late DateTime _endDate;
  late Future<MealHistoryResponse> _historyFuture;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _endDate = DateTime(today.year, today.month, today.day);
    _startDate = _endDate.subtract(const Duration(days: 6));
    _historyFuture = _fetch();
  }

  Future<MealHistoryResponse> _fetch() {
    final client = ref.read(foodVisionClientProvider);
    return client.getMealsByRange(
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
    if (picked == null) return;
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

  Future<void> _handleExport(String format) async {
    setState(() => _isExporting = true);
    try {
      final client = ref.read(foodVisionClientProvider);
      final bytes = await client.exportMeals(
        start: _toDate(_startDate),
        end: _toDate(_endDate),
        format: format,
      );

      final dir = await getApplicationDocumentsDirectory();
      final fileName =
          'nutrilens_meals_${_toDate(_startDate)}_to_${_toDate(_endDate)}.$format';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        format == 'csv' ? Icons.table_chart : Icons.picture_as_pdf,
                        color: format == 'csv' ? Colors.green : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Export Complete (${format.toUpperCase()})',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('File saved to:\n${file.path}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('Size: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 16),
                  if (format == 'csv') ...[
                    const Text('Preview:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        String.fromCharCodes(bytes)
                            .split('\n')
                            .take(4)
                            .join('\n'),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal History & Trends'),
        actions: [
          if (_isExporting)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.download),
              tooltip: 'Export Meals',
              onSelected: _handleExport,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    leading: Icon(Icons.table_chart, color: Colors.green),
                    title: Text('Export CSV'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                    title: Text('Export PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
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
                    _RangeChip(label: 'Today', onTap: () => _setRange(1)),
                    _RangeChip(label: '7 days', onTap: () => _setRange(7)),
                    _RangeChip(label: '30 days', onTap: () => _setRange(30)),
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

                final daysCount =
                    _endDate.difference(_startDate).inDays + 1;

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    _HistoryAnalyticsCard(
                      history: history,
                      daysCount: daysCount > 0 ? daysCount : 1,
                      grouped: grouped,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Logged Meals',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
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

class _HistoryAnalyticsCard extends StatelessWidget {
  final MealHistoryResponse history;
  final int daysCount;
  final Map<String, List<MealHistoryItem>> grouped;

  const _HistoryAnalyticsCard({
    required this.history,
    required this.daysCount,
    required this.grouped,
  });

  @override
  Widget build(BuildContext context) {
    final avgKcal = (history.totalKcal / daysCount).round();

    // Macro calories: protein (4 kcal/g), carbs (4 kcal/g), fat (9 kcal/g)
    final proteinCal = history.totalProteinG * 4;
    final carbsCal = history.totalCarbsG * 4;
    final fatCal = history.totalFatG * 9;
    final totalMacroCal = proteinCal + carbsCal + fatCal;

    final proteinPct = totalMacroCal > 0 ? (proteinCal / totalMacroCal) : 0.0;
    final carbsPct = totalMacroCal > 0 ? (carbsCal / totalMacroCal) : 0.0;
    final fatPct = totalMacroCal > 0 ? (fatCal / totalMacroCal) : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.insights, color: Colors.deepOrange),
                SizedBox(width: 8),
                Text(
                  'Nutrition Trends & Distribution',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Top Stat Tiles
            Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'Total Kcal',
                    value: '${history.totalKcal}',
                    color: Colors.deepOrange,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'Daily Avg',
                    value: '$avgKcal kcal',
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatBox(
                    label: 'Meals',
                    value: '${history.mealCount}',
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Macro Distribution Bar
            const Text(
              'Calorie Distribution by Macro',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    if (proteinPct > 0)
                      Expanded(
                        flex: (proteinPct * 100).round().clamp(1, 100),
                        child: Container(color: Colors.blue),
                      ),
                    if (carbsPct > 0)
                      Expanded(
                        flex: (carbsPct * 100).round().clamp(1, 100),
                        child: Container(color: Colors.amber.shade700),
                      ),
                    if (fatPct > 0)
                      Expanded(
                        flex: (fatPct * 100).round().clamp(1, 100),
                        child: Container(color: Colors.purple),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Macro Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _MacroLegend(
                  label: 'Protein',
                  grams: history.totalProteinG,
                  percentage: (proteinPct * 100).round(),
                  color: Colors.blue,
                ),
                _MacroLegend(
                  label: 'Carbs',
                  grams: history.totalCarbsG,
                  percentage: (carbsPct * 100).round(),
                  color: Colors.amber.shade700,
                ),
                _MacroLegend(
                  label: 'Fat',
                  grams: history.totalFatG,
                  percentage: (fatPct * 100).round(),
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Daily Calorie Intake Bars
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'Daily Intake Breakdown',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...grouped.entries.take(7).map((entry) {
              final dayTotal = entry.value
                  .fold<int>(0, (sum, meal) => sum + meal.totalKcal);
              const maxDay = 2500;
              final fraction = (dayTotal / maxDay).clamp(0.0, 1.0);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        entry.key.length >= 5 ? entry.key.substring(5) : entry.key,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            dayTotal > 2000
                                ? Colors.deepOrange
                                : Colors.teal.shade400,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 65,
                      child: Text(
                        '$dayTotal kcal',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _MacroLegend extends StatelessWidget {
  final String label;
  final double grams;
  final int percentage;
  final Color color;

  const _MacroLegend({
    required this.label,
    required this.grams,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ${grams.toStringAsFixed(0)}g ($percentage%)',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
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
              return _MealTile(meal: meal, time: time);
            }),
          ],
        ),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  final MealHistoryItem meal;
  final String time;

  const _MealTile({required this.meal, required this.time});

  @override
  Widget build(BuildContext context) {
    final subtitle = meal.items.isEmpty
        ? '${meal.itemCount} item${meal.itemCount == 1 ? '' : 's'}'
        : meal.items
            .map((it) => '${it.label} (${it.grams.toStringAsFixed(0)}g)')
            .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('$time  •  ${meal.totalKcal} kcal'),
          subtitle: Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: meal.notes.trim().isNotEmpty
              ? Tooltip(
                  message: meal.notes,
                  child: const Icon(Icons.notes, size: 18),
                )
              : null,
        ),
        if (meal.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: meal.imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final url = meal.imageUrls[idx];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    url,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}
