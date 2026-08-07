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

    // ✅ En iOS, subscribeToTopic falla silenciosamente si el token
    // de APNs todavía no está registrado. Esperamos a que esté listo
    // (hasta 5 segundos) antes de intentar la suscripción.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        String? apnsToken = await _fm.getAPNSToken();
        var intentos = 0;
        while (apnsToken == null && intentos < 10) {
          await Future.delayed(const Duration(milliseconds: 500));
          apnsToken = await _fm.getAPNSToken();
          intentos++;
        }
        debugPrint('[FCM] APNs token listo: ${apnsToken != null} (intentos=$intentos)');
      } catch (e) {
        debugPrint('[FCM] Error esperando APNs token: $e');
      }
    }

    try {
      await _fm.subscribeToTopic(topic);
      debugPrint('[FCM] subscribed topic=$topic');
    } catch (e) {
      debugPrint('FCM ERROR al suscribir a $topic: $e');
    }
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

  // ======================================================
  // ⚠️ IMPORTANTE: normalizeForTopic() debe ser un espejo EXACTO
  // de slugForTopic() en backend/src/routes/notificacionesRoutes.js.
  // Si se modifica una función, hay que modificar la otra igual,
  // sino los nombres de topic no van a coincidir y los push
  // segmentados van a dejar de llegar.
  // ======================================================
  static String normalizeForTopic(String? value) {
    final v = value ?? '';

    const Map<String, String> _acentos = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
      'Á': 'a', 'À': 'a', 'Ä': 'a', 'Â': 'a', 'Ã': 'a',
      'É': 'e', 'È': 'e', 'Ë': 'e', 'Ê': 'e',
      'Í': 'i', 'Ì': 'i', 'Ï': 'i', 'Î': 'i',
      'Ó': 'o', 'Ò': 'o', 'Ö': 'o', 'Ô': 'o', 'Õ': 'o',
      'Ú': 'u', 'Ù': 'u', 'Ü': 'u', 'Û': 'u',
      'Ñ': 'n', 'Ç': 'c',
    };

    final sinAcentos = v.split('').map((ch) => _acentos[ch] ?? ch).join();

    var out = sinAcentos.toLowerCase();
    out = out.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    out = out.replaceAll(RegExp(r'^_+|_+$'), '');
    if (out.length > 60) out = out.substring(0, 60);

    return out;
  }

  // ======================================================
  // Helpers internos: nombres de topic (deben coincidir 1:1
  // con buildFcmTarget() del backend)
  // ======================================================
  static String _topicActividad(String clubId, String actividad) =>
      'club_${clubId}_act_${normalizeForTopic(actividad)}';

  static String _topicCategoria(String clubId, String categoria) =>
      'club_${clubId}_cat_${normalizeForTopic(categoria)}';

  static String _topicAnio(String clubId, String anio) =>
      'club_${clubId}_anio_${normalizeForTopic(anio)}';

  static String _topicFaltaPago(String clubId) => 'club_${clubId}_faltapago';

  // ======================================================
  // Suscripción / desuscripción genérica (con manejo de
  // kIsWeb y errores, igual que subscribeToClub)
  // ======================================================
  static Future<void> _subscribe(String topic) async {
    if (kIsWeb) {
      debugPrint('[FCM] Web: subscribe ignorado ($topic)');
      return;
    }
    try {
      await _fm.subscribeToTopic(topic);
      debugPrint('[FCM] subscribed topic=$topic');
    } catch (e) {
      debugPrint('FCM ERROR (subscribe $topic): $e');
    }
  }

  static Future<void> _unsubscribe(String topic) async {
    if (kIsWeb) {
      debugPrint('[FCM] Web: unsubscribe ignorado ($topic)');
      return;
    }
    try {
      await _fm.unsubscribeFromTopic(topic);
      debugPrint('[FCM] unsubscribed topic=$topic');
    } catch (e) {
      debugPrint('FCM ERROR (unsubscribe $topic): $e');
    }
  }

  // ======================================================
  // Por Actividad
  // ======================================================
  static Future<void> subscribeToActividad(String clubId, String actividad) =>
      _subscribe(_topicActividad(clubId, actividad));

  static Future<void> unsubscribeFromActividad(
    String clubId,
    String actividad,
  ) => _unsubscribe(_topicActividad(clubId, actividad));

  // ======================================================
  // Por Categoría
  // ======================================================
  static Future<void> subscribeToCategoria(String clubId, String categoria) =>
      _subscribe(_topicCategoria(clubId, categoria));

  static Future<void> unsubscribeFromCategoria(
    String clubId,
    String categoria,
  ) => _unsubscribe(_topicCategoria(clubId, categoria));

  // ======================================================
  // Por Año de nacimiento
  // ======================================================
  static Future<void> subscribeToAnioNacimiento(String clubId, String anio) =>
      _subscribe(_topicAnio(clubId, anio));

  static Future<void> unsubscribeFromAnioNacimiento(
    String clubId,
    String anio,
  ) => _unsubscribe(_topicAnio(clubId, anio));

  // ======================================================
  // Falta de pago
  // ======================================================
  static Future<void> subscribeToFaltaPago(String clubId) =>
      _subscribe(_topicFaltaPago(clubId));

  static Future<void> unsubscribeFromFaltaPago(String clubId) =>
      _unsubscribe(_topicFaltaPago(clubId));

  // ======================================================
  // Sincroniza TODOS los topics segmentados del socio de una
  // sola vez. Se llama después del login, en el cold start
  // (main.dart) y cada vez que se re-sincroniza la sesión
  // (por ej. junto con el chequeo de expiración de 8hs).
  //
  // actividad / categoria / anioNacimiento pueden venir null
  // si el socio no tiene ese dato cargado.
  // ======================================================
  static Future<void> syncTopicsForSocio({
    required String clubId,
    String? actividad,
    String? categoria,
    String? anioNacimiento,
    required bool enFaltaPago,
  }) async {
    // club_$clubId (todos) siempre suscripto
    await subscribeToClub(clubId);

    if (actividad != null && actividad.trim().isNotEmpty) {
      await subscribeToActividad(clubId, actividad);
    }

    if (categoria != null && categoria.trim().isNotEmpty) {
      await subscribeToCategoria(clubId, categoria);
    }

    if (anioNacimiento != null && anioNacimiento.trim().isNotEmpty) {
      await subscribeToAnioNacimiento(clubId, anioNacimiento);
    }

    if (enFaltaPago) {
      await subscribeToFaltaPago(clubId);
    } else {
      await unsubscribeFromFaltaPago(clubId);
    }
  }
}