import 'package:local_auth/local_auth.dart';

/// ✅ NUEVO: wrapper fino sobre local_auth.
/// No maneja nada de sesión ni de credenciales — eso sigue siendo trabajo
/// de StorageService. Esta clase solo sabe pedir huella/Face ID y devolver
/// true/false. La usan HomeScreen (para activar el toggle) y
/// BiometricGateScreen (para pedir el desbloqueo al abrir la app).
class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// true si el dispositivo soporta biometría Y tiene algo configurado
  /// (huella/rostro cargado en el sistema operativo).
  static Future<bool> isAvailable() async {
    try {
      final puedeChequear = await _auth.canCheckBiometrics;
      final soportado = await _auth.isDeviceSupported();
      return puedeChequear && soportado;
    } catch (_) {
      return false;
    }
  }

  /// Pide la autenticación biométrica nativa del teléfono. Devuelve true
  /// solo si el socio se autenticó correctamente.
  ///
  /// `biometricOnly: false` deja que el sistema ofrezca el PIN/patrón del
  /// teléfono como respaldo si la huella falla varias veces o no está
  /// disponible en ese momento — evita dejar a alguien sin poder entrar
  /// a la app por un problema puntual del sensor.
  static Future<bool> authenticate({
    String reason = 'Confirmá tu identidad para continuar',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
