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
            return const Center(child: Text("Nenhuma resposta marcada"));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];

              return FutureBuilder<AdminTaskInfo>(
                future: service.getTaskInfo(item.taskId),
                builder: (context, taskSnapshot) {
                  final task = taskSnapshot.data;
                  final title = item.title ?? task?.title ?? item.taskId;
                  final points = item.points ?? task?.points;
                  final status = _statusLabel(item.status);
                  final pointsText = points == null ? "" : " - R\$$points";

                  return CheckboxListTile(
                    value: item.paid,
                    title: Text(title),
                    subtitle: Text("${item.date} - $status$pointsText"),
                    secondary: const Icon(Icons.payments_outlined),
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

int? _parsePoints(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
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
