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

  /// Crea una reserva de un solo producto (sin carrito). Se mantiene por
  /// compatibilidad; el flujo nuevo con carrito usa [crearPedido].
  /// No valida stock acá: el stock recién se descuenta cuando el admin
  /// acepta la reserva desde el panel.
  Future<Map<String, dynamic>> crearReserva({
    required String token,
    required String productoId,
    required int cantidad,
    String? talleId,
  }) async {
    final data = await crearPedido(
      token: token,
      items: [
        {
          'producto_id': productoId,
          if (talleId != null) 'talle_id': talleId,
          'cantidad': cantidad,
        },
      ],
    );
    final reservas = List<Map<String, dynamic>>.from(data['reservas'] ?? []);
    return reservas.isNotEmpty ? reservas.first : {};
  }

  /// ✅ NUEVO: crea un pedido con uno o varios productos (carrito). Todas
  /// las líneas quedan agrupadas bajo un mismo `pedido_id` y el admin las
  /// gestiona en conjunto (aceptar/rechazar/retirar/cobrar el pedido
  /// completo). `items` es una lista de
  /// { producto_id, talle_id? (si el producto tiene talles), cantidad }.
  Future<Map<String, dynamic>> crearPedido({
    required String token,
    required List<Map<String, dynamic>> items,
  }) async {
    if (items.isEmpty) {
      throw Exception('El carrito está vacío');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}/app/tienda/reservas');
    final res = await http.post(
      url,
      headers: _headers(token),
      body: jsonEncode({'items': items}),
    );

    final data = _decode(res);
    if (res.statusCode != 201 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'No se pudo confirmar el pedido');
    }

    return data;
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
