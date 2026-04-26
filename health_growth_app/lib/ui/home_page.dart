import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = FirestoreService();

    return Scaffold(
      appBar: AppBar(title: const Text("Health Growth 🎮")),
      body: StreamBuilder(
        stream: service.getPillars(),
        builder: (context, AsyncSnapshot snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var pillars = snapshot.data.docs;

          return ListView(
            children: pillars.map<Widget>((pillar) {
              return buildPillar(pillar, service);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget buildPillar(dynamic pillar, FirestoreService service) {
    Color color = Color(pillar['color']);

    return Card(
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              pillar['title'],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder(
              stream: service.getTasks(pillar.id),
              builder: (context, AsyncSnapshot snapshot) {
                if (!snapshot.hasData) return Container();

                var tasks = snapshot.data.docs;

                return Column(
                  children: tasks.map<Widget>((task) {
                    return ListTile(
                      leading: Checkbox(
                        value: false,
                        onChanged: (value) {},
                      ),
                      title: Text(task['title']),
                      trailing: Text("+${task['points']}"),
                    );
                  }).toList(),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}
