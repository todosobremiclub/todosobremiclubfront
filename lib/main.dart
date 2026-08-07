import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/services/push_service.dart';
import 'firebase_options.dart';
import 'core/services/storage_service.dart';
import 'core/services/notification_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Inicializar store persistente de notificaciones
  await NotificationStore.instance.init();

  // ✅ Inicializar Push SOLO en mobile
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(
      PushService.firebaseMessagingBackgroundHandler,
    );

    await PushService.init();
  }

  // ======================================================
  // 🔔 NOTIFICACIÓN EN FOREGROUND
  // ======================================================
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("🔥 PUSH RECIBIDA (FOREGROUND)");
    print("DATA: ${message.data}");
    print("NOTIF: ${message.notification?.title}");

    final notif = message.notification;

    if (notif != null) {
      await NotificationStore.instance.agregar(
        AppNotification(
          titulo: notif.title ?? 'SIN TITULO',
          mensaje: notif.body ?? 'SIN MENSAJE',
          fecha: DateTime.now(),
        ),
      );

      print("✅ GUARDADA EN STORE (FOREGROUND)");
    } else {
      print("⚠️ notification es NULL");
    }
  });

  // ======================================================
  // 🔔 APP ABIERTA DESDE NOTIFICACIÓN (BACKGROUND)
  // ======================================================
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    print("📲 APP ABIERTA DESDE PUSH");

    final notif = message.notification;

    if (notif != null) {
      await NotificationStore.instance.agregar(
        AppNotification(
          titulo: notif.title ?? 'SIN TITULO',
          mensaje: notif.body ?? 'SIN MENSAJE',
          fecha: DateTime.now(),
        ),
      );

      print("✅ GUARDADA (openedApp)");
    }
  });

  // ======================================================
  // 🔔 APP ABIERTA DESDE ESTADO CERRADO
  // ======================================================
  final initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    print("🚀 APP ABIERTA DESDE NOTIFICACIÓN (KILLED)");

    final notif = initialMessage.notification;

    if (notif != null) {
      await NotificationStore.instance.agregar(
        AppNotification(
          titulo: notif.title ?? 'SIN TITULO',
          mensaje: notif.body ?? 'SIN MENSAJE',
          fecha: DateTime.now(),
        ),
      );

      print("✅ GUARDADA (initialMessage)");
    }
  }

// ======================================================
  // 📡 SUSCRIPCIÓN A TOPICS DEL SOCIO (club, actividad,
  // categoría, año de nacimiento y falta de pago)
  // ======================================================
  final session = await StorageService.loadSession();

  if (session != null && !kIsWeb) {
    final clubId = session.club['id'].toString();
    final socioObj = session.socioObj;

    print("📡 Sincronizando topics para club_$clubId");

    await PushService.syncTopicsForSocio(
      clubId: clubId,
      actividad: socioObj.actividad,
      categoria: socioObj.categoria,
      anioNacimiento:
          socioObj.anioNacimiento == '—' ? null : socioObj.anioNacimiento,
      enFaltaPago: !socioObj.alDia,
    );

    print("✅ Topics sincronizados para club_$clubId");
  } else {
    print("⚠️ No hay sesión → no se suscribe a topics");
  }

  // ======================================================
  // 🚀 RUN APP
  // ======================================================
  runApp(const MyApp());
}