import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final db = FirebaseFirestore.instance;
  final Map<String, int> _taskPointsCache = {};
  final Map<String, AdminTaskInfo> _taskInfoCache = {};

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

  Stream<QuerySnapshot<Map<String, dynamic>>> getAllTasks() {
    return db.collectionGroup('tasks').snapshots();
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

  Stream<QuerySnapshot<Map<String, dynamic>>> getProgressResponses() {
    return db.collection('progress').orderBy(FieldPath.documentId).snapshots();
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
    required String scheduleType,
    required List<int> weekdays,
  }) async {
    await db.collection('pillars').doc(pillarId).collection('tasks').add({
      'title': title,
      'points': points,
      'scheduleType': scheduleType,
      'weekdays': weekdays,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> seedHealthGrowthPlan() async {
    final batch = db.batch();

    for (final pillar in _defaultPillars) {
      final pillarRef = db.collection('pillars').doc(pillar.id);
      batch.set(pillarRef, {
        'title': pillar.title,
        'color': pillar.color,
        'target': pillar.target,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      for (final task in pillar.tasks) {
        final taskRef = pillarRef.collection('tasks').doc(task.id);
        batch.set(taskRef, {
          'title': task.title,
          'points': task.value,
          'scheduleType': task.scheduleType,
          'weekdays': task.weekdays,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
    _taskPointsCache.clear();
    _taskInfoCache.clear();
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
    _taskInfoCache.remove(taskId);
  }

  Future<void> updateTaskSchedule({
    required String pillarId,
    required String taskId,
    required String scheduleType,
    required List<int> weekdays,
  }) async {
    await db
        .collection('pillars')
        .doc(pillarId)
        .collection('tasks')
        .doc(taskId)
        .update({'scheduleType': scheduleType, 'weekdays': weekdays});
    _taskInfoCache.remove(taskId);
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
      'scheduleType': 'everyday',
      'weekdays': <int>[],
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
    await _updateProgressEntry(date, taskId, {'status': 'approved'});
  }

  Future<void> rejectTask(String date, String taskId) async {
    await _updateProgressEntry(date, taskId, {'status': 'rejected'});
  }

  Future<void> createManualEntry({
    required String date,
    required String title,
    required int points,
  }) async {
    final id = "manual_${DateTime.now().millisecondsSinceEpoch}";
    await db.collection('progress').doc(date).set({
      id: {
        'value': true,
        'title': title,
        'points': points,
        'status': 'approved',
        'paid': false,
        'manual': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> setTaskPaid({
    required String date,
    required String taskId,
    required bool paid,
  }) async {
    await _updateProgressEntry(date, taskId, {
      'paid': paid,
      'paidAt': paid ? FieldValue.serverTimestamp() : null,
    });
  }

  Future<int> calculateWeeklyPoints() async {
    final now = DateTime.now();
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    var snapshot = await db.collection('progress').get();

    int total = 0;

    for (var doc in snapshot.docs) {
      final date = _tryParseDate(doc.id);
      if (date == null || date.isBefore(weekStart) || date.isAfter(weekEnd)) {
        continue;
      }

      var data = doc.data();

      for (final entry in data.entries) {
        final taskId = entry.key;
        final value = entry.value;

        if (value is Map &&
            value['status'] == 'approved' &&
            value['value'] == true) {
          final entryPoints = _parsePoints(value['points']);
          total += entryPoints != 0 ? entryPoints : await getTaskPoints(taskId);
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

  Future<AdminTaskInfo> getTaskInfo(String taskId) async {
    final cached = _taskInfoCache[taskId];
    if (cached != null) return cached;

    final snapshot = await db
        .collectionGroup('tasks')
        .where(FieldPath.documentId, isEqualTo: taskId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      final fallback = AdminTaskInfo(title: taskId, points: 0);
      _taskInfoCache[taskId] = fallback;
      return fallback;
    }

    final data = snapshot.docs.first.data();
    final info = AdminTaskInfo(
      title: data['title']?.toString() ?? taskId,
      points: _parsePoints(data['points']),
    );
    _taskInfoCache[taskId] = info;
    return info;
  }

  Future<void> _updateProgressEntry(
    String date,
    String taskId,
    Map<String, Object?> updates,
  ) async {
    final docRef = db.collection('progress').doc(date);

    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      final current = data?[taskId];
      final entry = _progressEntryMap(current)..addAll(updates);

      transaction.set(docRef, {taskId: entry}, SetOptions(merge: true));
    });
  }

  Map<String, Object?> _progressEntryMap(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.from(value);
    }

    if (value is bool) {
      return {'value': value, 'status': value ? 'pending' : 'unchecked'};
    }

    return {'value': true, 'status': 'pending'};
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

  DateTime? _tryParseDate(String value) {
    final parts = value.split("-");
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;

    return DateTime(year, month, day);
  }
}

class AdminTaskInfo {
  const AdminTaskInfo({required this.title, required this.points});

  final String title;
  final int points;
}

class _DefaultPillar {
  const _DefaultPillar({
    required this.id,
    required this.title,
    required this.color,
    required this.target,
    required this.tasks,
  });

  final String id;
  final String title;
  final int color;
  final int target;
  final List<_DefaultTask> tasks;
}

class _DefaultTask {
  const _DefaultTask({
    required this.id,
    required this.title,
    required this.value,
    required this.scheduleType,
    required this.weekdays,
  });

  final String id;
  final String title;
  final int value;
  final String scheduleType;
  final List<int> weekdays;
}

final _defaultPillars = [
  _DefaultPillar(
    id: "estudo",
    title: "Estudo",
    color: 0xFF1E88E5,
    target: 2000,
    tasks: const [
      _DefaultTask(
        id: "sessao_estudo_40_min",
        title: "Sessao de estudo de 40 min",
        value: 3,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5],
      ),
      _DefaultTask(
        id: "leitura_resumo_exercicios",
        title: "Leitura, resumo ou exercicios",
        value: 2,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5],
      ),
      _DefaultTask(
        id: "recuperacao_fim_de_semana",
        title: "Recuperacao de estudo no fim de semana",
        value: 10,
        scheduleType: "custom",
        weekdays: [6, 7],
      ),
      _DefaultTask(
        id: "semana_completa_estudo",
        title: "Semana completa de estudo",
        value: 15,
        scheduleType: "custom",
        weekdays: [5],
      ),
    ],
  ),
  _DefaultPillar(
    id: "crescimento_saudavel",
    title: "Crescimento saudavel",
    color: 0xFF43A047,
    target: 1500,
    tasks: const [
      _DefaultTask(
        id: "cafe_da_manha_completo",
        title: "Cafe da manha completo",
        value: 2,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "fruta_legume_salada",
        title: "Fruta, legume ou salada no dia",
        value: 2,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "agua_garrafa_concluida",
        title: "Agua / garrafa concluida",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "sono_ate_2230",
        title: "Dormir ate 22:30 e nao passar das 11h",
        value: 2,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "sem_tela_apos_21",
        title: "Sem tela apos as 21:00",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "treino_movimento",
        title: "Treino e movimento do dia",
        value: 2,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5],
      ),
      _DefaultTask(
        id: "semana_saudavel_completa",
        title: "Semana saudavel completa",
        value: 15,
        scheduleType: "custom",
        weekdays: [7],
      ),
      _DefaultTask(
        id: "semana_de_elite",
        title: "Semana de Elite acima de 20 acertos",
        value: 30,
        scheduleType: "custom",
        weekdays: [7],
      ),
    ],
  ),
  _DefaultPillar(
    id: "rotinas_autonomia",
    title: "Rotinas e autonomia",
    color: 0xFFFB8C00,
    target: 1500,
    tasks: const [
      _DefaultTask(
        id: "arrumar_cama",
        title: "Arrumar cama",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "organizar_quarto",
        title: "Organizar quarto",
        value: 2,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "mesa_ajudar_refeicao",
        title: "Mesa pronta / ajudar refeicao",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "guardar_roupas",
        title: "Guardar roupas",
        value: 2,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "mochila_dia_seguinte",
        title: "Mochila do dia seguinte",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "comer_a_mesa_lavar_prato",
        title: "Comer a mesa e lavar o prato 2x ao dia",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "tarefa_extra_autonomia",
        title: "Tarefa extra de autonomia",
        value: 2,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "lixo_banheiros_bela",
        title: "Tirar lixo dos banheiros + coco da Bela",
        value: 4,
        scheduleType: "custom",
        weekdays: [1, 3, 5],
      ),
      _DefaultTask(
        id: "lavar_louca_almoco",
        title: "Lavar louca do almoco",
        value: 3,
        scheduleType: "custom",
        weekdays: [2, 4],
      ),
      _DefaultTask(
        id: "semana_completa_rotinas",
        title: "Semana completa de rotinas",
        value: 15,
        scheduleType: "custom",
        weekdays: [7],
      ),
    ],
  ),
];
