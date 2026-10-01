// lib/services/socio_service.dart
//
// Service de "Cambiar de socio" (lado app del socio). Habla contra los
// endpoints nuevos de backend/src/routes/appRoutes.js:
//   GET  /app/socios-relacionados  -> socios que el logueado puede ver
//                                     (Grupo Familiar + relación manual)
//   POST /app/socios/cambiar       -> arma una sesión nueva para otro
//                                     socio relacionado, SIN pedir DNI.
//
// Igual que TiendaService, siempre sacamos clubId/socioId del token (no
// se mandan por body/URL).
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class SocioService {
  Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta inválida del servidor (HTTP ${res.statusCode})');
    }
  }

  /// Socios que el socio logueado puede "ver" sin volver a loguearse:
  /// los de su mismo Grupo Familiar y los relacionados a mano desde el
  /// panel admin. Devuelve lista vacía si no tiene ninguno (la pantalla
  /// debe ocultar el selector en ese caso).
  Future<List<Map<String, dynamic>>> getSociosRelacionados({
    required String token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/socios-relacionados');
    final res = await http.get(url, headers: _headers(token));

    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Error al obtener los socios relacionados');
    }

    return List<Map<String, dynamic>>.from(data['socios'] ?? []);
  }

  /// Cambia la sesión activa a otro socio relacionado (Grupo Familiar o
  /// manual), sin pedir DNI. Devuelve la misma forma que AuthService.login
  /// ({ok, token, socio, club}) para poder guardarla con
  /// StorageService.saveSession igual que tras un login normal.
  Future<Map<String, dynamic>> cambiarSocio({
    required String token,
    required String socioId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/socios/cambiar');
    final res = await http.post(
      url,
      headers: _headers(token),
      body: jsonEncode({'socio_id': socioId}),
    );

    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'No se pudo cambiar de socio');
    }

    return data;
  }
}
