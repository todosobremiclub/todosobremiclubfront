// lib/services/clases_service.dart
//
// Clases / entrenamientos del socio. Habla contra backend/src/routes/clasesAppRoutes.js
// (montado en /app). El club y el socio salen del token.
// Las clases las crea el club desde la Agenda del panel y asigna a los socios.
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class ClasesService {
  static const _timeout = Duration(seconds: 25);

  /// Clases asignadas al socio, ordenadas por la próxima fecha. Cada una trae:
  /// id, titulo, descripcion, hora_desde, hora_hasta, recurrente,
  /// frecuencia_texto, proxima y proximas [{fecha, hora_desde, hora_hasta}].
  Future<List<Map<String, dynamic>>> getMisClases({required String token}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/app/clases/mias');
    final res = await http.get(url, headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    }).timeout(_timeout);

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta inválida del servidor (HTTP ${res.statusCode})');
    }
    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'No se pudieron cargar tus clases');
    }
    return List<Map<String, dynamic>>.from((data['clases'] ?? []) as List);
  }
}
