import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ En Web no inicializamos Firebase (evita: FirebaseOptions cannot be null)
  if (kIsWeb) {
    runApp(const MyApp());
    return;
  }

  // ✅ Mobile (Android/iOS)
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(
    PushService.firebaseMessagingBackgroundHandler,
  );

  await PushService.init();

  runApp(const MyApp());
}
