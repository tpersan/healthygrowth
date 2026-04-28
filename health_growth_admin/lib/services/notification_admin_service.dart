import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço de notificações para o admin
/// Gerencia envio de notificações diretas e programadas para o app da criança
class NotificationAdminService {
  final db = FirebaseFirestore.instance;

  /// Envia notificação direta para o app da criança
  /// Armazena no Firestore para ser monitorado pelo app
  Future<void> sendDirectNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final docRef = db.collection('notifications').doc();

    await docRef.set({
      'type': 'direct',
      'title': title,
      'body': body,
      'payload': payload,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });

    print('Notification sent: $title');
  }

  /// Agenda notificação programada
  /// O app da criança monitora esta coleção e agenda localmente
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays, // 1=Seg, 7=Dom
    String? payload,
  }) async {
    final docRef = db.collection('scheduled_notifications').doc();

    await docRef.set({
      'type': 'scheduled',
      'title': title,
      'body': body,
      'hour': hour,
      'minute': minute,
      'weekdays': weekdays,
      'payload': payload,
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
    });

    print('Scheduled notification: $title at $hour:$minute');
  }

  /// Cancela notificação programada
  Future<void> cancelScheduledNotification(String notificationId) async {
    await db.collection('scheduled_notifications').doc(notificationId).update({
      'active': false,
    });
  }

  /// Notifica sobre nova tarefa criada
  Future<void> notifyNewTask({
    required String taskTitle,
    required String pillarTitle,
  }) async {
    await sendDirectNotification(
      title: '📝 Nova Tarefa!',
      body: 'Nova tarefa "$taskTitle" adicionada em $pillarTitle',
      payload: 'task:$taskTitle',
    );
  }

  /// Notifica sobre tarefa aprovada
  Future<void> notifyTaskApproved({
    required String taskTitle,
    required int points,
  }) async {
    await sendDirectNotification(
      title: '✅ Tarefa Aprovada!',
      body: 'A tarefa "$taskTitle" foi aprovada! +$points pontos 🎉',
      payload: 'approved:$taskTitle',
    );
  }

  /// Notifica sobre tarefa rejeitada
  Future<void> notifyTaskRejected({
    required String taskTitle,
    required String reason,
  }) async {
    await sendDirectNotification(
      title: '❌ Tarefa Não Aprovada',
      body: 'A tarefa "$taskTitle" precisa de ajustes: $reason',
      payload: 'rejected:$taskTitle',
    );
  }

  /// Stream de notificações programadas ativas
  Stream<QuerySnapshot<Map<String, dynamic>>> getScheduledNotifications() {
    return db
        .collection('scheduled_notifications')
        .where('active', isEqualTo: true)
        .snapshots();
  }

  /// Remove todas as notificações programadas
  Future<void> clearAllScheduledNotifications() async {
    final snapshot = await db
        .collection('scheduled_notifications')
        .where('active', isEqualTo: true)
        .get();

    final batch = db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'active': false});
    }
    await batch.commit();
  }
}
