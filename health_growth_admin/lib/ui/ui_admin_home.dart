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
        title: const Text("ADM"),
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
                  padding: const EdgeInsets.all(12),
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

              return Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Saldo acumulado: R\$$total',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (note10 > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '⭐ Notas 10: $note10 / 5${note10 >= 5 ? " → Chefão das Notas +R\$150!" : ""}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: note10 >= 5 ? Colors.amber[700] : null,
                          ),
                        ),
                      ],
                      if (pillarPoints.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Divider(height: 1),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: pillarPoints.entries.map((e) {
                            return Text(
                              '${e.key}: R\$${_parsePoints(e.value)}',
                              style: Theme.of(context).textTheme.bodySmall,
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

                if (pendingDocs.isEmpty) {
                  return const Center(
                    child: Text("Nenhuma resposta pendente de conferencia"),
                  );
                }

                return ListView(
                  children: pendingDocs.map<Widget>((doc) {
                    final data = doc.data();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.id,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...data.entries.map((entry) {
                          final taskId = entry.key;
                          final task = entry.value;

                          if (task is Map &&
                              task['value'] == true &&
                              task['status'] == 'pending') {
                            final title = task['title']?.toString() ?? taskId;
                            final points = _parsePoints(task['points']);

                            return ListTile(
                              title: Text(title),
                              subtitle: Text(
                                points == 0
                                    ? "Pendente"
                                    : "Pendente - R\$$points",
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: "Rejeitar",
                                    icon: const Icon(Icons.close),
                                    onPressed: () async {
                                      await service.rejectTask(doc.id, taskId);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: "Aprovar",
                                    icon: const Icon(Icons.check),
                                    onPressed: () async {
                                      await service.approveTask(doc.id, taskId);
                                    },
                                  ),
                                ],
                              ),
                            );
                          }

                          return const SizedBox.shrink();
                        }),
                        const Divider(),
                      ],
                    );
                  }).toList(),
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
