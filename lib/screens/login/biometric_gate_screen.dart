import 'package:flutter/material.dart';

import '../../core/services/biometric_service.dart';
import '../../core/services/storage_service.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

/// ✅ NUEVO: pantalla intermedia entre "hay sesión de socio guardada" y
/// HomeScreen, que solo se usa cuando el socio activó a mano "Desbloqueo
/// con huella / Face ID" (ver StorageService.getBiometricEnabled y el
/// toggle en HomeScreen). No reemplaza el login con usuario/contraseña:
/// la sesión ya está guardada en el teléfono (StorageService.saveSession),
/// esto solo la tapa hasta que el socio confirme su huella/Face ID.
///
/// Si el socio cancela o falla, la sesión NO se borra: se muestra un
/// estado de "bloqueado" con botón para reintentar, o para cerrar sesión
/// del todo (por ejemplo si no es su teléfono).
class BiometricGateScreen extends StatefulWidget {
  final AppSession session;

  const BiometricGateScreen({super.key, required this.session});

  @override
  State<BiometricGateScreen> createState() => _BiometricGateScreenState();
}

class _BiometricGateScreenState extends State<BiometricGateScreen> {
  bool _checking = true;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _intentarDesbloquear();
  }

  Future<void> _intentarDesbloquear() async {
    setState(() => _checking = true);

    final ok = await BiometricService.authenticate(
      reason: 'Confirmá tu huella o Face ID para entrar a Todo Sobre Mi Club',
    );

    if (!mounted) return;
    setState(() {
      _checking = false;
      _unlocked = ok;
    });
  }

  Future<void> _cerrarSesion() async {
    await StorageService.clearSession();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Una vez desbloqueado, se muestra la app normal: esta pantalla
    // deja de existir en el árbol (no vuelve a pedir la huella hasta el
    // próximo arranque de la app).
    if (_unlocked) {
      return HomeScreen(session: widget.session);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.fingerprint, size: 72, color: Colors.blue),
                const SizedBox(height: 20),
                Text(
                  _checking
                      ? 'Verificando identidad…'
                      : 'No se pudo confirmar tu identidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(height: 24),
                if (_checking)
                  const CircularProgressIndicator()
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _intentarDesbloquear,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _cerrarSesion,
                    child: const Text('Cerrar sesión'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
