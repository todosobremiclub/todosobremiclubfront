import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'core/services/storage_service.dart';
import 'core/config/api_config.dart';
import 'core/config/app_theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/admin/admin_home_screen.dart'; // ✅ NUEVO
import 'screens/update/force_update_screen.dart'; // ✅ NUEVO: bloqueo por versión mínima

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // ======================================================
  // ✅ NUEVO: chequeo de versión mínima (bloqueante)
  // Consulta GET /app/config (sin auth) y compara el build
  // instalado contra el mínimo permitido para esta plataforma.
  // Si falla la consulta (sin internet, backend caído, etc.)
  // NO bloqueamos: preferimos dejar entrar antes que trabar
  // a todo el mundo por un problema de red.
  // ======================================================
  Future<String?> _checkForceUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      if (currentBuild <= 0) return null;

      final res = await http
          .get(Uri.parse(ApiConfig.appConfigUrl))
          .timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      if (data is! Map || data['ok'] != true) return null;

      final esIOS = defaultTargetPlatform == TargetPlatform.iOS;

      final minBuild = esIOS
          ? (data['minBuildIOS'] as num?)?.toInt() ?? 0
          : (data['minBuildAndroid'] as num?)?.toInt() ?? 0;

      final storeUrl = esIOS
          ? data['storeUrlIOS']?.toString()
          : data['storeUrlAndroid']?.toString();

      if (minBuild > 0 &&
          currentBuild < minBuild &&
          storeUrl != null &&
          storeUrl.isNotEmpty) {
        return storeUrl;
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  Future<_SesionInicial> _load() async {
    // ✅ NUEVO: si hay que forzar actualización, cortamos acá y no
    // seguimos cargando ninguna sesión (ni admin ni socio).
    final storeUrlBloqueo = await _checkForceUpdate();
    if (storeUrlBloqueo != null) {
      return _SesionInicial(forceUpdateStoreUrl: storeUrlBloqueo);
    }

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

        // ✅ NUEVO: bloqueo por versión mínima (tiene prioridad sobre todo)
        if (resultado?.forceUpdateStoreUrl != null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(useMaterial3: true),
            home: ForceUpdateScreen(storeUrl: resultado!.forceUpdateStoreUrl!),
          );
        }

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
  final String? forceUpdateStoreUrl; // ✅ NUEVO

  _SesionInicial({this.admin, this.socio, this.forceUpdateStoreUrl});
}