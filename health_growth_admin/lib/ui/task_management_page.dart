import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/notification_admin_service.dart';

class TaskManagementPage extends StatefulWidget {
  const TaskManagementPage({super.key});

  @override
  State<TaskManagementPage> createState() => _TaskManagementPageState();
}

class _TaskManagementPageState extends State<TaskManagementPage>
    with SingleTickerProviderStateMixin {
  final service = AdminService();
  final notificationService = NotificationAdminService();
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
            tooltip: "Notificações",
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotificationDialog(context),
          ),
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

  Future<void> _showNotificationDialog(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _NotificationSheet(notificationService: notificationService),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(Icons.category_outlined, color: color, size: 18),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(pillar.id, style: const TextStyle(fontSize: 12)),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'R\$$points',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _scheduleLabel(scheduleType, weekdays),
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.tune, size: 20),
                onPressed: () => _showTaskSettingsDialog(
                  context,
                  task.id,
                  points,
                  scheduleType,
                  weekdays,
                ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: Colors.blue.shade600,
                  ),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text("Pilar: $pillarId"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.outlined(
                      tooltip: "Rejeitar",
                      icon: const Icon(Icons.close, size: 20),
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      onPressed: () => service.rejectSuggestion(suggestion.id),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      tooltip: "Aprovar",
                      icon: const Icon(Icons.check, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: pillarId.isEmpty
                          ? null
                          : () => _showApproveDialog(
                              context,
                              suggestion.id,
                              pillarId,
                              title,
                            ),
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

// ========== NOTIFICATION SHEET ==========

class _NotificationSheet extends StatefulWidget {
  const _NotificationSheet({required this.notificationService});

  final NotificationAdminService notificationService;

  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet>
    with SingleTickerProviderStateMixin {
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
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            TabBar(
              controller: tabController,
              tabs: const [
                Tab(text: "Enviar"),
                Tab(text: "Programar"),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _DirectNotificationTab(
                    service: widget.notificationService,
                    scrollController: scrollController,
                  ),
                  _ScheduledNotificationTab(
                    service: widget.notificationService,
                    scrollController: scrollController,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DirectNotificationTab extends StatefulWidget {
  const _DirectNotificationTab({
    required this.service,
    required this.scrollController,
  });

  final NotificationAdminService service;
  final ScrollController scrollController;

  @override
  State<_DirectNotificationTab> createState() => _DirectNotificationTabState();
}

class _DirectNotificationTabState extends State<_DirectNotificationTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;

    setState(() => _sending = true);

    try {
      await widget.service.sendDirectNotification(title: title, body: body);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Notificação enviada!")));
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: "Título",
            hintText: "Ex: Nova tarefa disponível!",
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bodyController,
          decoration: const InputDecoration(
            labelText: "Mensagem",
            hintText: "Ex: Você tem uma nova tarefa para fazer hoje.",
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send),
          label: Text(_sending ? "Enviando..." : "Enviar Notificação"),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          "Ações rápidas:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.check_circle, size: 18),
              label: const Text("Tarefa Aprovada"),
              onPressed: () {
                _titleController.text = "✅ Tarefa Aprovada!";
                _bodyController.text = "Uma de suas tarefas foi aprovada!";
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.cancel, size: 18),
              label: const Text("Tarefa Rejeitada"),
              onPressed: () {
                _titleController.text = "❌ Tarefa Não Aprovada";
                _bodyController.text = "Revise e tente novamente.";
              },
            ),
            ActionChip(
              avatar: const Icon(Icons.emoji_events, size: 18),
              label: const Text("Parabéns"),
              onPressed: () {
                _titleController.text = "🎉 Parabéns!";
                _bodyController.text = "Você está indo muito bem!";
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _ScheduledNotificationTab extends StatefulWidget {
  const _ScheduledNotificationTab({
    required this.service,
    required this.scrollController,
  });

  final NotificationAdminService service;
  final ScrollController scrollController;

  @override
  State<_ScheduledNotificationTab> createState() =>
      _ScheduledNotificationTabState();
}

class _ScheduledNotificationTabState extends State<_ScheduledNotificationTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);
  final Set<int> _selectedWeekdays = {1, 2, 3, 4, 5}; // Seg a Sex
  bool _sending = false;

  static const _weekdays = {
    1: "Seg",
    2: "Ter",
    3: "Qua",
    4: "Qui",
    5: "Sex",
    6: "Sáb",
    7: "Dom",
  };

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _schedule() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) return;
    if (_selectedWeekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione pelo menos um dia")),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await widget.service.scheduleNotification(
        title: title,
        body: body,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
        weekdays: _selectedWeekdays.toList()..sort(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Notificação agendada para $_selectedTime")),
        );
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro: $e")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: "Título",
            hintText: "Ex: Hora da tarefa!",
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bodyController,
          decoration: const InputDecoration(
            labelText: "Mensagem",
            hintText: "Ex: Você tem tarefas para fazer hoje.",
          ),
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.access_time),
          title: const Text("Horário"),
          subtitle: Text(_selectedTime.format(context)),
          onTap: _selectTime,
        ),
        const SizedBox(height: 16),
        const Text(
          "Repetir nos dias:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _weekdays.entries.map((entry) {
            final selected = _selectedWeekdays.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _selectedWeekdays.add(entry.key);
                  } else {
                    _selectedWeekdays.remove(entry.key);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _sending ? null : _schedule,
          icon: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.schedule),
          label: Text(_sending ? "Agendando..." : "Agendar Notificação"),
        ),
      ],
    );
  }
}
