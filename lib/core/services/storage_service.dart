import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/club.dart';
import '../../models/socio.dart';

class StorageService {
  static const _kToken = 'app_token';
  static const _kSocio = 'app_socio';
  static const _kClub = 'app_club';
  static const _kLoginAt = 'app_login_at'; // ✅ NUEVO: timestamp de login (auto-logout 8hs)

  // ✅ NUEVO: tiempo máximo de sesión antes del auto-logout
  static const Duration sessionMaxAge = Duration(hours: 8);

  // ===== Sesión de ADMINISTRADOR =====
  static const _kAdminToken = 'admin_token';
  static const _kAdminEmail = 'admin_email';
  static const _kAdminRole = 'admin_role';
  static const _kAdminClubId = 'admin_club_id';
  static const _kAdminClubName = 'admin_club_name';

  /// Guarda token + socio + club como JSON (string)
  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> socio,
    required Map<String, dynamic> club,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kSocio, jsonEncode(socio));
    await prefs.setString(_kClub, jsonEncode(club));
    // ✅ NUEVO: marca el momento del login para el auto-logout de 8hs
    await prefs.setString(_kLoginAt, DateTime.now().toIso8601String());
  }

  /// Devuelve null si falta algo
  static Future<AppSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final socioStr = prefs.getString(_kSocio);
    final clubStr = prefs.getString(_kClub);

    if (token == null || token.isEmpty) return null;
    if (socioStr == null || socioStr.isEmpty) return null;
    if (clubStr == null || clubStr.isEmpty) return null;

    return AppSession(
      token: token,
      socio: jsonDecode(socioStr) as Map<String, dynamic>,
      club: jsonDecode(clubStr) as Map<String, dynamic>,
    );
  }

  /// ✅ NUEVO: true si pasaron 8hs o más desde el último login del socio.
  /// Si no hay timestamp guardado (sesión guardada antes de este cambio,
  /// o dato corrupto), se considera expirada por seguridad.
  static Future<bool> isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final loginAtStr = prefs.getString(_kLoginAt);
    if (loginAtStr == null || loginAtStr.isEmpty) return true;

    final loginAt = DateTime.tryParse(loginAtStr);
    if (loginAt == null) return true;

    return DateTime.now().difference(loginAt) >= sessionMaxAge;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kSocio);
    await prefs.remove(_kClub);
    await prefs.remove(_kLoginAt); // ✅ NUEVO
  }

  // ======================================================
  // Sesión de ADMINISTRADOR
  // ======================================================

  /// Guarda la sesión de un administrador logueado con email/password.
  /// Por ahora tomamos el primer rol/club del array (un admin puede
  /// tener varios clubes; el selector múltiple queda para más adelante).
  static Future<void> saveAdminSession({
    required String token,
    required String email,
    required String role,
    required String clubId,
    required String clubName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAdminToken, token);
    await prefs.setString(_kAdminEmail, email);
    await prefs.setString(_kAdminRole, role);
    await prefs.setString(_kAdminClubId, clubId);
    await prefs.setString(_kAdminClubName, clubName);
  }

  /// Devuelve null si no hay sesión de admin guardada
  static Future<AdminSession?> loadAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kAdminToken);
    final email = prefs.getString(_kAdminEmail);
    final role = prefs.getString(_kAdminRole);
    final clubId = prefs.getString(_kAdminClubId);
    final clubName = prefs.getString(_kAdminClubName);

    if (token == null || token.isEmpty) return null;
    if (email == null || role == null) return null;
    if (clubId == null || clubName == null) return null;

    return AdminSession(
      token: token,
      email: email,
      role: role,
      clubId: clubId,
      clubName: clubName,
    );
  }

  static Future<void> clearAdminSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAdminToken);
    await prefs.remove(_kAdminEmail);
    await prefs.remove(_kAdminRole);
    await prefs.remove(_kAdminClubId);
    await prefs.remove(_kAdminClubName);
  }

  // ======================================================
  // ✅ NUEVO: "Recordarme" (checkbox del login de socio)
  // Guarda usuario/contraseña para prellenar el formulario la próxima
  // vez que se muestre LoginScreen. No tiene nada que ver con mantener
  // la sesión iniciada (eso ya lo hacen saveSession/loadSession): esto
  // solo evita tener que volver a tipear los datos de acceso después de
  // un logout manual o del auto-logout de 8hs.
  // ⚠️ Se guarda en SharedPreferences sin cifrar, igual que el token de
  // sesión (mismo nivel de protección que ya tiene hoy la app).
  // ======================================================
  static const _kRememberMe = 'app_remember_me';
  static const _kRememberedUsuario = 'app_remembered_usuario';
  static const _kRememberedContrasena = 'app_remembered_contrasena';

  static Future<void> saveRememberedCredentials({
    required String usuario,
    required String contrasena,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMe, true);
    await prefs.setString(_kRememberedUsuario, usuario);
    await prefs.setString(_kRememberedContrasena, contrasena);
  }

  static Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMe, false);
    await prefs.remove(_kRememberedUsuario);
    await prefs.remove(_kRememberedContrasena);
  }

  /// Devuelve null si el socio nunca activó "Recordarme" (o lo desactivó).
  static Future<RememberedCredentials?> loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final activo = prefs.getBool(_kRememberMe) ?? false;
    if (!activo) return null;

    final usuario = prefs.getString(_kRememberedUsuario);
    final contrasena = prefs.getString(_kRememberedContrasena);
    if (usuario == null || contrasena == null) return null;

    return RememberedCredentials(usuario: usuario, contrasena: contrasena);
  }

  // ======================================================
  // ✅ NUEVO: "Recordarme" — misma idea que arriba, pero para el login
  // de ADMINISTRADOR (email + contraseña). Se guarda aparte del de socio
  // para que cambiar de modo en LoginScreen no mezcle ni pise los datos
  // recordados del otro modo.
  // ⚠️ Igual que el de socio: sin cifrar en SharedPreferences.
  // ======================================================
  static const _kAdminRememberMe = 'app_admin_remember_me';
  static const _kAdminRememberedEmail = 'app_admin_remembered_email';
  static const _kAdminRememberedPassword = 'app_admin_remembered_password';

  static Future<void> saveRememberedAdminCredentials({
    required String email,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminRememberMe, true);
    await prefs.setString(_kAdminRememberedEmail, email);
    await prefs.setString(_kAdminRememberedPassword, password);
  }

  static Future<void> clearRememberedAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminRememberMe, false);
    await prefs.remove(_kAdminRememberedEmail);
    await prefs.remove(_kAdminRememberedPassword);
  }

  /// Devuelve null si el administrador nunca activó "Recordarme" (o lo
  /// desactivó).
  static Future<RememberedCredentials?> loadRememberedAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final activo = prefs.getBool(_kAdminRememberMe) ?? false;
    if (!activo) return null;

    final email = prefs.getString(_kAdminRememberedEmail);
    final password = prefs.getString(_kAdminRememberedPassword);
    if (email == null || password == null) return null;

    return RememberedCredentials(usuario: email, contrasena: password);
  }
}

class RememberedCredentials {
  final String usuario;
  final String contrasena;

  RememberedCredentials({required this.usuario, required this.contrasena});
}

class AppSession {
  final String token;
  final Map<String, dynamic> socio;
  final Map<String, dynamic> club;

  AppSession({
    required this.token,
    required this.socio,
    required this.club,
  });

  Socio get socioObj => Socio.fromJson(socio);
  Club get clubObj => Club.fromJson(club);
}

class AdminSession {
  final String token;
  final String email;
  final String role;
  final String clubId;
  final String clubName;

  AdminSession({
    required this.token,
    required this.email,
    required this.role,
    required this.clubId,
    required this.clubName,
  });
}