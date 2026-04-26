import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key});

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage>
    with SingleTickerProviderStateMixin {
  final service = AdminService();
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gerenciar tarefas"),
        actions: [
          IconButton(
            tooltip: "Carregar modelo Health Growth",
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => _seedDefaultPlan(context),
          ),
        ],
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: "Pilares"),
            Tab(text: "Sugestoes"),
          ],
        ),
      ),
      body: TabBarView(
        controller: tabController,
        children: [
          _PillarsTab(service: service),
          _SuggestionsTab(service: service),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: tabController,
        builder: (context, _) {
          if (tabController.index != 0) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: () => _showPillarDialog(context),
            icon: const Icon(Icons.add),
            label: const Text("Pilar"),
          );
        },
      ),
    );
  }

  Future<void> _seedDefaultPlan(BuildContext context) async {
    await service.seedHealthGrowthPlan();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Modelo Health Growth carregado")),
    );
  }

  Future<void> _showPillarDialog(BuildContext context) async {
    final titleController = TextEditingController();
    var selectedColor = Colors.blue.toARGB32();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Novo pilar"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: "Nome"),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: selectedColor,
                    decoration: const InputDecoration(labelText: "Cor"),
                    items: _pillarColors.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.value.toARGB32(),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 8,
                              backgroundColor: entry.value,
                            ),
                            const SizedBox(width: 8),
                            Text(entry.key),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedColor = value);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;

                await service.createPillar(title: title, color: selectedColor);
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text("Criar"),
            ),
          ],
        );
      },
    );

    titleController.dispose();
  }
}

class _PillarsTab extends StatelessWidget {
  const _PillarsTab({required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.getPillars(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorMessage(error: snapshot.error);
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final pillars = snapshot.data!.docs;
        if (pillars.isEmpty) {
          return const Center(child: Text("Nenhum pilar cadastrado"));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: pillars.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final pillar = pillars[index];
            final data = pillar.data();
            final color = _parseColor(data['color']);
            final title = data['title']?.toString() ?? pillar.id;

            return Card(
              child: ExpansionTile(
                leading: CircleAvatar(backgroundColor: color),
                title: Text(title),
                subtitle: Text(pillar.id),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: FilledButton.icon(
                        onPressed: () => _showTaskDialog(context, pillar.id),
                        icon: const Icon(Icons.add),
                        label: const Text("Nova tarefa"),
                      ),
                    ),
                  ),
                  _TaskList(service: service, pillarId: pillar.id),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTaskDialog(BuildContext context, String pillarId) async {
    final titleController = TextEditingController();
    final pointsController = TextEditingController(text: "1");
    var scheduleType = _everydaySchedule;
    var selectedWeekdays = <int>{DateTime.now().weekday};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Nova tarefa"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: "Nome"),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    TextField(
                      controller: pointsController,
                      decoration: const InputDecoration(labelText: "Valor R\$"),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _ScheduleEditor(
                      scheduleType: scheduleType,
                      selectedWeekdays: selectedWeekdays,
                      onScheduleTypeChanged: (value) {
                        setDialogState(() => scheduleType = value);
                      },
                      onWeekdayChanged: (weekday, selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedWeekdays.add(weekday);
                          } else {
                            selectedWeekdays.remove(weekday);
                          }
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final points = int.tryParse(pointsController.text.trim()) ?? 0;
                if (title.isEmpty || points <= 0) return;
                if (scheduleType == _customSchedule &&
                    selectedWeekdays.isEmpty) {
                  return;
                }

                await service.createTask(
                  pillarId: pillarId,
                  title: title,
                  points: points,
                  scheduleType: scheduleType,
                  weekdays: _weekdaysForSave(scheduleType, selectedWeekdays),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text("Criar"),
            ),
          ],
        );
      },
    );

    titleController.dispose();
    pointsController.dispose();
  }
}

class _TaskList extends StatelessWidget {
  const _TaskList({required this.service, required this.pillarId});

