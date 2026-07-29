import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/club.dart';
import '../../models/socio.dart';

class StorageService {
  static const _kToken = 'app_token';
  static const _kSocio = 'app_socio';
  static const _kClub = 'app_club';

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

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kSocio);
    await prefs.remove(_kClub);
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