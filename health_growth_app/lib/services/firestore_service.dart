import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirestoreService {
  final db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getPillars() {
    return db.collection('pillars').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getTasks(String pillarId) {
    return db
        .collection('pillars')
        .doc(pillarId)
        .collection('tasks')
        .snapshots();
  }

  Future<void> saveTodayProgress({
    required String taskId,
    required String title,
    required int points,
    required bool value,
  }) async {
    await db.collection('progress').doc(_todayKey()).set({
      taskId: {
        'value': value,
        'title': title,
        'points': points,
        'status': value ? 'pending' : 'unchecked',
        'paid': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getTodayProgress() {
    return db.collection('progress').doc(_todayKey()).snapshots();
  }

  Future<void> suggestTask(String title, String pillarId) async {
    await db.collection('suggestions').add({
      "title": title,
      "pillarId": pillarId,
      "status": "pending",
      "createdAt": Timestamp.now(),
    });
  }

  String _todayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}
