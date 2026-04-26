import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final db = FirebaseFirestore.instance;
  final Map<String, int> _taskPointsCache = {};

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

  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingSuggestions() {
    return db
        .collection('suggestions')
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getPendingProgress() {
    return db.collection('progress').snapshots();
  }

  Future<void> createPillar({required String title, required int color}) async {
    final id = _slugify(title);
    await db.collection('pillars').doc(id).set({
      'title': title,
      'color': color,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> createTask({
    required String pillarId,
    required String title,
    required int points,
  }) async {
    await db.collection('pillars').doc(pillarId).collection('tasks').add({
      'title': title,
      'points': points,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTaskPoints({
    required String pillarId,
    required String taskId,
    required int points,
  }) async {
    await db
        .collection('pillars')
        .doc(pillarId)
        .collection('tasks')
        .doc(taskId)
        .update({'points': points});
    _taskPointsCache.remove(taskId);
  }

  Future<void> approveSuggestion({
    required String suggestionId,
    required String pillarId,
    required String title,
    required int points,
  }) async {
    final taskRef = db
        .collection('pillars')
        .doc(pillarId)
        .collection('tasks')
        .doc();
    final suggestionRef = db.collection('suggestions').doc(suggestionId);
    final batch = db.batch();

    batch.set(taskRef, {
      'title': title,
      'points': points,
      'createdAt': FieldValue.serverTimestamp(),
      'sourceSuggestionId': suggestionId,
    });
    batch.update(suggestionRef, {
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedTaskId': taskRef.id,
      'points': points,
    });

    await batch.commit();
  }

  Future<void> rejectSuggestion(String suggestionId) async {
    await db.collection('suggestions').doc(suggestionId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> approveTask(String date, String taskId) async {
    await db.collection('progress').doc(date).update({
      "$taskId.status": "approved",
    });
  }

  Future<int> calculateWeeklyPoints() async {
    var snapshot = await db.collection('progress').get();

    int total = 0;

    for (var doc in snapshot.docs) {
      var data = doc.data();

      for (final entry in data.entries) {
        final taskId = entry.key;
        final value = entry.value;

        if (value is Map &&
            value['status'] == 'approved' &&
            value['value'] == true) {
          total += await getTaskPoints(taskId);
        }
      }
    }

    return total;
  }

  Future<int> getTaskPoints(String taskId) async {
    final cached = _taskPointsCache[taskId];
    if (cached != null) return cached;

    final snapshot = await db
        .collectionGroup('tasks')
        .where(FieldPath.documentId, isEqualTo: taskId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      _taskPointsCache[taskId] = 0;
      return 0;
    }

    final data = snapshot.docs.first.data();
    final points = _parsePoints(data['points']);
    _taskPointsCache[taskId] = points;
    return points;
  }

  int _parsePoints(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String _slugify(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (normalized.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch.toString();
    }

    return normalized;
  }
}
