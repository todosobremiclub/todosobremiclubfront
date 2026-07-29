import 'package:flutter/material.dart';

import '../../core/services/storage_service.dart';
import '../login/login_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  AdminSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarSesion();
  }

  Future<void> _cargarSesion() async {
    final session = await StorageService.loadAdminSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await StorageService.clearAdminSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _proximamente(String accion) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$accion: próximamente')),
    );
  }

  // ======================================================
  // Reglas de visibilidad por rol, según roles reales
  // confirmados en la base (user_clubs.role):
  //
  // admin / superadmin -> todo: pago, ingreso, gastos, noticias,
  //                        notificaciones, asistencia, buscar socio
  // solo_lectura        -> sin acceso a la app
  // finanzas            -> pagos de cuotas y gastos
  // comunicacion        -> noticias y notificaciones
  // profesor            -> noticias, notificaciones, buscar socio
  // asistencias         -> registrar asistencias
  // ======================================================
  bool _puede(List<String> rolesPermitidos) {
    if (_session == null) return false;
    if (_session!.role == 'superadmin') return true;
    return rolesPermitidos.contains(_session!.role);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _logout());
      return const Scaffold(body: SizedBox.shrink());
    }

    // 🔒 solo_lectura no tiene acceso a ninguna acción de la app
    if (_session!.role == 'solo_lectura') {
      return Scaffold(
        appBar: AppBar(
          title: Text(_session!.clubName),
          actions: [
            IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
          ],
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tu rol (solo lectura) no tiene acciones habilitadas en la app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final botones = <_AccionAdmin>[
      _AccionAdmin(
        titulo: 'Registrar pago de cuota',
        icono: Icons.payments,
        visible: _puede(['admin', 'finanzas']),
        onTap: () => _proximamente('Registrar pago de cuota'),
      ),
      _AccionAdmin(
        titulo: 'Registrar ingreso',
        icono: Icons.point_of_sale,
        visible: _puede(['admin']),
        onTap: () => _proximamente('Registrar ingreso'),
      ),
      _AccionAdmin(
        titulo: 'Registrar gasto',
        icono: Icons.receipt_long,
        visible: _puede(['admin', 'finanzas']),
        onTap: () => _proximamente('Registrar gasto'),
      ),
      _AccionAdmin(
        titulo: 'Cargar nuevo socio',
        icono: Icons.person_add,
        visible: _puede(['admin']),
        onTap: () => _proximamente('Cargar nuevo socio'),
      ),
      _AccionAdmin(
        titulo: 'Buscar socio',
        icono: Icons.search,
        visible: _puede(['admin', 'profesor']),
        onTap: () => _proximamente('Buscar socio'),
      ),
      _AccionAdmin(
        titulo: 'Publicar noticia',
        icono: Icons.campaign,
        visible: _puede(['admin', 'comunicacion', 'profesor']),
        onTap: () => _proximamente('Publicar noticia'),
      ),
      _AccionAdmin(
        titulo: 'Enviar notificación',
        icono: Icons.notifications_active,
        visible: _puede(['admin', 'comunicacion', 'profesor']),
        onTap: () => _proximamente('Enviar notificación'),
      ),
      _AccionAdmin(
        titulo: 'Registrar asistencia',
        icono: Icons.fact_check,
        visible: _puede(['admin', 'asistencias']),
        onTap: () => _proximamente('Registrar asistencia'),
      ),
    ].where((a) => a.visible).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_session!.clubName),
        actions: [
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sesión: ${_session!.email} (${_session!.role})',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: botones.isEmpty
                  ? const Center(
                      child: Text('Tu rol no tiene acciones habilitadas.'),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: botones.map((a) {
                        return _BotonAccion(accion: a);
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccionAdmin {
  final String titulo;
  final IconData icono;
  final bool visible;
  final VoidCallback onTap;

  _AccionAdmin({
    required this.titulo,
    required this.icono,
    required this.visible,
    required this.onTap,
  });
}

class _BotonAccion extends StatelessWidget {
  final _AccionAdmin accion;

  const _BotonAccion({required this.accion});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: accion.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(accion.icono, size: 36),
            const SizedBox(height: 8),
            Text(
              accion.titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}