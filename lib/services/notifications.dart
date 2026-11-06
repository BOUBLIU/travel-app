import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notifications locales (dépassement de seuils de budget).
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _plugin.initialize(settings: settings);
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _ready = true;
    } catch (e) {
      debugPrint('Notifications indisponibles : $e');
    }
  }

  Future<void> show(int id, String title, String body) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'budget_alerts',
        'Alertes budget',
        channelDescription: 'Dépassement du budget total ou d\'une catégorie',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _plugin.show(id: id, title: title, body: body, notificationDetails: details);
    } catch (e) {
      debugPrint('Notification non envoyée : $e');
    }
  }
}
