import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

class AuthService {
  String? _token;

  String? get token => _token;

  Map<String, String> get authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> login({
    required String numeroSocio,
    required String dni,
  }) async {
    final Uri initialUrl =
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.appLogin}');

    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'numero': numeroSocio,
      'dni': dni,
    });

    http.Response res = await http.post(
      initialUrl,
      headers: headers,
      body: body,
    );

    if ((res.statusCode == 307 || res.statusCode == 308) &&
        res.headers['location'] != null) {
      final location = res.headers['location']!;
      Uri redirectUrl;

      if (location.startsWith('http://') ||
          location.startsWith('https://')) {
        redirectUrl = Uri.parse(location);
      } else {
        redirectUrl = initialUrl.resolve(location);
      }

      res = await http.post(
        redirectUrl,
        headers: headers,
        body: body,
      );
    }

    if (res.statusCode != 200) {
      throw Exception('Login falló (HTTP ${res.statusCode})');
    }

    final data = jsonDecode(res.body);

    if (data is! Map || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Login inválido');
    }

    if (data['token'] != null) {
      _token = data['token'];
    }

    return Map<String, dynamic>.from(data);
  }

  // ======================================================
  // Login de ADMINISTRADOR (email + password)
  // Mismo endpoint /auth/login que usa la web de gestión.
  // ======================================================
  Future<Map<String, dynamic>> loginAdmin({
    required String email,
    required String password,
  }) async {
    final Uri url = Uri.parse(ApiConfig.adminLoginUrl);

    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta inválida del servidor (HTTP ${res.statusCode})');
    }

    if (res.statusCode != 200 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Credenciales incorrectas');
    }

    if (data['token'] != null) {
      _token = data['token'];
    }

    return data;
  }
}