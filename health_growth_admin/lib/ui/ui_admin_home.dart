import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import 'response_payments_page.dart';
import 'task_charts_page.dart';
import 'task_management_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final service = AdminService();
  int weeklyPoints = 0;
  String? pointsError;

  @override
  void initState() {
    super.initState();
    loadPoints();
  }

  Future<void> loadPoints() async {
    try {
      final pts = await service.calculateWeeklyPoints();
      if (!mounted) return;

      setState(() {
        weeklyPoints = pts;
        pointsError = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        pointsError = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADM"),
        actions: [
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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                  "Total aprovado na semana: R\$$weeklyPoints",
                  style: const TextStyle(fontSize: 20),
                ),
                if (pointsError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      pointsError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
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
                                      if (!mounted) return;
                                      await loadPoints();
                                    },
                                  ),
                                  IconButton(
                                    tooltip: "Aprovar",
                                    icon: const Icon(Icons.check),
                                    onPressed: () async {
                                      await service.approveTask(doc.id, taskId);
                                      if (!mounted) return;
                                      await loadPoints();
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
                await loadPoints();
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
