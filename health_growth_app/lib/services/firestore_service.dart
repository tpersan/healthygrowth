import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final db = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getPillars() {
    return db.collection('pillars').snapshots();
  }

  Stream<QuerySnapshot> getTasks(String pillarId) {
    return db.collection('pillars').doc(pillarId).collection('tasks').snapshots();
  }
}
