import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class TaskChartsPage extends StatelessWidget {
  const TaskChartsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();

    return Scaffold(
      appBar: AppBar(title: const Text("Acompanhamento")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.getAllTasks(),
        builder: (context, taskSnapshot) {
          if (taskSnapshot.hasError) {
            return _ErrorMessage(error: taskSnapshot.error);
          }

          if (!taskSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service.getProgressResponses(),
            builder: (context, progressSnapshot) {
              if (progressSnapshot.hasError) {
                return _ErrorMessage(error: progressSnapshot.error);
              }

              if (!progressSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tasks = taskSnapshot.data!.docs
                  .map((doc) => _TaskSchedule.fromDoc(doc))
                  .toList();
              final progressDocs = progressSnapshot.data!.docs;
              final metrics = _buildMetrics(tasks, progressDocs);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SummaryGrid(metrics: metrics),
                  const SizedBox(height: 16),
                  _ChartSection(
                    title: "Ultimos 14 dias",
                    metrics: metrics.daily,
                  ),
                  const SizedBox(height: 16),
                  _DayList(metrics: metrics.daily),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.metrics});

  final _TaskMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      children: [
        _SummaryTile(
          label: "Disponiveis",
          value: metrics.available.toString(),
          color: Colors.blue,
        ),
        _SummaryTile(
          label: "Completadas",
          value: metrics.completed.toString(),
          color: Colors.green,
        ),
        _SummaryTile(
          label: "Pagas",
          value: metrics.paid.toString(),
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, required this.metrics});

  final String title;
  final List<_DailyMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final chartMetrics = metrics.take(14).toList().reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: CustomPaint(
                painter: _TaskBarChartPainter(
                  metrics: chartMetrics,
                  labelColor: Theme.of(context).colorScheme.onSurface,
                ),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _Legend(color: Colors.blue, label: "Disponiveis"),
                _Legend(color: Colors.green, label: "Completadas"),
                _Legend(color: Colors.orange, label: "Pagas"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _DayList extends StatelessWidget {
  const _DayList({required this.metrics});

  final List<_DailyMetric> metrics;

  @override
  Widget build(BuildContext context) {
    if (metrics.isEmpty) {
      return const Center(child: Text("Nenhum dado de acompanhamento"));
    }

    return Card(
      child: Column(
        children: metrics.map((metric) {
          return ListTile(
            title: Text(metric.date),
            subtitle: Text(
              "Disponiveis: ${metric.available} - Completadas: ${metric.completed} - Pagas: ${metric.paid}",
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TaskBarChartPainter extends CustomPainter {
  const _TaskBarChartPainter({required this.metrics, required this.labelColor});

  final List<_DailyMetric> metrics;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (metrics.isEmpty) return;

    final axisPaint = Paint()
      ..color = labelColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    final availablePaint = Paint()..color = Colors.blue;
    final completedPaint = Paint()..color = Colors.green;
    final paidPaint = Paint()..color = Colors.orange;
    final maxValue = math.max(
      1,
      metrics
          .map((metric) => math.max(metric.available, metric.completed))
          .fold<int>(0, math.max),
    );
    final topPadding = 8.0;
    final bottomPadding = 36.0;
    final leftPadding = 4.0;
    final chartHeight = size.height - topPadding - bottomPadding;
    final groupWidth = (size.width - leftPadding) / metrics.length;
    final barWidth = math.min(10.0, groupWidth / 5);
    final baseline = size.height - bottomPadding;

    canvas.drawLine(
      Offset(leftPadding, baseline),
      Offset(size.width, baseline),
      axisPaint,
    );

    for (var index = 0; index < metrics.length; index++) {
      final metric = metrics[index];
      final center = leftPadding + groupWidth * index + groupWidth / 2;
      final values = [metric.available, metric.completed, metric.paid];
      final paints = [availablePaint, completedPaint, paidPaint];

      for (var barIndex = 0; barIndex < values.length; barIndex++) {
        final barHeight = chartHeight * values[barIndex] / maxValue;
        final x = center + (barIndex - 1) * (barWidth + 2);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x - barWidth / 2,
            baseline - barHeight,
            barWidth,
            barHeight,
          ),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, paints[barIndex]);
      }

      final label = metric.date.substring(5);
      final textPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: groupWidth);
      textPainter.paint(
        canvas,
        Offset(center - textPainter.width / 2, baseline + 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TaskBarChartPainter oldDelegate) {
    return metrics != oldDelegate.metrics ||
        labelColor != oldDelegate.labelColor;
  }
}

_TaskMetrics _buildMetrics(
  List<_TaskSchedule> tasks,
  List<QueryDocumentSnapshot<Map<String, dynamic>>> progressDocs,
) {
  final byDate = <String, _DailyMetric>{};
  final today = DateTime.now();

  for (var daysAgo = 0; daysAgo < 14; daysAgo++) {
    final date = today.subtract(Duration(days: daysAgo));
    final key = _dateKey(date);
    byDate[key] = _DailyMetric(
      date: key,
      available: _availableTasksForDate(tasks, date),
    );
  }

  for (final doc in progressDocs) {
    final date = _tryParseDate(doc.id);
    if (date == null) continue;

    final metric = byDate.putIfAbsent(
      doc.id,
      () => _DailyMetric(
        date: doc.id,
        available: _availableTasksForDate(tasks, date),
      ),
    );

    for (final entry in doc.data().entries) {
      final response = _TaskResponse.fromValue(entry.value);

      if (response.completed) metric.completed++;
      if (response.paid) metric.paid++;
    }
  }

  final daily = byDate.values.toList()
    ..sort((a, b) => b.date.compareTo(a.date));

  return _TaskMetrics(
    daily: daily,
    available: daily.fold(0, (total, metric) => total + metric.available),
    completed: daily.fold(0, (total, metric) => total + metric.completed),
    paid: daily.fold(0, (total, metric) => total + metric.paid),
  );
}

int _availableTasksForDate(List<_TaskSchedule> tasks, DateTime date) {
  return tasks.where((task) => task.appearsOn(date.weekday)).length;
}

DateTime? _tryParseDate(String value) {
  final parts = value.split("-");
  if (parts.length != 3) return null;

  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;

  return DateTime(year, month, day);
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, "0");
  final day = date.day.toString().padLeft(2, "0");
  return "${date.year}-$month-$day";
}

class _TaskMetrics {
  const _TaskMetrics({
    required this.daily,
    required this.available,
    required this.completed,
    required this.paid,
  });

  final List<_DailyMetric> daily;
  final int available;
  final int completed;
  final int paid;
}

class _DailyMetric {
  _DailyMetric({required this.date, required this.available})
    : completed = 0,
      paid = 0;

  final String date;
  final int available;
  int completed;
  int paid;
}

class _TaskSchedule {
  const _TaskSchedule({required this.scheduleType, required this.weekdays});

  factory _TaskSchedule.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return _TaskSchedule(
      scheduleType: data['scheduleType']?.toString() ?? "everyday",
      weekdays: _parseWeekdays(data['weekdays']),
    );
  }

  final String scheduleType;
  final Set<int> weekdays;

  bool appearsOn(int weekday) {
    if (scheduleType != "custom") return true;
    if (weekdays.isEmpty) return true;
    return weekdays.contains(weekday);
  }
}

class _TaskResponse {
  const _TaskResponse({required this.completed, required this.paid});

  factory _TaskResponse.fromValue(Object? value) {
    if (value is bool) {
      return _TaskResponse(completed: value, paid: false);
    }

    if (value is Map) {
      return _TaskResponse(
        completed: value['value'] == true,
        paid: value['paid'] == true,
      );
    }

    return const _TaskResponse(completed: false, paid: false);
  }

  final bool completed;
  final bool paid;
}

Set<int> _parseWeekdays(Object? value) {
  if (value is! Iterable) return {};

  return value
      .map((item) {
        if (item is int) return item;
        if (item is num) return item.toInt();
        return int.tryParse(item.toString()) ?? 0;
      })
      .where((weekday) => weekday >= 1 && weekday <= 7)
      .toSet();
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "Erro ao carregar dados: $error",
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
