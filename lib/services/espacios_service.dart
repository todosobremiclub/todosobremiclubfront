// lib/services/espacios_service.dart
//
// Service de "Espacios y Clases", lado socio (app). Habla contra los
// endpoints de backend/src/routes/espaciosAppRoutes.js (montado en /app).
// El club y el socio salen del token, igual que en la Tienda.
//
// Reservas: recursos, turnos libres, crear / mías / cancelar.
// Abonos: los del socio (solo lectura; los gestiona el club).
// Clases: todas las del club y las del socio (las inscripciones las hace el club).
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class EspaciosService {
  static const _timeout = Duration(seconds: 25);

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

  Future<Map<String, dynamic>> _get(String path, String token, String errorDefault) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = await http.get(url, headers: _headers(token)).timeout(_timeout);
    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? errorDefault);
    }
    return data;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    String token,
    Map<String, dynamic> body,
    String errorDefault, {
    int okStatus = 200,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');
    final res = await http
        .post(url, headers: _headers(token), body: jsonEncode(body))
        .timeout(_timeout);
    final data = _decode(res);
    if (res.statusCode != okStatus || data['ok'] != true) {
      throw Exception(data['error'] ?? errorDefault);
    }
    return data;
  }

  List<Map<String, dynamic>> _lista(dynamic v) =>
      List<Map<String, dynamic>>.from((v ?? []) as List);

  // ------------------------------------------------------------------
  // Reservas
  // ------------------------------------------------------------------

  /// Recursos que el socio puede reservar desde la app.
  Future<List<Map<String, dynamic>>> getRecursos({required String token}) async {
    final data = await _get('/app/espacios/recursos', token, 'No se pudieron cargar los espacios');
    return _lista(data['recursos']);
  }

  /// Turnos LIBRES de un recurso entre [desde] y [hasta] (YYYY-MM-DD, máx. 31 días).
  /// Devuelve la lista de días: [{ fecha, turnos: [{hora_desde, hora_hasta}] }].
  Future<List<Map<String, dynamic>>> getTurnos({
    required String token,
    required String recursoId,
    required String desde,
    required String hasta,
  }) async {
    final data = await _get(
      '/app/espacios/recursos/$recursoId/turnos?desde=$desde&hasta=$hasta',
      token,
      'No se pudieron cargar los turnos',
    );
    return _lista(data['dias']);
  }

  /// Pide un turno. Queda "pendiente" hasta que el club lo acepte.
  Future<Map<String, dynamic>> crearReserva({
    required String token,
    required String recursoId,
    required String fecha,
    required String horaDesde,
    String? comentario,
  }) async {
    final data = await _post(
      '/app/espacios/reservas',
      token,
      {
        'recurso_id': recursoId,
        'fecha': fecha,
        'hora_desde': horaDesde,
        if (comentario != null && comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
      },
      'No se pudo crear la reserva',
      okStatus: 201,
    );
    return Map<String, dynamic>.from(data['reserva'] ?? {});
  }

  /// Reservas del socio: próximas primero y los últimos 90 días de historial.
  Future<List<Map<String, dynamic>>> getMisReservas({required String token}) async {
    final data = await _get('/app/espacios/reservas/mias', token, 'No se pudieron cargar tus reservas');
    return _lista(data['reservas']);
  }

  Future<void> cancelarReserva({required String token, required String id}) async {
    await _post('/app/espacios/reservas/$id/cancelar', token, {}, 'No se pudo cancelar la reserva');
  }

  // ------------------------------------------------------------------
  // Abonos
  // ------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getMisAbonos({required String token}) async {
    final data = await _get('/app/espacios/abonos/mios', token, 'No se pudieron cargar tus abonos');
    return _lista(data['abonos']);
  }

  // ------------------------------------------------------------------
  // Clases
  // ------------------------------------------------------------------

  /// Todas las clases activas del club (con cupo e indicador "inscripto").
  Future<List<Map<String, dynamic>>> getClases({required String token}) async {
    final data = await _get('/app/clases', token, 'No se pudieron cargar las clases');
    return _lista(data['clases']);
  }

  /// Clases donde el socio está inscripto, con sus próximas fechas
  /// (las canceladas vienen con cancelada: true).
  Future<List<Map<String, dynamic>>> getMisClases({required String token}) async {
    final data = await _get('/app/clases/mias', token, 'No se pudieron cargar tus clases');
    return _lista(data['clases']);
  }
}
