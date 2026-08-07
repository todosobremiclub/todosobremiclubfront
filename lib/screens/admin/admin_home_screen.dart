import 'package:flutter/material.dart';

import '../../core/services/storage_service.dart';
import '../../core/config/app_theme.dart';
import '../../models/club.dart';
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
import 'agenda_screen.dart';
import 'pendientes_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  AdminSession? _session;
  bool _loading = true;
  String? _logoUrl;
  Club? _club;

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
        setState(() {
          _logoUrl = club['logo_url']?.toString();
          _club = Club.fromJson(club);
        });
      } catch (_) {
        // Si falla, seguimos con el color por defecto, no bloqueamos la pantalla
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
  // profesor            -> noticias, notificaciones, buscar socio, asistencia
  // asistencias         -> registrar asistencias
  // ======================================================
  bool _puede(List<String> rolesPermitidos) {
    if (_session == null) return false;
    if (_session!.role == 'superadmin') return true;
    return rolesPermitidos.contains(_session!.role);
  }

  static const Map<String, String> _roleLabels = {
    'admin': 'Administrador',
    'superadmin': 'Super administrador',
    'finanzas': 'Finanzas',
    'comunicacion': 'Comunicación',
    'profesor': 'Profesor',
    'asistencias': 'Asistencias',
    'solo_lectura': 'Solo lectura',
  };

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

    // ✅ Tema con el color real del club (o el default si todavía no cargó)
    final theme = _club != null ? AppTheme.fromClub(_club!) : Theme.of(context);

    return Theme(
      data: theme,
      child: _buildBody(context, token, clubId, theme),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String token,
    String clubId,
    ThemeData theme,
  ) {
    // 🔒 solo_lectura no tiene acceso a ninguna acción de la app
    if (_session!.role == 'solo_lectura') {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(theme),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Tu rol (solo lectura) no tiene acciones habilitadas en la app.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
    }

    final secciones = <_Seccion>[
      _Seccion(
        titulo: 'Finanzas',
        color: Colors.teal,
        acciones: [
          _AccionAdmin(
            titulo: 'Registrar pago de cuota',
            icono: Icons.payments_outlined,
            visible: _puede(['admin', 'finanzas']),
            onTap: () => _abrir(PagoFormScreen(token: token, clubId: clubId)),
          ),
          _AccionAdmin(
            titulo: 'Registrar ingreso',
            icono: Icons.point_of_sale_outlined,
            visible: _puede(['admin']),
            onTap: () => _abrir(IngresoFormScreen(token: token, clubId: clubId)),
          ),
          _AccionAdmin(
            titulo: 'Registrar gasto',
            icono: Icons.receipt_long_outlined,
            visible: _puede(['admin', 'finanzas']),
            onTap: () => _abrir(GastoFormScreen(token: token, clubId: clubId)),
          ),
        ],
      ),
_Seccion(
        titulo: 'Socios',
        color: Colors.indigo,
        acciones: [
          _AccionAdmin(
            titulo: 'Cargar nuevo socio',
            icono: Icons.person_add_alt_1_outlined,
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
            titulo: 'Pendientes',
            icono: Icons.pending_actions_outlined,
            visible: _puede(['admin']),
            onTap: () => _abrir(PendientesScreen(token: token, clubId: clubId)),
          ),
        ],
      ),

_Seccion(
        titulo: 'Comunicación',
        color: Colors.deepPurple,
        acciones: [
          _AccionAdmin(
            titulo: 'Publicar noticia',
            icono: Icons.campaign_outlined,
            visible: _puede(['admin', 'comunicacion', 'profesor']),
            onTap: () => _abrir(NoticiaFormScreen(token: token, clubId: clubId)),
          ),
          _AccionAdmin(
            titulo: 'Enviar notificación',
            icono: Icons.notifications_active_outlined,
            visible: _puede(['admin', 'comunicacion', 'profesor']),
            onTap: () => _abrir(NotificacionFormScreen(token: token, clubId: clubId)),
          ),
          _AccionAdmin(
            titulo: 'Agenda',
            icono: Icons.event_outlined,
            visible: _puede(['admin', 'comunicacion']),
            onTap: () => _abrir(AgendaScreen(token: token, clubId: clubId)),
          ),
        ],
      ),
      _Seccion(
        titulo: 'Actividad',
        color: Colors.deepOrange,
        acciones: [
          _AccionAdmin(
            titulo: 'Registrar asistencia',
            icono: Icons.fact_check_outlined,
            visible: _puede(['admin', 'asistencias', 'profesor']),
            onTap: () => _abrir(AsistenciaFormScreen(token: token, clubId: clubId)),
          ),
          _AccionAdmin(
            titulo: 'Control de acceso',
            icono: Icons.qr_code_scanner,
            visible: _puede(['admin']),
            onTap: () => _abrir(const ControlAccesoScreen()),
          ),
        ],
      ),
    ];

    // Nos quedamos solo con las secciones que tengan al menos 1 acción visible
    final seccionesVisibles = secciones
        .map((s) => _Seccion(
              titulo: s.titulo,
              color: s.color,
              acciones: s.acciones.where((a) => a.visible).toList(),
            ))
        .where((s) => s.acciones.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: _buildAppBar(theme),
      body: seccionesVisibles.isEmpty
          ? const Center(
              child: Text(
                'Tu rol no tiene acciones habilitadas.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
              children: [
                _buildSesionCard(theme),
                const SizedBox(height: 14),
                for (final seccion in seccionesVisibles) ...[
                  _buildTituloSeccion(seccion.titulo, seccion.color),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.25,
                    children: seccion.acciones
                        .map((a) => _BotonAccion(accion: a, colorSeccion: seccion.color))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      title: Row(
        children: [
          if (_logoUrl != null && _logoUrl!.isNotEmpty) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white,
              backgroundImage: NetworkImage(_logoUrl!),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              _session!.clubName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _logout,
          icon: Icon(Icons.logout, color: theme.colorScheme.onPrimary),
          tooltip: 'Cerrar sesión',
        ),
      ],
    );
  }

  Widget _buildSesionCard(ThemeData theme) {
    final roleLabel = _roleLabels[_session!.role] ?? _session!.role;
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_outline, color: primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _session!.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  roleLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTituloSeccion(String titulo, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _Seccion {
  final String titulo;
  final Color color;
  final List<_AccionAdmin> acciones;

  _Seccion({
    required this.titulo,
    required this.color,
    required this.acciones,
  });
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
  final Color colorSeccion;

  const _BotonAccion({required this.accion, required this.colorSeccion});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: accion.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colorSeccion.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(accion.icono, size: 19, color: colorSeccion),
              ),
              const SizedBox(height: 6),
              Text(
                accion.titulo,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}