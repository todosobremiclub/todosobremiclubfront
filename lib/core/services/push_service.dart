import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_store.dart';

class PushService {
  static final FirebaseMessaging _fm = FirebaseMessaging.instance;

  // ======================================================
// Handler para mensajes cuando la app está terminada
// (ANDROID / iOS)
// ======================================================
@pragma('vm:entry-point')
static Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  debugPrint('[FCM:bg] ${message.messageId} data=${message.data}');

  try {
    final notif = message.notification;

    if (notif != null) {
      await NotificationStore.instance.agregar(
        AppNotification(
          titulo: notif.title ?? 'SIN TITULO',
          mensaje: notif.body ?? 'SIN MENSAJE',
          fecha: DateTime.now(),
        ),
      );

      debugPrint('✅ Notificación guardada en background');
    } else {
      debugPrint('⚠️ message.notification es NULL');

      // 🔥 fallback por si viene como DATA (muy importante)
      final data = message.data;

      if (data.isNotEmpty) {
        await NotificationStore.instance.agregar(
          AppNotification(
            titulo: data['title'] ?? 'SIN TITULO',
            mensaje: data['body'] ?? 'SIN MENSAJE',
            fecha: DateTime.now(),
          ),
        );

        debugPrint('✅ Notificación guardada desde DATA');
      }
    }
  } catch (e) {
    debugPrint('❌ Error en background handler: $e');
  }
}

  // ======================================================
  // Inicialización general de FCM
  // ======================================================
  static Future<void> init() async {
    // 🔴 En WEB no inicializamos Messaging
    if (kIsWeb) {
      debugPrint('[FCM] Web detectado: init() ignorado');
      return;
    }

    // iOS / Android 13+: pedir permisos
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    // iOS: mostrar notificación también en foreground (opcional)
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  // ======================================================
  // Suscribirse a un club (TOPICS)
  // ======================================================
  static Future<void> subscribeToClub(String clubId) async {
    // 🔴 Firebase Web NO soporta subscribeToTopic
    if (kIsWeb) {
      debugPrint('[FCM] Web: subscribeToClub ignorado (club_$clubId)');
      return;
    }

    final topic = 'club_$clubId';
    await _fm.subscribeToTopic(topic);
    debugPrint('[FCM] subscribed topic=$topic');
  }

  // ======================================================
  // Desuscribirse de un club
  // ======================================================
  static Future<void> unsubscribeFromClub(String clubId) async {
    // 🔴 Firebase Web NO soporta unsubscribeFromTopic
    if (kIsWeb) {
      debugPrint('[FCM] Web: unsubscribeFromClub ignorado (club_$clubId)');
      return;
    }

    final topic = 'club_$clubId';
    await _fm.unsubscribeFromTopic(topic);
    debugPrint('[FCM] unsubscribed topic=$topic');
  }
}
