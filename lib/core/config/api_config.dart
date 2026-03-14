class ApiConfig {
  /// Base URL de tu backend en producción
  /// Importante: sin "www" para evitar redirects en CORS (preflight)
  static const String baseUrl = 'https://todosobremiclub.com.ar';

  /// Endpoint de login de la app
  static const String appLogin = '/app/login';

  /// URL completa del login (por si la querés usar directo)
  static String get appLoginUrl => '$baseUrl$appLogin';
}