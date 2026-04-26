import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final service = FirestoreService();

  String getToday() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  void showSuggestionDialog() {
    String title = "";
    String pillarId = "estudo";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Sugerir nova tarefa"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (v) => title = v,
                decoration: const InputDecoration(labelText: "Nome da tarefa"),
              ),
              DropdownButton<String>(
                value: pillarId,
                onChanged: (v) => pillarId = v!,
                items: ["estudo", "saude", "rotina"]
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await service.suggestTask(title, pillarId);
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
    String today = getToday();

    return Scaffold(
      appBar: AppBar(title: const Text("Health Growth 🎮")),
      floatingActionButton: FloatingActionButton(
        onPressed: showSuggestionDialog,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.getPillars(),
        builder: (context, pillarSnap) {
          if (!pillarSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: service.getProgress(today),
            builder: (context, progressSnap) {
              Map<String, dynamic> data = {};
              if (progressSnap.hasData && progressSnap.data!.exists) {
                data = progressSnap.data!.data() ?? {};
              }

              final pillars = pillarSnap.data!.docs;

              return ListView(
                children: pillars.map<Widget>((pillar) {
                  return buildPillar(pillar, data, today);
                }).toList(),
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
    String today,
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
                if (!taskSnap.hasData) return Container();

                final tasks = taskSnap.data!.docs;

                return Column(
                  children: tasks.map<Widget>((task) {
                    final taskData = task.data();
                    final checked = progress[task.id] as bool? ?? false;

                    return CheckboxListTile(
                      value: checked,
                      title: Text(taskData['title'] as String),
                      subtitle: Text("+${taskData['points']}"),
                      onChanged: (value) {
                        service.saveProgress(task.id, today, value ?? false);
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
}
