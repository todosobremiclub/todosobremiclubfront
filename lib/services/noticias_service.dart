import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class NoticiasService {
  Future<List<Map<String, dynamic>>> getNoticias({
    required String token,
    required String clubId,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/club/$clubId/noticias');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Error al obtener noticias');
    }

    final data = jsonDecode(res.body);
    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Error al obtener noticias');
    }

    return List<Map<String, dynamic>>.from(data['noticias']);
  }
}