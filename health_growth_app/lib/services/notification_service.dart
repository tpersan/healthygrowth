import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Serviço de notificações para o app da criança
/// Gerencia notificações diretas (FCM) e programadas (locais)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Stream para notificações recebidas
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNotification =>
      _notificationController.stream;

  String? _fcmToken;
  StreamSubscription? _scheduledSubscription;

  /// Inicializa o serviço de notificações
  Future<void> initialize() async {
    await _initializeFCM();
    await _initializeLocalNotifications();
    await _listenToScheduledNotifications();
  }

  /// Configura Firebase Cloud Messaging
  Future<void> _initializeFCM() async {
    // Request permission no iOS
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: true,
      badge: true,
      carPlay: true,
      criticalAlert: true,
      provisional: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('FCM: Permission granted');
    }

    // Get token
    _fcmToken = await _fcm.getToken();
    print('FCM Token: $_fcmToken');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleFCMMessage);

    // Handle when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFCMMessageOpenedApp);
  }

  /// Configura notificações locais
  Future<void> _initializeLocalNotifications() async {
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
  }

  /// Handle FCM messages em foreground
  void _handleFCMMessage(RemoteMessage message) {
    print('FCM Message received: ${message.notification?.title}');

    final data = message.data.isNotEmpty ? message.data : <String, dynamic>{};

    if (message.notification != null) {
      data['title'] = message.notification!.title;
      data['body'] = message.notification!.body;
    }

    _notificationController.add(data);

    // Show local notification for foreground messages
    if (message.notification != null) {
      _showLocalNotification(
        id:
            message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch,
        title: message.notification!.title!,
        body: message.notification!.body!,
        payload: data['payload'] as String?,
      );
    }
  }

  /// Handle quando app é aberto via notificação
  void _handleFCMMessageOpenedApp(RemoteMessage message) {
    final data = message.data.isNotEmpty ? message.data : <String, dynamic>{};
    if (message.notification != null) {
      data['title'] = message.notification!.title;
      data['body'] = message.notification!.body;
    }
    _notificationController.add(data);
  }

  /// Handle resposta de notificação local
  void _handleLocalNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      _notificationController.add({'payload': response.payload});
    }
  }

  /// Mostra notificação local imediata
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'health_growth_channel',
      'Health Growth Notifications',
      channelDescription: 'Notificações do app Healthy Growth',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Agenda notificação local para horário específico
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
    required List<int> weekdays, // 1=Seg, 7=Dom
    String? payload,
  }) async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

    // Se o horário já passou hoje, agenda para amanhã
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Ajusta para o dia da semana correto
    while (!weekdays.contains(scheduledDate.weekday)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'health_growth_scheduled',
      'Tarefas Programadas',
      channelDescription: 'Notificações agendadas de tarefas',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // ZonedSchedule para repetição semanal
    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  /// Cancela notificação agendada
  Future<void> cancelScheduledNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  /// Cancela todas as notificações
  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// Get FCM token para enviar ao servidor
  String? get fcmToken => _fcmToken;

  /// Escuta notificações programadas do Firestore e agenda localmente
  Future<void> _listenToScheduledNotifications() async {
    _scheduledSubscription = _db
        .collection('scheduled_notifications')
        .where('active', isEqualTo: true)
        .snapshots()
        .listen((snapshot) async {
          // Cancela todas as notificações antigas
          await cancelAllNotifications();

          // Agenda cada notificação programada
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final id = doc.id.hashCode;

            await scheduleNotification(
              id: id,
              title: data['title'] ?? 'Lembrete',
              body: data['body'] ?? '',
              hour: data['hour'] ?? 8,
              minute: data['minute'] ?? 0,
              weekdays: List<int>.from(data['weekdays'] ?? [1, 2, 3, 4, 5]),
              payload: data['payload'],
            );
          }
        });
  }

  /// Dispose
  void dispose() {
    _scheduledSubscription?.cancel();
    _notificationController.close();
  }
}
