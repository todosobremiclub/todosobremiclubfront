import 'package:flutter/material.dart';
import 'core/services/storage_service.dart';
import 'core/config/app_theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<AppSession?> _load() => StorageService.loadSession();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppSession?>(
      future: _load(),
      builder: (context, snapshot) {
        // Loading inicial
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final session = snapshot.data;

        // ✅ Theme dinámico si hay sesión
        final theme = session != null
            ? AppTheme.fromClub(session.clubObj)
            : ThemeData(useMaterial3: true);

        return MaterialApp(
          title: 'Todo Sobre Mi Club',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: session != null
              ? HomeScreen(session: session)
              : const LoginScreen(),
        );
      },
    );
  }
}