import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Sistema Health Growth - Heitor
/// Baseado em: Growth_Saudavel-prototipo revisado.pdf
class FirestoreService {
  final db = FirebaseFirestore.instance;

  // ========== PILARES ==========

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

  // ========== PROGRESSO DIÁRIO ==========

  Stream<DocumentSnapshot<Map<String, dynamic>>> getTodayProgress() {
    return db.collection('progress').doc(_todayKey()).snapshots();
  }

  Future<void> saveTodayProgress({
    required String taskId,
    required String title,
    required int points,
    required bool value,
    String pillar = 'estudo',
  }) async {
    await db.collection('progress').doc(_todayKey()).set({
      taskId: {
        'value': value,
        'title': title,
        'points': points,
        'status': value ? 'pending' : 'unchecked',
        'pillar': pillar,
        'paid': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  // ========== MISSÕES ESPECÍFICAS POR PILAR ==========

  // Pilar 1 - ESTUDO (Meta: R$2.000)
  Future<void> completeStudySession() async {
    await _addMission('estudo_sessao', 'Sessão de estudo 40min', 3, 'estudo');
  }

  Future<void> completeReading() async {
    await _addMission(
      'estudo_leitura',
      'Leitura/resumo/exercícios',
      2,
      'estudo',
    );
  }

  Future<void> completeNota(double nota) async {
    int pontos = 0;
    if (nota >= 10) {
      pontos = 40;
    } else if (nota >= 9)
      pontos = 30;
    else if (nota >= 8)
      pontos = 20;

    if (pontos > 0) {
      await _addMission('estudo_nota', 'Nota $nota', pontos, 'estudo');
    }
  }

  // Pilar 2 - CRESCIMENTO SAUDÁVEL (Meta: R$1.500)
  Future<void> completeCafeCompleto() async {
    await _addMission('saude_cafe', 'Café da manhã completo', 2, 'saude');
  }

  Future<void> completeFrutaLegume() async {
    await _addMission('saude_fruta', 'Fruta/legume/salada no dia', 2, 'saude');
  }

  Future<void> completeAgua() async {
    await _addMission('saude_agua', 'Água 2L concluída', 1, 'saude');
  }

  Future<void> completeSono() async {
    await _addMission('saude_sono', 'Dormir até 22:30', 2, 'saude');
  }

  Future<void> completeSemTela() async {
    await _addMission('saude_tela', 'Sem tela após 21:00', 1, 'saude');
  }

  Future<void> completeTreino() async {
    await _addMission('saude_treino', 'Treino do dia', 2, 'saude');
  }

  // Pilar 3 - ROTINAS (Meta: R$1.500)
  Future<void> completeArrumarCama() async {
    await _addMission('rotina_cama', 'Arrumar cama', 1, 'rotinas');
  }

  Future<void> completeOrganizarQuarto() async {
    await _addMission('rotina_quarto', 'Organizar quarto', 2, 'rotinas');
  }

  Future<void> completeMesaPronta() async {
    await _addMission(
      'rotina_mesa',
      'Mesa pronta/ajudar refeição',
      1,
      'rotinas',
    );
  }

  Future<void> completeGuardarRoupas() async {
    await _addMission('rotina_roupas', 'Guardar roupas', 2, 'rotinas');
  }

  Future<void> completeMochila() async {
    await _addMission(
      'rotina_mochila',
      'Mochila do dia seguinte',
      1,
      'rotinas',
    );
  }

  Future<void> completeLouca() async {
    await _addMission('rotina_louca', 'Lavar louça do almoço', 3, 'rotinas');
  }

  Future<void> completeLixo() async {
    await _addMission(
      'rotina_lixo',
      'Tirar lixo banheiros + coco',
      4,
      'rotinas',
    );
  }

  Future<void> completeTarefaExtra() async {
    await _addMission(
      'rotina_extra',
      'Tarefa extra de autonomia',
      2,
      'rotinas',
    );
  }

  // ========== BÔNUS SEMANAIS ==========

  Future<void> completeSemanaEstudo() async {
    await _addMission(
      'bonus_semana_estudo',
      'Semana completa de estudo',
      15,
      'estudo',
    );
  }

  Future<void> completeSemanaSaudavel() async {
    await _addMission(
      'bonus_semana_saudavel',
      'Semana saudável completa',
      15,
      'saude',
    );
  }

  Future<void> completeSemanaRotinas() async {
    await _addMission(
      'bonus_semana_rotinas',
      'Semana completa de rotinas',
      15,
      'rotinas',
    );
  }

  Future<void> completeSemanaElite() async {
    await _addMission(
      'bonus_semana_elite',
      'Semana de Elite (+20 acertos)',
      30,
      'saude',
    );
  }

  Future<void> completeRecovery() async {
    await _addMission(
      'bonus_recovery',
      'Recuperação de strike no fim de semana',
      10,
      'estudo',
    );
  }

  Future<void> completeChefaoSemana() async {
    await _addMission(
      'bonus_chefao',
      'Chefão da semana (+R\$100)',
      100,
      'geral',
    );
  }

  // ========== COMBOS ==========

  Future<void> completeCombo3dias() async {
    await _addMission('combo_3', 'Combo 3 dias', 5, 'geral');
  }

  Future<void> completeCombo7dias() async {
    await _addMission('combo_7', 'Combo 7 dias', 15, 'geral');
  }

  Future<void> completeCombo14dias() async {
    await _addMission('combo_14', 'Combo 14 dias', 40, 'geral');
  }

  // ========== PENALIDADES ==========

  Future<void> applyPenalty(String tipo, int valor) async {
    await db.collection('penalties').doc(_todayKey()).set({
      tipo: {'valor': valor, 'data': FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  // ========== SUGESTÕES ==========

  Future<void> suggestTask(String title, String pillarId) async {
    await db.collection('suggestions').add({
      "title": title,
      "pillarId": pillarId,
      "status": "pending",
      "createdAt": Timestamp.now(),
    });
  }

  // ========== HISTÓRICO E ESTATÍSTICAS ==========

  Stream<DocumentSnapshot<Map<String, dynamic>>> getUserStats() {
    return db.collection('users').doc('heitor').snapshots();
  }

  Future<void> updateLevel(int novoLevel) async {
    await db.collection('users').doc('heitor').set({
      'level': novoLevel,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateTotalPoints(int pontos) async {
    await db.collection('users').doc('heitor').set({
      'totalPoints': pontos,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ========== HELPERS ==========

  Future<void> _addMission(
    String id,
    String titulo,
    int pontos,
    String pilar,
  ) async {
    await db.collection('progress').doc(_todayKey()).set({
      id: {
        'title': titulo,
        'points': pontos,
        'pillar': pilar,
        'value': true,
        'status': 'pending',
        'paid': false,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  String _todayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }
}
