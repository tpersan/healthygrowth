import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import 'penalties_page.dart';
import 'response_payments_page.dart';
import 'task_charts_page.dart';
import 'task_management_page.dart';
import 'weekly_goal_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final service = AdminService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Health Growth"),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: "Penalidades",
            icon: const Icon(Icons.warning_amber_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PenaltiesPage()),
              );
            },
          ),
          IconButton(
            tooltip: "Lancamento manual",
            icon: const Icon(Icons.add_card),
            onPressed: () => _showManualEntryDialog(context),
          ),
          IconButton(
            tooltip: "Acompanhamento",
            icon: const Icon(Icons.bar_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TaskChartsPage()),
              );
            },
          ),
          IconButton(
            tooltip: "Controle de respostas",
            icon: const Icon(Icons.payments_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ResponsePaymentsPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: "Gerenciar tarefas",
            icon: const Icon(Icons.tune),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TaskManagementPage(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: "Meta semanal",
            icon: const Icon(Icons.flag),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const WeeklyGoalPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Painel de stats do Heitor (Stream)
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: service.getUserStatsStream(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    'Erro ao carregar stats: ${snap.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              // Proteção contra dados nulos
              final data = snap.hasData && snap.data!.exists
                  ? snap.data!.data() ?? <String, dynamic>{}
                  : <String, dynamic>{};
              final total = _parsePoints(data['totalPoints']);
              final note10 = _parsePoints(data['note10count']);
              final pillarPointsRaw = data['pillarPoints'];
              final pillarPoints = pillarPointsRaw is Map<String, dynamic>
                  ? pillarPointsRaw
                  : <String, dynamic>{};
              final cs = Theme.of(context).colorScheme;

              return Card(
                elevation: 0,
                color: cs.primaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.savings_rounded,
                            color: cs.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Saldo do Heitor',
                            style: TextStyle(
                              color: cs.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'R\$ $total',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                      ),
                      if (note10 > 0) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: note10 >= 5
                                ? Colors.amber.shade300
                                : cs.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '⭐ Notas 10: $note10 / 5${note10 >= 5 ? " → Chefão +R\$150!" : ""}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: note10 >= 5
                                  ? Colors.amber.shade900
                                  : cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                      if (pillarPoints.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: pillarPoints.entries.map((e) {
                            final val = _parsePoints(e.value);
                            return Chip(
                              label: Text('${e.key}: R\$$val'),
                              labelStyle: TextStyle(
                                fontSize: 11,
                                color: cs.onSecondaryContainer,
                                fontWeight: FontWeight.w500,
                              ),
                              backgroundColor: cs.secondaryContainer,
                              side: BorderSide.none,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          // Lista de tarefas pendentes (Stream)
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.getPendingProgress(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _ErrorMessage(error: snapshot.error);
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.reversed.toList();
                final pendingDocs = docs.where((doc) {
                  return doc.data().values.any((task) {
                    return task is Map &&
                        task['value'] == true &&
                        task['status'] == 'pending';
                  });
                }).toList();

                final cs = Theme.of(context).colorScheme;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            'Pendências',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                  color: cs.onSurfaceVariant,
                                ),
                          ),
                          if (pendingDocs.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Badge.count(count: pendingDocs.length),
                          ],
                        ],
                      ),
                    ),
                    if (pendingDocs.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.task_alt,
                                size: 56,
                                color: cs.primary.withValues(alpha: 0.35),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tudo em dia!',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Nenhuma resposta pendente de conferência',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          children: pendingDocs.map<Widget>((doc) {
                            final data = doc.data();
                            final pendingTasks = data.entries.where((entry) {
                              final task = entry.value;
                              return task is Map &&
                                  task['value'] == true &&
                                  task['status'] == 'pending';
                            }).toList();

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    color: cs.surfaceContainerHighest,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 14,
                                          color: cs.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          doc.id,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: cs.onSurfaceVariant,
                                          ),
                                        ),
                                        const Spacer(),
                                        Badge.count(
                                          count: pendingTasks.length,
                                          backgroundColor:
                                              Colors.orange.shade600,
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...pendingTasks.map((entry) {
                                    final taskId = entry.key;
                                    final task = entry.value as Map;
                                    final title =
                                        task['title']?.toString() ?? taskId;
                                    final points = _parsePoints(task['points']);

                                    return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 2,
                                          ),
                                      title: Text(
                                        title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: points == 0
                                          ? Text(
                                              'Pendente',
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontSize: 12,
                                              ),
                                            )
                                          : Text(
                                              'R\$ $points',
                                              style: TextStyle(
                                                color: cs.primary,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton.outlined(
                                            tooltip: 'Rejeitar',
                                            icon: const Icon(
                                              Icons.close,
                                              size: 20,
                                            ),
                                            style: IconButton.styleFrom(
                                              foregroundColor: cs.error,
                                              side: BorderSide(color: cs.error),
                                            ),
                                            onPressed: () async {
                                              await service.rejectTask(
                                                doc.id,
                                                taskId,
                                              );
                                            },
                                          ),
                                          const SizedBox(width: 6),
                                          IconButton.filled(
                                            tooltip: 'Aprovar',
                                            icon: const Icon(
                                              Icons.check,
                                              size: 20,
                                            ),
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  Colors.green.shade600,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () async {
                                              await service.approveTask(
                                                doc.id,
                                                taskId,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showManualEntryDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final pointsController = TextEditingController();
    final today = _dateKey(DateTime.now());
    final dateController = TextEditingController(text: today);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text("Lancamento manual"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: "Descricao",
                  hintText: "Ex: Semana completa, penalidade tela",
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(
                  labelText: "Valor R\$",
                  helperText: "Use negativo para penalidade",
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: "Data"),
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
                final title = titleController.text.trim();
                final points = int.tryParse(pointsController.text.trim());
                final date = dateController.text.trim();
                if (title.isEmpty || points == null || date.isEmpty) return;

                await service.createManualEntry(
                  date: date,
                  title: title,
                  points: points,
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

    titleController.dispose();
    pointsController.dispose();
    dateController.dispose();
  }
}

int _parsePoints(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

String _dateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, "0");
  final day = date.day.toString().padLeft(2, "0");
  return "${date.year}-$month-$day";
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
