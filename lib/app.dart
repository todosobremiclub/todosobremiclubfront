import 'package:flutter/material.dart';
import 'core/services/storage_service.dart';
import 'core/config/app_theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_home_screen.dart'; // ✅ NUEVO

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<_SesionInicial> _load() async {
    // ✅ Primero chequeamos si hay sesión de ADMINISTRADOR guardada
    final adminSession = await StorageService.loadAdminSession();
    if (adminSession != null) {
      return _SesionInicial(admin: adminSession);
    }

    // Si no hay admin, seguimos con el flujo normal de SOCIO
    final appSession = await StorageService.loadSession();

    // ✅ NUEVO: auto-logout si pasaron 8hs o más desde el login
    if (appSession != null) {
      final expirada = await StorageService.isSessionExpired();
      if (expirada) {
        await StorageService.clearSession();
        return _SesionInicial(socio: null);
      }
    }

    return _SesionInicial(socio: appSession);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SesionInicial>(
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

        final resultado = snapshot.data;

        // ✅ Caso ADMINISTRADOR: sin theme dinámico de club, va directo
        if (resultado?.admin != null) {
          return MaterialApp(
            title: 'Todo Sobre Mi Club - Admin',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true),
            home: const AdminHomeScreen(),
          );
        }

        final session = resultado?.socio;

        // ✅ Theme dinámico si hay sesión de socio
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

class _SesionInicial {
  final AdminSession? admin;
  final AppSession? socio;

  _SesionInicial({this.admin, this.socio});
}