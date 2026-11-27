import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/club.dart';
import '../../models/socio.dart';

class StorageService {
  // 🔒 Etapa 5 (F-07): tokens, datos de sesión y credenciales recordadas se guardan CIFRADOS
  // (Android Keystore / iOS Keychain). SharedPreferences queda solo para banderas y fechas.
  static const FlutterSecureStorage _sec = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Lee de almacenamiento seguro. Si no está, busca el valor viejo en SharedPreferences
  /// (instalaciones anteriores), lo migra al almacenamiento seguro y lo borra del viejo lugar.
  static Future<String?> _getSecure(String key) async {
    try {
      final v = await _sec.read(key: key);
      if (v != null) return v;
    } catch (_) {
      // Keystore corrupto o restaurado de otro dispositivo: se trata como "sin dato".
      try {
        await _sec.deleteAll();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(key);
    if (legacy == null) return null;
    try {
      await _sec.write(key: key, value: legacy);
      await prefs.remove(key);
    } catch (_) {}
    return legacy;
  }

  static Future<void> _setSecure(String key, String value) async {
    await _sec.write(key: key, value: value);
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key)) await prefs.remove(key);
  }

  static Future<void> _delSecure(String key) async {
    try {
      await _sec.delete(key: key);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(key)) await prefs.remove(key);
  }

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
  static const _kAdminLoginAt = 'admin_login_at'; // 🔒 vencimiento de la sesión de admin

  /// Guarda token + socio + club como JSON (string)
  static Future<void> saveSession({
    required String token,
    required Map<String, dynamic> socio,
    required Map<String, dynamic> club,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _setSecure(_kToken, token);
    await _setSecure(_kSocio, jsonEncode(socio));
    await _setSecure(_kClub, jsonEncode(club));
    // ✅ NUEVO: marca el momento del login para el auto-logout de 8hs
    await prefs.setString(_kLoginAt, DateTime.now().toIso8601String());
  }

  /// Devuelve null si falta algo
  static Future<AppSession?> loadSession() async {
    final token = await _getSecure(_kToken);
    final socioStr = await _getSecure(_kSocio);
    final clubStr = await _getSecure(_kClub);

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
    await _delSecure(_kToken);
    await _delSecure(_kSocio);
    await _delSecure(_kClub);
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
    await _setSecure(_kAdminToken, token);
    await _setSecure(_kAdminEmail, email);
    await _setSecure(_kAdminRole, role);
    await _setSecure(_kAdminClubId, clubId);
    await _setSecure(_kAdminClubName, clubName);
    await prefs.setString(_kAdminLoginAt, DateTime.now().toIso8601String());
  }

  /// 🔒 true si pasaron 8 hs o más desde el login del admin (o no hay fecha guardada:
  /// sesiones creadas antes de esta versión se consideran vencidas y piden login de nuevo).
  static Future<bool> isAdminSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_kAdminLoginAt);
    if (s == null || s.isEmpty) return true;
    final at = DateTime.tryParse(s);
    if (at == null) return true;
    return DateTime.now().difference(at) >= sessionMaxAge;
  }

  /// Devuelve null si no hay sesión de admin guardada
  static Future<AdminSession?> loadAdminSession() async {
    final token = await _getSecure(_kAdminToken);
    final email = await _getSecure(_kAdminEmail);
    final role = await _getSecure(_kAdminRole);
    final clubId = await _getSecure(_kAdminClubId);
    final clubName = await _getSecure(_kAdminClubName);

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
    await _delSecure(_kAdminToken);
    await _delSecure(_kAdminEmail);
    await _delSecure(_kAdminRole);
    await _delSecure(_kAdminClubId);
    await _delSecure(_kAdminClubName);
    await prefs.remove(_kAdminLoginAt);
  }

  // ======================================================
  // ✅ NUEVO: "Recordarme" (checkbox del login de socio)
  // Guarda usuario/contraseña para prellenar el formulario la próxima
  // vez que se muestre LoginScreen. No tiene nada que ver con mantener
  // la sesión iniciada (eso ya lo hacen saveSession/loadSession): esto
  // solo evita tener que volver a tipear los datos de acceso después de
  // un logout manual o del auto-logout de 8hs.
  // 🔒 Se guarda en almacenamiento seguro cifrado (Keystore / Keychain).
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
    await _setSecure(_kRememberedUsuario, usuario);
    await _setSecure(_kRememberedContrasena, contrasena);
  }

  static Future<void> clearRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRememberMe, false);
    await _delSecure(_kRememberedUsuario);
    await _delSecure(_kRememberedContrasena);
  }

  /// Devuelve null si el socio nunca activó "Recordarme" (o lo desactivó).
  static Future<RememberedCredentials?> loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final activo = prefs.getBool(_kRememberMe) ?? false;
    if (!activo) return null;

    final usuario = await _getSecure(_kRememberedUsuario);
    final contrasena = await _getSecure(_kRememberedContrasena);
    if (usuario == null || contrasena == null) return null;

    return RememberedCredentials(usuario: usuario, contrasena: contrasena);
  }

  // ======================================================
  // ✅ NUEVO: "Recordarme" — misma idea que arriba, pero para el login
  // de ADMINISTRADOR (email + contraseña). Se guarda aparte del de socio
  // para que cambiar de modo en LoginScreen no mezcle ni pise los datos
  // recordados del otro modo.
  // 🔒 Igual que el de socio: almacenamiento seguro cifrado.
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
    await _setSecure(_kAdminRememberedEmail, email);
    await _setSecure(_kAdminRememberedPassword, password);
  }

  static Future<void> clearRememberedAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAdminRememberMe, false);
    await _delSecure(_kAdminRememberedEmail);
    await _delSecure(_kAdminRememberedPassword);
  }

  /// Devuelve null si el administrador nunca activó "Recordarme" (o lo
  /// desactivó).
  static Future<RememberedCredentials?> loadRememberedAdminCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final activo = prefs.getBool(_kAdminRememberMe) ?? false;
    if (!activo) return null;

    final email = await _getSecure(_kAdminRememberedEmail);
    final password = await _getSecure(_kAdminRememberedPassword);
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