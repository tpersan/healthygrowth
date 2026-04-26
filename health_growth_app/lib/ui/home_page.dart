import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/firestore_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final service = FirestoreService();
  late _TodayInfo today;
  Timer? _todayTimer;

  @override
  void initState() {
    super.initState();
    today = getToday();
    _todayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final currentToday = getToday();
      if (currentToday.key == today.key) return;
      setState(() => today = currentToday);
    });
  }

  @override
  void dispose() {
    _todayTimer?.cancel();
    super.dispose();
  }

  _TodayInfo getToday() {
    final now = DateTime.now();
    return _TodayInfo(
      key: DateFormat('yyyy-MM-dd').format(now),
      weekday: now.weekday,
      label:
          "${_weekdayNames[now.weekday]}, ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}",
    );
  }

  void showSuggestionDialog() {
    String title = "";
    String? pillarId;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Sugerir nova tarefa"),
          content: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: service.getPillars(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  width: 240,
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final pillars = snapshot.data!.docs;
              if (pillars.isEmpty) {
                return const Text("Nenhum pilar cadastrado ainda");
              }

              pillarId ??= pillars.first.id;

              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        onChanged: (v) => title = v,
                        decoration: const InputDecoration(
                          labelText: "Nome da tarefa",
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: pillarId,
                        decoration: const InputDecoration(labelText: "Pilar"),
                        items: pillars.map((pillar) {
                          final data = pillar.data();
                          final title = data['title']?.toString() ?? pillar.id;

                          return DropdownMenuItem(
                            value: pillar.id,
                            child: Text(title),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() => pillarId = value);
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final selectedPillar = pillarId;
                if (title.trim().isEmpty || selectedPillar == null) return;

                await service.suggestTask(title.trim(), selectedPillar);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: const Text("Enviar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Health Growth - ${today.label}")),
      floatingActionButton: FloatingActionButton(
        onPressed: showSuggestionDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.getPillars(),
        builder: (context, pillarSnap) {
          if (pillarSnap.hasError) {
            return _ErrorMessage(error: pillarSnap.error);
          }

          if (!pillarSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            key: ValueKey(today.key),
            stream: service.getTodayProgress(),
            builder: (context, progressSnap) {
              if (progressSnap.hasError) {
                return _ErrorMessage(error: progressSnap.error);
              }

              if (!progressSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final progress = progressSnap.data!.exists
                  ? progressSnap.data!.data() ?? <String, dynamic>{}
                  : <String, dynamic>{};
              final pillars = pillarSnap.data!.docs;

              return ListView(
                children: [
                  _TodayHeader(today: today),
                  ...pillars.map<Widget>((pillar) {
                    return buildPillar(pillar, progress, today);
                  }),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget buildPillar(
    QueryDocumentSnapshot<Map<String, dynamic>> pillar,
    Map<String, dynamic> progress,
    _TodayInfo today,
  ) {
    final pillarData = pillar.data();
    final color = Color(pillarData['color'] as int);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              pillarData['title'] as String,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.getTasks(pillar.id),
              builder: (context, taskSnap) {
                if (taskSnap.hasError) {
                  return _ErrorMessage(error: taskSnap.error);
                }

                if (!taskSnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  );
                }

                final tasks = taskSnap.data!.docs.where((task) {
                  return _taskAppearsToday(task.data(), today.weekday);
                }).toList();

                if (tasks.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text("Nenhuma tarefa para hoje"),
                  );
                }

                return Column(
                  children: tasks.map<Widget>((task) {
                    final taskData = task.data();
                    final checked = _progressChecked(progress[task.id]);

                    return CheckboxListTile(
                      value: checked,
                      title: Text(taskData['title'] as String),
                      subtitle: Text("+R\$${taskData['points']}"),
                      onChanged: (value) {
                        _saveTaskProgress(
                          task.id,
                          taskData['title']?.toString() ?? task.id,
                          _parsePoints(taskData['points']),
                          value ?? false,
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  bool _taskAppearsToday(Map<String, dynamic> taskData, int weekday) {
    final scheduleType = taskData['scheduleType']?.toString() ?? 'everyday';
    if (scheduleType != 'custom') return true;

    final weekdays = taskData['weekdays'];
    if (weekdays is! Iterable) return true;

    return weekdays.any((item) {
      if (item is int) return item == weekday;
      if (item is num) return item.toInt() == weekday;
      return int.tryParse(item.toString()) == weekday;
    });
  }

  bool _progressChecked(Object? value) {
    if (value is bool) return value;
    if (value is Map) return value['value'] == true;
    return false;
  }

  void _saveTaskProgress(String taskId, String title, int points, bool value) {
    final currentToday = getToday();
    if (currentToday.key != today.key) {
      setState(() => today = currentToday);
      return;
    }

    service.saveTodayProgress(
      taskId: taskId,
      title: title,
      points: points,
      value: value,
    );
  }
}

int _parsePoints(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

class _TodayInfo {
  const _TodayInfo({
    required this.key,
    required this.weekday,
    required this.label,
  });

  final String key;
  final int weekday;
  final String label;
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.today});

  final _TodayInfo today;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(today.label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            "Tarefas e respostas somente de hoje",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
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

const _weekdayNames = {
  1: "Segunda-feira",
  2: "Terca-feira",
  3: "Quarta-feira",
  4: "Quinta-feira",
  5: "Sexta-feira",
  6: "Sabado",
  7: "Domingo",
};
