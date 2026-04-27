import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';

class ResponsePaymentsPage extends StatelessWidget {
  const ResponsePaymentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = AdminService();

    return Scaffold(
      appBar: AppBar(title: const Text("Controle de respostas")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.getProgressResponses(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorMessage(error: snapshot.error);
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final days = snapshot.data!.docs.reversed.toList();
          final items = <_ResponseItem>[];

          for (final day in days) {
            final data = day.data();
            for (final entry in data.entries) {
              final response = _parseResponse(entry.value);
              if (response == null) continue;

              items.add(
                _ResponseItem(
                  date: day.id,
                  taskId: entry.key,
                  status: response.status,
                  paid: response.paid,
                  title: response.title,
                  points: response.points,
                ),
              );
            }
          }

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 56,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text("Nenhuma resposta marcada"),
                ],
              ),
            );
          }

          final totalApproved = items
              .where((i) => i.status == "approved")
              .length;
          final totalPaid = items.where((i) => i.paid).length;
          final totalPoints = items.fold<int>(
            0,
            (sum, i) => sum + (i.points ?? 0),
          );
          final cs = Theme.of(context).colorScheme;

          return Column(
            children: [
              Card(
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                elevation: 0,
                color: cs.secondaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatBadge(
                        label: 'Total',
                        value: '${items.length}',
                        color: cs.primary,
                      ),
                      _StatBadge(
                        label: 'Aprovadas',
                        value: '$totalApproved',
                        color: Colors.green,
                      ),
                      _StatBadge(
                        label: 'Pagas',
                        value: '$totalPaid',
                        color: Colors.teal,
                      ),
                      _StatBadge(
                        label: 'Saldo',
                        value: 'R\$$totalPoints',
                        color: cs.primary,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return FutureBuilder<AdminTaskInfo>(
                      future: service.getTaskInfo(item.taskId),
                      builder: (context, taskSnapshot) {
                        final task = taskSnapshot.data;
                        final title = item.title ?? task?.title ?? item.taskId;
                        final points = item.points ?? task?.points;
                        final status = _statusLabel(item.status);
                        final statusColor = _statusColor(item.status);
                        final pointsText = points == null
                            ? ''
                            : ' • R\$$points';

                        return CheckboxListTile(
                          value: item.paid,
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${item.date}$pointsText',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          secondary: Icon(
                            item.paid
                                ? Icons.check_circle
                                : Icons.payments_outlined,
                            color: item.paid ? Colors.green : null,
                          ),
                          onChanged: item.status == "approved"
                              ? (value) {
                                  service.setTaskPaid(
                                    date: item.date,
                                    taskId: item.taskId,
                                    paid: value ?? false,
                                  );
                                }
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResponseItem {
  const _ResponseItem({
    required this.date,
    required this.taskId,
    required this.status,
    required this.paid,
    required this.title,
    required this.points,
  });

  final String date;
  final String taskId;
  final String status;
  final bool paid;
  final String? title;
  final int? points;
}

class _ResponseState {
  const _ResponseState({
    required this.status,
    required this.paid,
    required this.title,
    required this.points,
  });

  final String status;
  final bool paid;
  final String? title;
  final int? points;
}

_ResponseState? _parseResponse(Object? value) {
  if (value is bool) {
    return value
        ? const _ResponseState(
            status: "pending",
            paid: false,
            title: null,
            points: null,
          )
        : null;
  }

  if (value is Map && value['value'] == true) {
    return _ResponseState(
      status: value['status']?.toString() ?? "pending",
      paid: value['paid'] == true,
      title: value['title']?.toString(),
      points: _parsePoints(value['points']),
    );
  }

  return null;
}

String _statusLabel(String status) {
  return switch (status) {
    "approved" => "aprovada",
    "pending" => "pendente",
    "unchecked" => "desmarcada",
    "rejected" => "rejeitada",
    _ => status,
  };
}

Color _statusColor(String status) {
  return switch (status) {
    "approved" => Colors.green,
    "pending" => Colors.orange,
    "rejected" => Colors.red,
    _ => Colors.grey,
  };
}

int? _parsePoints(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ],
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
