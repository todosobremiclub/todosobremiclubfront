class ApiConfig {
  /// Base URL de tu backend en producción
  /// Importante: sin "www" para evitar redirects en CORS (preflight)
  static const String baseUrl = 'https://todosobremiclub.com.ar';

  /// Endpoint de login de la app
  static const String appLogin = '/app/login';

  /// URL completa del login (por si la querés usar directo)
  static String get appLoginUrl => '$baseUrl$appLogin';

  /// Transferencias - App Socio
  static const String transferStart = '/app/payments/transfer/start';
  static const String transferProof = '/app/payments/transfer/proof';
  static const String transferConfig = '/app/club/transferencia-config';

  /// URLs completas
  static String get transferStartUrl => '$baseUrl$transferStart';
  static String get transferProofUrl => '$baseUrl$transferProof';
  static String get transferConfigUrl => '$baseUrl$transferConfig';
}