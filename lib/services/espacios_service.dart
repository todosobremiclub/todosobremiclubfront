// lib/services/espacios_service.dart
//
// Service de "Espacios", lado socio (app). Habla contra los
// endpoints de backend/src/routes/espaciosAppRoutes.js (montado en /app).
// El club y el socio salen del token, igual que en la Tienda.
//
// Reservas: recursos, turnos libres, crear / mías / cancelar.
// Abonos: los del socio (solo lectura; los gestiona el club).
// (Las clases / entrenamientos están en clases_service.dart.)
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

  /// Pide VARIOS horarios a la vez (hasta 6). Cada uno queda como una reserva
  /// "pendiente" separada. [turnos]: [{'fecha': 'YYYY-MM-DD', 'hora_desde': 'HH:MM'}].
  /// Si algún horario ya lo tomó otra persona, los demás igual se crean y ese
  /// vuelve en `fallidos` ([{fecha, hora_desde, error}]).
  Future<({List<Map<String, dynamic>> reservas, List<Map<String, dynamic>> fallidos})>
      crearReservasMultiples({
    required String token,
    required String recursoId,
    required List<Map<String, String>> turnos,
    String? comentario,
  }) async {
    final data = await _post(
      '/app/espacios/reservas/multiples',
      token,
      {
        'recurso_id': recursoId,
        'turnos': turnos
            .map((t) => {'fecha': t['fecha'], 'hora_desde': t['hora_desde']})
            .toList(),
        if (comentario != null && comentario.trim().isNotEmpty) 'comentario': comentario.trim(),
      },
      'No se pudieron crear las reservas',
      okStatus: 201,
    );
    return (reservas: _lista(data['reservas']), fallidos: _lista(data['fallidos']));
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
}