  final AdminService service;
  final String pillarId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.getTasks(pillarId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _ErrorMessage(error: snapshot.error),
          );
        }

        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          );
        }

        final tasks = snapshot.data!.docs;
        if (tasks.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Nenhuma tarefa cadastrada"),
            ),
          );
        }

        return Column(
          children: tasks.map((task) {
            final data = task.data();
            final title = data['title']?.toString() ?? task.id;
            final points = _parsePoints(data['points']);
            final scheduleType =
                data['scheduleType']?.toString() ?? _everydaySchedule;
            final weekdays = _parseWeekdays(data['weekdays']);

            return ListTile(
              title: Text(title),
              subtitle: Text(
                "${_scheduleLabel(scheduleType, weekdays)}\n${task.id}",
              ),
              isThreeLine: true,
              trailing: TextButton.icon(
                onPressed: () => _showTaskSettingsDialog(
                  context,
                  task.id,
                  points,
                  scheduleType,
                  weekdays,
                ),
                icon: const Icon(Icons.edit),
                label: Text("R\$$points"),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showTaskSettingsDialog(
    BuildContext context,
    String taskId,
    int currentPoints,
    String currentScheduleType,
    Set<int> currentWeekdays,
  ) async {
    final pointsController = TextEditingController(text: "$currentPoints");
    var scheduleType = currentScheduleType;
    var selectedWeekdays = currentWeekdays.isEmpty
        ? <int>{DateTime.now().weekday}
        : {...currentWeekdays};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Editar tarefa"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: pointsController,
                      decoration: const InputDecoration(labelText: "Valor R\$"),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _ScheduleEditor(
                      scheduleType: scheduleType,
                      selectedWeekdays: selectedWeekdays,
                      onScheduleTypeChanged: (value) {
                        setDialogState(() => scheduleType = value);
                      },
                      onWeekdayChanged: (weekday, selected) {
                        setDialogState(() {
                          if (selected) {
                            selectedWeekdays.add(weekday);
                          } else {
                            selectedWeekdays.remove(weekday);
                          }
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () async {
                final points = int.tryParse(pointsController.text.trim()) ?? 0;
                if (points <= 0) return;
                if (scheduleType == _customSchedule &&
                    selectedWeekdays.isEmpty) {
                  return;
                }

                await service.updateTaskPoints(
                  pillarId: pillarId,
                  taskId: taskId,
                  points: points,
                );
                await service.updateTaskSchedule(
                  pillarId: pillarId,
                  taskId: taskId,
                  scheduleType: scheduleType,
                  weekdays: _weekdaysForSave(scheduleType, selectedWeekdays),
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text("Salvar"),
            ),
          ],
        );
      },
    );

    pointsController.dispose();
  }
}

class _SuggestionsTab extends StatelessWidget {
  const _SuggestionsTab({required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.getPendingSuggestions(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorMessage(error: snapshot.error);
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final suggestions = snapshot.data!.docs;
        if (suggestions.isEmpty) {
          return const Center(child: Text("Nenhuma sugestao pendente"));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: suggestions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            final data = suggestion.data();
            final title = data['title']?.toString() ?? "Sem titulo";
            final pillarId = data['pillarId']?.toString() ?? "";

            return Card(
              child: ListTile(
                title: Text(title),
                subtitle: Text("Pilar: $pillarId"),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: "Aprovar",
                      icon: const Icon(Icons.check),
                      onPressed: pillarId.isEmpty
                          ? null
                          : () => _showApproveDialog(
                              context,
                              suggestion.id,
                              pillarId,
                              title,
                            ),
                    ),
                    IconButton(
                      tooltip: "Rejeitar",
                      icon: const Icon(Icons.close),
                      onPressed: () => service.rejectSuggestion(suggestion.id),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showApproveDialog(
    BuildContext context,
    String suggestionId,
    String pillarId,
    String title,
  ) async {
    final pointsController = TextEditingController(text: "1");

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Aprovar sugestao"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 12),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(labelText: "Valor R\$"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            FilledButton(
              onPressed: () async {
                final points = int.tryParse(pointsController.text.trim()) ?? 0;
                if (points <= 0) return;

                await service.approveSuggestion(
                  suggestionId: suggestionId,
                  pillarId: pillarId,
                  title: title,
                  points: points,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
              },
              child: const Text("Aprovar"),
            ),
          ],
        );
      },
    );

    pointsController.dispose();
  }
}

const _pillarColors = {
  "Azul": Colors.blue,
  "Verde": Colors.green,
  "Laranja": Colors.orange,
  "Roxo": Colors.purple,
  "Vermelho": Colors.red,
};

const _everydaySchedule = "everyday";
const _customSchedule = "custom";
const _weekdayLabels = {
  1: "Seg",
  2: "Ter",
  3: "Qua",
  4: "Qui",
  5: "Sex",
  6: "Sab",
  7: "Dom",
};

class _ScheduleEditor extends StatelessWidget {
  const _ScheduleEditor({
    required this.scheduleType,
    required this.selectedWeekdays,
    required this.onScheduleTypeChanged,
    required this.onWeekdayChanged,
  });

  final String scheduleType;
  final Set<int> selectedWeekdays;
  final ValueChanged<String> onScheduleTypeChanged;
  final void Function(int weekday, bool selected) onWeekdayChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: _everydaySchedule,
              label: Text("Todos os dias"),
            ),
            ButtonSegment(value: _customSchedule, label: Text("Dias")),
          ],
          selected: {scheduleType},
          onSelectionChanged: (values) {
            onScheduleTypeChanged(values.first);
          },
        ),
        if (scheduleType == _customSchedule) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: _weekdayLabels.entries.map((entry) {
              return FilterChip(
                label: Text(entry.value),
                selected: selectedWeekdays.contains(entry.key),
                onSelected: (selected) {
                  onWeekdayChanged(entry.key, selected);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

Color _parseColor(Object? value) {
  if (value is int) return Color(value);
  if (value is num) return Color(value.toInt());
  return Colors.blue;
}

int _parsePoints(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

Set<int> _parseWeekdays(Object? value) {
  if (value is Iterable) {
    return value
        .map((item) {
          if (item is int) return item;
          if (item is num) return item.toInt();
          return int.tryParse(item.toString()) ?? 0;
        })
        .where((weekday) => weekday >= 1 && weekday <= 7)
        .toSet();
  }

  return {};
}

List<int> _weekdaysForSave(String scheduleType, Set<int> weekdays) {
  if (scheduleType == _everydaySchedule) return <int>[];
  final sorted = weekdays.toList()..sort();
  return sorted;
}

String _scheduleLabel(String scheduleType, Set<int> weekdays) {
  if (scheduleType != _customSchedule || weekdays.isEmpty) {
    return "Todos os dias";
  }

  final sorted = weekdays.toList()..sort();
  return sorted.map((weekday) => _weekdayLabels[weekday]).join(", ");
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        "Erro ao carregar dados: $error",
        style: TextStyle(color: Theme.of(context).colorScheme.error),
        textAlign: TextAlign.center,
      ),
    );
  }
}
