import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/club.dart';
import '../../models/socio.dart';

class StorageService {
  static const _kToken = 'app_token';
  static const _kSocio = 'app_socio';
  static const _kClub = 'app_club';

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
