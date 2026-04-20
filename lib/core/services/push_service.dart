import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushService {
  static final FirebaseMessaging _fm = FirebaseMessaging.instance;

  // Handler para mensajes cuando la app está terminada/background (Android)
  @pragma('vm:entry-point')
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    // OJO: acá no uses cosas de UI. Solo logs / lógica mínima.
    debugPrint('[FCM:bg] ${message.messageId} data=${message.data}');
  }

  static Future<void> init() async {
    // iOS: pedir permisos (en Android 13+ también aplica)
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    // iOS: mostrar notificación también en foreground si querés (opcional)
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> subscribeToClub(String clubId) async {
    final topic = 'club_$clubId';
    await _fm.subscribeToTopic(topic);
    debugPrint('[FCM] subscribed topic=$topic');
  }

  static Future<void> unsubscribeFromClub(String clubId) async {
    final topic = 'club_$clubId';
    await _fm.unsubscribeFromTopic(topic);
    debugPrint('[FCM] unsubscribed topic=$topic');
  }
}