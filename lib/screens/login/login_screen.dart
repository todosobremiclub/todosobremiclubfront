import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/push_service.dart'; // ✅ NUEVO: FCM topic subscribe
import '../../app.dart'; // 👈 para volver a MyApp después del login
import '../admin/admin_home_screen.dart'; // ✅ NUEVO: pantalla de administración

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

  // ✅ NUEVO: toggle socio / administrador
  bool _isAdminMode = false;

  void _toggleAdminMode() {
    setState(() {
      _isAdminMode = !_isAdminMode;
      _numeroController.clear();
      _dniController.clear();
    });
  }

  Future<void> _login() async {
    if (_isAdminMode) {
      await _loginAdmin();
    } else {
      await _loginSocio();
    }
  }

  // ======================================================
  // Login SOCIO (flujo original, sin cambios de lógica)
  // ======================================================
  Future<void> _loginSocio() async {
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

      await StorageService.saveSession(
        token: token,
        socio: socio,
        club: club,
      );

      final session = await StorageService.loadSession();
      if (session == null) {
        throw Exception('No se pudo recuperar la sesión después del login');
      }

      final socioObj = session.socioObj;
      await PushService.syncTopicsForSocio(
        clubId: session.clubObj.id,
        actividad: socioObj.actividad,
        categoria: socioObj.categoria,
        anioNacimiento:
            socioObj.anioNacimiento == '—' ? null : socioObj.anioNacimiento,
        enFaltaPago: !socioObj.alDia,
      );

      if (!mounted) return;

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

  // ======================================================
  // Login ADMINISTRADOR (email + password → /auth/login)
  // ======================================================
  Future<void> _loginAdmin() async {
    final email = _numeroController.text.trim();
    final password = _dniController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá email y contraseña')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final data = await _authService.loginAdmin(
        email: email,
        password: password,
      );

      final token = data['token'] as String?;
      final user = data['user'] as Map<String, dynamic>?;

      if (token == null || user == null) {
        throw Exception('Respuesta inválida del servidor (faltan token/user)');
      }

      final roles = (user['roles'] as List?) ?? [];
      if (roles.isEmpty) {
        throw Exception('Este usuario no tiene ningún club asignado');
      }

      // Por ahora tomamos el primer rol/club (selector múltiple, a futuro)
      final primerRol = roles.first as Map<String, dynamic>;

      await StorageService.saveAdminSession(
        token: token,
        email: user['email'] ?? email,
        role: primerRol['role']?.toString() ?? '',
        clubId: primerRol['club_id']?.toString() ?? '',
        clubName: primerRol['club_name']?.toString() ?? '',
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const AdminHomeScreen(),
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
  void dispose() {
    _numeroController.dispose();
    _dniController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textMain = Colors.black87;
    const textMuted = Colors.black54;
    const borderEnabled = Colors.black38;
    const borderFocused = Colors.black87;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/img/logo-tsmc.png',
                  height: 160,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 36),

                // Campo 1: Usuario (socio) / Email (admin)
                TextField(
                  controller: _numeroController,
                  keyboardType: _isAdminMode
                      ? TextInputType.emailAddress
                      : TextInputType.number,
                  inputFormatters: _isAdminMode
                      ? []
                      : [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: textMain),
                  decoration: InputDecoration(
                    labelText: _isAdminMode ? 'Email' : 'Usuario',
                    labelStyle: const TextStyle(color: textMuted),
                    prefixIcon: Icon(
                      _isAdminMode ? Icons.email : Icons.person,
                      color: textMuted,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: borderEnabled),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: borderFocused),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo 2: Contraseña (mismo para ambos modos)
                TextField(
                  controller: _dniController,
                  keyboardType: _isAdminMode
                      ? TextInputType.text
                      : TextInputType.number,
                  inputFormatters: _isAdminMode
                      ? []
                      : [FilteringTextInputFormatter.digitsOnly],
                  obscureText: true,
                  style: const TextStyle(color: textMain),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: const TextStyle(color: textMuted),
                    prefixIcon: const Icon(Icons.lock, color: textMuted),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: borderEnabled),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: borderFocused),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.04),
                  ),
                ),
                const SizedBox(height: 30),

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
                const SizedBox(height: 16),

                // ✅ NUEVO: toggle socio / administrador
                TextButton(
                  onPressed: _loading ? null : _toggleAdminMode,
                  child: Text(
                    _isAdminMode
                        ? '¿Sos socio? Ingresá acá'
                        : '¿Sos administrador? Ingresá acá',
                    style: const TextStyle(color: Colors.blue),
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