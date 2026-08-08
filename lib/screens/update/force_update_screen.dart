import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla bloqueante: se muestra en vez de la app normal cuando
/// el build instalado quedó por debajo del mínimo permitido
/// (ver GET /app/config en el backend y la lógica en app.dart).
///
/// No tiene forma de cerrarse ni saltear: es el "home" del MaterialApp
/// mientras la condición de bloqueo esté activa.
class ForceUpdateScreen extends StatelessWidget {
  final String storeUrl;

  const ForceUpdateScreen({super.key, required this.storeUrl});

  Future<void> _abrirStore() async {
    final uri = Uri.tryParse(storeUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.system_update_rounded,
                  size: 72,
                  color: Colors.black87,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Hay una nueva versión disponible',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Para seguir usando la app necesitás actualizar a la '
                  'última versión disponible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _abrirStore,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Actualizar ahora',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}