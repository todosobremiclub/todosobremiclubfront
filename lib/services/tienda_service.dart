// lib/services/tienda_service.dart
//
// Service de la Tienda Online, lado socio (app). Habla contra los
// endpoints de backend/src/routes/appRoutes.js (bloque "TIENDA ONLINE
// (app del socio)"), que siempre sacan clubId/socioId del token — igual
// que el resto de los endpoints de /app.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class TiendaService {
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

  /// Catálogo de productos activos del club del socio logueado.
  /// El backend devuelve 403 si el club no tiene Tienda Online habilitada.
  Future<List<Map<String, dynamic>>> getProductos({
    required String token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/tienda/productos');
    final res = await http.get(url, headers: _headers(token));

    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Error al obtener los productos de la tienda');
    }

    return List<Map<String, dynamic>>.from(data['productos'] ?? []);
  }

  /// Crea una reserva. No valida stock acá: el stock recién se descuenta
  /// cuando el admin acepta la reserva desde el panel.
  Future<Map<String, dynamic>> crearReserva({
    required String token,
    required String productoId,
    required int cantidad,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/tienda/reservas');
    final res = await http.post(
      url,
      headers: _headers(token),
      body: jsonEncode({
        'producto_id': productoId,
        'cantidad': cantidad,
      }),
    );

    final data = _decode(res);
    if (res.statusCode != 201 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'No se pudo reservar el producto');
    }

    return Map<String, dynamic>.from(data['reserva'] ?? {});
  }

  /// Historial de reservas del socio logueado, más recientes primero.
  Future<List<Map<String, dynamic>>> getMisReservas({
    required String token,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/tienda/reservas/mias');
    final res = await http.get(url, headers: _headers(token));

    final data = _decode(res);
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Error al obtener tus reservas');
    }

    return List<Map<String, dynamic>>.from(data['reservas'] ?? []);
  }
}
