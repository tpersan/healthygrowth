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

  // ========== METAS SEMANAIS ==========

  Stream<DocumentSnapshot<Map<String, dynamic>>> getWeeklyGoal(
    String weekKey,
  ) {
    return db.collection('weekly_goals').doc(weekKey).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getWeeklyGoals() {
    return db
        .collection('weekly_goals')
        .orderBy(FieldPath.documentId, descending: true)
        .limit(12)
        .snapshots();
  }

  Future<void> setWeeklyGoalText({
    required String weekKey,
    required String goal,
  }) async {
    await db.collection('weekly_goals').doc(weekKey).set({
      'goal': goal,
      'createdBy': 'admin',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setWeeklyGoalPercent({
    required String weekKey,
    required String dateKey,
    required num percent,
  }) async {
    await db.collection('weekly_goals').doc(weekKey).set({
      'percentByDay.$dateKey': percent.clamp(0, 100),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
    final docRef = db.collection('progress').doc(date);
    final userRef = db.collection('users').doc('heitor');

    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      final entry = _progressEntryMap(data?[taskId]);
      final wasApproved = entry['status'] == 'approved';
      entry['status'] = 'approved';
      transaction.set(docRef, {taskId: entry}, SetOptions(merge: true));

      if (!wasApproved) {
        final points = _parsePoints(entry['points']);
        final pillar = entry['pillar']?.toString() ?? 'geral';
        if (points != 0) {
          transaction.set(
            userRef,
            {
              'pillarPoints.$pillar': FieldValue.increment(points),
              'totalPoints': FieldValue.increment(points),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
    });
  }

  Future<void> rejectTask(String date, String taskId) async {
    final docRef = db.collection('progress').doc(date);
    final userRef = db.collection('users').doc('heitor');

    await db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      final entry = _progressEntryMap(data?[taskId]);
      final wasApproved = entry['status'] == 'approved';
      entry['status'] = 'rejected';
      transaction.set(docRef, {taskId: entry}, SetOptions(merge: true));

      if (wasApproved) {
        final points = _parsePoints(entry['points']);
        final pillar = entry['pillar']?.toString() ?? 'geral';
        if (points != 0) {
          transaction.set(
            userRef,
            {
              'pillarPoints.$pillar': FieldValue.increment(-points),
              'totalPoints': FieldValue.increment(-points),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
    });
  }

  /// Aplica uma penalidade manualmente (lançamento direto aprovado)
  Future<void> applyPenaltyEntry({
    required String date,
    required String category,
    required int amount,
    String? description,
  }) async {
    final id = 'penalty_${DateTime.now().millisecondsSinceEpoch}';
    final userRef = db.collection('users').doc('heitor');
    final docRef = db.collection('progress').doc(date);

    final batch = db.batch();
    batch.set(
      docRef,
      {
        id: {
          'value': true,
          'title': description ?? category,
          'points': amount,
          'status': 'approved',
          'paid': false,
          'pillar': 'penalidades',
          'isPenalty': true,
          'category': category,
          'createdAt': FieldValue.serverTimestamp(),
        },
      },
      SetOptions(merge: true),
    );
    batch.set(
      userRef,
      {
        'pillarPoints.penalidades': FieldValue.increment(amount),
        'totalPoints': FieldValue.increment(amount),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Incrementa o contador de notas 10 e verifica o Chefão das Notas
  Future<void> incrementNote10Count() async {
    final userRef = db.collection('users').doc('heitor');
    await userRef.set(
      {
        'note10count': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Retorna stream do documento do usuário (contém totalPoints, pillarPoints, note10count)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStatsStream() {
    return db.collection('users').doc('heitor').snapshots();
  }

  /// Calcula o total acumulado de todos os tempos (aprovados)
  Future<int> calculateTotalPoints() async {
    final snapshot = await db.collection('progress').get();
    int total = 0;
    for (final doc in snapshot.docs) {
      for (final entry in doc.data().values) {
        if (entry is Map &&
            entry['status'] == 'approved' &&
            entry['value'] == true) {
          total += _parsePoints(entry['points']);
        }
      }
    }
    return total;
  }

  /// Lê a reflexão semanal
  Stream<DocumentSnapshot<Map<String, dynamic>>> getWeeklyReflection(
    String weekKey,
  ) {
    return db.collection('weekly_reflections').doc(weekKey).snapshots();
  }

  /// Salva a reflexão semanal
  Future<void> saveWeeklyReflection({
    required String weekKey,
    required String pillarUp,
    required String obstacle,
    required String simplify,
  }) async {
    await db.collection('weekly_reflections').doc(weekKey).set({
      'pillarUp': pillarUp,
      'obstacle': obstacle,
      'simplify': simplify,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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
      // Missões diárias
      _DefaultTask(
        id: "sessao_estudo_40_min",
        title: "Sessão de estudo de 40 min",
        value: 3,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5],
      ),
      _DefaultTask(
        id: "leitura_resumo_exercicios",
        title: "Leitura, resumo ou exercícios",
        value: 2,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5],
      ),
      // Bônus semanal
      _DefaultTask(
        id: "semana_completa_estudo",
        title: "Semana completa de estudo",
        value: 15,
        scheduleType: "custom",
        weekdays: [5],
      ),
      // Recuperação
      _DefaultTask(
        id: "recuperacao_fim_de_semana",
        title: "Recuperação de strike no fim de semana",
        value: 10,
        scheduleType: "custom",
        weekdays: [6, 7],
      ),
      // Notas escolares
      _DefaultTask(
        id: "nota_8",
        title: "Nota 8 ou mais",
        value: 20,
        scheduleType: "custom",
        weekdays: [7],
      ),
      _DefaultTask(
        id: "nota_9",
        title: "Nota 9",
        value: 30,
        scheduleType: "custom",
        weekdays: [7],
      ),
      _DefaultTask(
        id: "nota_10",
        title: "Nota 10",
        value: 40,
        scheduleType: "custom",
        weekdays: [7],
      ),
      // Chefão das notas - desbloqueia ao bater 5 notas 10
      _DefaultTask(
        id: "chefao_notas",
        title: "Chefão das notas (5 notas 10)",
        value: 150,
        scheduleType: "custom",
        weekdays: [7],
      ),
    ],
  ),
  _DefaultPillar(
    id: "crescimento_saudavel",
    title: "Crescimento Saudável",
    color: 0xFF43A047,
    target: 1500,
    tasks: const [
      // Alimentação
      _DefaultTask(
        id: "cafe_da_manha_completo",
        title: "Café da manhã completo",
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
        title: "Água / garrafa concluída (2L)",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      // Sono e tela
      _DefaultTask(
        id: "sono_ate_2230",
        title: "Dormir até 22:30",
        value: 2,
        scheduleType: "everyday",
        weekdays: [],
      ),
      _DefaultTask(
        id: "sem_tela_apos_21",
        title: "Sem tela após as 21:00",
        value: 1,
        scheduleType: "everyday",
        weekdays: [],
      ),
      // Movimento
      _DefaultTask(
        id: "treino_movimento",
        title: "Treino e movimento do dia",
        value: 2,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5],
      ),
      // Bônus semanal
      _DefaultTask(
        id: "semana_saudavel_completa",
        title: "Semana saudável completa",
        value: 15,
        scheduleType: "custom",
        weekdays: [7],
      ),
      _DefaultTask(
        id: "semana_de_elite",
        title: "Semana de Elite (+20 acertos)",
        value: 30,
        scheduleType: "custom",
        weekdays: [7],
      ),
      // Bonus delivery a cada 15 dias
      _DefaultTask(
        id: "bonus_delivery",
        title: "Bônus delivery especial (15 dias)",
        value: 0,
        scheduleType: "custom",
        weekdays: [7],
      ),
    ],
  ),
  _DefaultPillar(
    id: "rotinas_autonomia",
    title: "Rotinas e Autonomia",
    color: 0xFFFB8C00,
    target: 1500,
    tasks: const [
      // Diárias
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
        title: "Mesa pronta / ajudar refeição",
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
        title: "Comer na mesa e lavar o prato 2x",
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
      // Tarefas fixas da semana
      _DefaultTask(
        id: "lixo_banheiros_bela",
        title: "Tirar lixo banheiros + coco da Bela",
        value: 4,
        scheduleType: "custom",
        weekdays: [1, 3, 5],
      ),
      _DefaultTask(
        id: "lavar_louca_almoco",
        title: "Lavar louça do almoço",
        value: 3,
        scheduleType: "custom",
        weekdays: [2, 4],
      ),
      // Bônus semanal
      _DefaultTask(
        id: "semana_completa_rotinas",
        title: "Semana completa de rotinas",
        value: 15,
        scheduleType: "custom",
        weekdays: [7],
      ),
    ],
  ),
  // Pilares de Bônus e Combos
  _DefaultPillar(
    id: "bonus",
    title: "Bônus e Combos",
    color: 0xFF9C27B0,
    target: 0,
    tasks: const [
      _DefaultTask(
        id: "combo_3_dias",
        title: "Combo 3 dias",
        value: 5,
        scheduleType: "custom",
        weekdays: [3, 7],
      ),
      _DefaultTask(
        id: "combo_7_dias",
        title: "Combo 7 dias",
        value: 15,
        scheduleType: "custom",
        weekdays: [7],
      ),
      _DefaultTask(
        id: "combo_14_dias",
        title: "Combo 14 dias",
        value: 40,
        scheduleType: "custom",
        weekdays: [7],
      ),
      _DefaultTask(
        id: "chefao_semana",
        title: "Chefão da semana (perfeita)",
        value: 100,
        scheduleType: "custom",
        weekdays: [7],
      ),
    ],
  ),
  // Pilares de Penalidades
  _DefaultPillar(
    id: "penalidades",
    title: "Penalidades",
    color: 0xFFE53935,
    target: 0,
    tasks: const [
      _DefaultTask(
        id: "mentir",
        title: "Mentir",
        value: -10,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5, 6, 7],
      ),
      _DefaultTask(
        id: "quebrar_regra",
        title: "Quebrar regra combinada",
        value: -5,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5, 6, 7],
      ),
      _DefaultTask(
        id: "dia_zerado",
        title: "Dia zerado sem esforço",
        value: -2,
        scheduleType: "custom",
        weekdays: [1, 2, 3, 4, 5, 6, 7],
      ),
    ],
  ),
];
