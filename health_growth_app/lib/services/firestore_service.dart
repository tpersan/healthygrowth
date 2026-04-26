import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> saveProgress(String taskId, String date, bool value) async {
    await db.collection('progress').doc(date).set({
      taskId: value,
    }, SetOptions(merge: true));
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> getProgress(String date) {
    return db.collection('progress').doc(date).snapshots();
  }

  Future<void> suggestTask(String title, String pillarId) async {
    await db.collection('suggestions').add({
      "title": title,
      "pillarId": pillarId,
      "status": "pending",
      "createdAt": Timestamp.now(),
    });
  }
}
