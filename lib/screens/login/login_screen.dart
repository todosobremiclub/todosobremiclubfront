import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../app.dart'; // 👈 para volver a MyApp después del login

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _numeroController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();

  final AuthService _authService = AuthService();
  bool _loading = false;

  Future<void> _login() async {
    // Ahora los usamos como usuario/contraseña
    final usuario = _numeroController.text.trim();
    final contrasena = _dniController.text.trim();

    if (usuario.isEmpty || contrasena.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá usuario y contraseña')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // El backend sigue esperando numeroSocio y dni, no lo tocamos
      final data = await _authService.login(
        numeroSocio: usuario,
        dni: contrasena,
      );

      final token = data['token'] as String?;
      final socio = data['socio'] as Map<String, dynamic>?;
      final club = data['club'] as Map<String, dynamic>?;

      if (token == null || socio == null || club == null) {
        throw Exception(
          'Respuesta inválida del servidor (faltan token/socio/club)',
        );
      }

      // 1️⃣ Guardamos la sesión
      await StorageService.saveSession(
        token: token,
        socio: socio,
        club: club,
      );

      // 2️⃣ (Opcional) volvemos a cargarla para validar que quedó bien
      final session = await StorageService.loadSession();
      if (session == null) {
        throw Exception('No se pudo recuperar la sesión después del login');
      }

      if (!mounted) return;

      // 3️⃣ En lugar de ir directo a HomeScreen,
      //     volvemos a arrancar MyApp para que aplique AppTheme.fromClub
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MyApp(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo verde oscuro
      backgroundColor: const Color(0xFF004225),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset(
                  'assets/img/logo-tsmc.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),

                // Título
                const Text(
                  'Todo Sobre Mi Club',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // Campo USUARIO (teclado numérico, pero mantiene label "Usuario")
                TextField(
                  controller: _numeroController,
                  keyboardType: TextInputType.number, // ✅ teclado numérico
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // ✅ solo números
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Usuario',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.person, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo CONTRASEÑA (teclado numérico, oculto, mantiene label "Contraseña")
                TextField(
                  controller: _dniController,
                  keyboardType: TextInputType.number, // ✅ teclado numérico
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // ✅ solo números
                  ],
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white54),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                  ),
                ),
                const SizedBox(height: 30),

                // Botón azul con letras blancas
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Ingresar'),
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
