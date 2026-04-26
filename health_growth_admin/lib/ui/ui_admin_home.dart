import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import 'task_management_page.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final service = AdminService();
  int weeklyPoints = 0;

  @override
  void initState() {
    super.initState();
    loadPoints();
  }

  Future<void> loadPoints() async {
    final pts = await service.calculateWeeklyPoints();
    if (!mounted) return;

    setState(() {
      weeklyPoints = pts;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADM"),
        actions: [
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
            child: Text(
              "Total da semana: $weeklyPoints pontos",
              style: const TextStyle(fontSize: 20),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.getPendingProgress(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs;

                return ListView(
                  children: docs.map<Widget>((doc) {
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

                          if (task is Map && task['status'] == 'pending') {
                            return ListTile(
                              title: Text(taskId),
                              subtitle: const Text("Pendente"),
                              trailing: IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () async {
                                  await service.approveTask(doc.id, taskId);
                                  if (!mounted) return;
                                  await loadPoints();
                                },
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
}
