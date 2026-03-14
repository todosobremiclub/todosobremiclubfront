import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class AuthService {
  Future<Map<String, dynamic>> login({
    required String numeroSocio,
    required String dni,
  }) async {
    final Uri initialUrl =
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.appLogin}');

    // Body y headers compartidos
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'numero': numeroSocio,
      'dni': dni,
    });

    // 1️⃣ Primer intento
    http.Response res = await http.post(
      initialUrl,
      headers: headers,
      body: body,
    );

    // 2️⃣ Si hay redirección 307/308, seguimos UNA vez
    if ((res.statusCode == 307 || res.statusCode == 308) &&
        res.headers['location'] != null) {
      final location = res.headers['location']!;
      Uri redirectUrl;

      // Si la Location es absoluta (https://...), usamos esa
      if (location.startsWith('http://') || location.startsWith('https://')) {
        redirectUrl = Uri.parse(location);
      } else {
        // Si es relativa (/app/login), la resolvemos contra la original
        redirectUrl = initialUrl.resolve(location);
      }

      // Segundo intento en la URL de redirección
      res = await http.post(
        redirectUrl,
        headers: headers,
        body: body,
      );
    }

    // 3️⃣ Validamos respuesta final
    if (res.statusCode != 200) {
      throw Exception('Login falló (HTTP ${res.statusCode})');
    }

    final data = jsonDecode(res.body);

    if (data is! Map || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Login inválido');
    }

    return Map<String, dynamic>.from(data);
  }
}