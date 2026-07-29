import 'package:flutter/material.dart';

import '../../core/services/storage_service.dart';
import '../../services/admin_api_service.dart';
import '../login/login_screen.dart';
import 'control_acceso_screen.dart';
import 'notificacion_form_screen.dart';
import 'noticia_form_screen.dart';
import 'pago_form_screen.dart';
import 'socio_form_screen.dart';
import 'asistencia_form_screen.dart';
import 'ingreso_form_screen.dart';
import 'gasto_form_screen.dart';
import 'buscar_socio_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  AdminSession? _session;
  bool _loading = true;
  String? _logoUrl;

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

    if (session != null) {
      try {
        final club = await AdminApiService.getClub(
          token: session.token,
          clubId: session.clubId,
        );
        if (!mounted) return;
        setState(() => _logoUrl = club['logo_url']?.toString());
      } catch (_) {
        // Si falla, seguimos sin logo, no bloqueamos la pantalla
      }
    }
  }

  Future<void> _logout() async {
    await StorageService.clearAdminSession();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _abrir(Widget pantalla) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => pantalla),
    );
  }

  // ======================================================
  // Reglas de visibilidad por rol (user_clubs.role):
  // admin / superadmin -> todo
  // solo_lectura        -> sin acceso a la app
  // finanzas            -> pagos, ingresos, gastos
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

    final token = _session!.token;
    final clubId = _session!.clubId;

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
        onTap: () => _abrir(PagoFormScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Registrar ingreso',
        icono: Icons.point_of_sale,
        visible: _puede(['admin', 'finanzas']),
        onTap: () => _abrir(IngresoFormScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Registrar gasto',
        icono: Icons.receipt_long,
        visible: _puede(['admin', 'finanzas']),
        onTap: () => _abrir(GastoFormScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Cargar nuevo socio',
        icono: Icons.person_add,
        visible: _puede(['admin']),
        onTap: () => _abrir(SocioFormScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Buscar socio',
        icono: Icons.search,
        visible: _puede(['admin', 'profesor']),
        onTap: () => _abrir(BuscarSocioScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Publicar noticia',
        icono: Icons.campaign,
        visible: _puede(['admin', 'comunicacion', 'profesor']),
        onTap: () => _abrir(NoticiaFormScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Enviar notificación',
        icono: Icons.notifications_active,
        visible: _puede(['admin', 'comunicacion', 'profesor']),
        onTap: () => _abrir(NotificacionFormScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Registrar asistencia',
        icono: Icons.fact_check,
        visible: _puede(['admin', 'asistencias']),
        onTap: () => _abrir(AsistenciaFormScreen(token: token, clubId: clubId)),
      ),
      _AccionAdmin(
        titulo: 'Control de acceso',
        icono: Icons.qr_code_scanner,
        visible: _puede(['admin']),
        onTap: () => _abrir(const ControlAccesoScreen()),
      ),
    ].where((a) => a.visible).toList();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_logoUrl != null && _logoUrl!.isNotEmpty) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white,
                backgroundImage: NetworkImage(_logoUrl!),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(_session!.clubName, overflow: TextOverflow.ellipsis)),
          ],
        ),
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