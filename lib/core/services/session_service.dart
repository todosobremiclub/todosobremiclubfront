import 'package:flutter/material.dart';

import 'storage_service.dart';
import '../../screens/login/login_screen.dart';

/// ✅ NUEVO: cierre de sesión automático cuando el backend informa que
/// el token del administrador venció o es inválido (HTTP 401).
///
/// El token de un administrador dura 8hs (ver
/// backend/src/routes/authRoutes.js, POST /auth/login,
/// `jwt.sign(..., { expiresIn: '8h' })`). Antes de este cambio, cuando
/// el token vencía, cualquier pantalla de administración que hiciera un
/// pedido a la API (AdminApiService) mostraba un error crudo como
/// "Exception: Error en la operación (HTTP 401)", sin explicar qué pasó
/// ni volver a la pantalla de login. Eso generaba consultas de usuarios
/// que no entendían el error ("se rompió la app").
///
/// Con este servicio, apenas cualquier pedido de AdminApiService recibe
/// un HTTP 401, se limpia la sesión guardada y se navega automáticamente
/// a LoginScreen con un mensaje claro, sin importar en qué pantalla
/// estaba el usuario en ese momento.
///
/// Usa un GlobalKey<NavigatorState> (asignado al MaterialApp en
/// lib/app.dart) para poder navegar sin depender del BuildContext de la
/// pantalla puntual que hizo el pedido que falló.
class SessionService {
  SessionService._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static bool _cerrandoSesion = false;

  /// Limpia la sesión de administrador guardada y vuelve al login.
  /// Es seguro llamarlo varias veces seguidas (ej: si 2 pedidos a la API
  /// fallan con 401 casi al mismo tiempo): solo la primera llamada actúa,
  /// las siguientes no hacen nada hasta que termine.
  static Future<void> forceAdminLogout({
    String mensaje = 'Tu sesión expiró. Iniciá sesión nuevamente.',
  }) async {
    if (_cerrandoSesion) return;
    _cerrandoSesion = true;

    try {
      await StorageService.clearAdminSession();

      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );

        final context = navigator.context;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(mensaje),
              duration: const Duration(seconds: 4),
            ),
          );
        });
      }
    } finally {
      _cerrandoSesion = false;
    }
  }
}
