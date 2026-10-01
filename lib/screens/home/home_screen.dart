import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/storage_service.dart';
import '../../core/services/notification_store.dart';
import '../../services/socio_service.dart'; // ✅ NUEVO: "Cambiar de socio"

import '../login/login_screen.dart';
import '../carnet/carnet_screen.dart';
import '../noticias/noticias_screen.dart';
import '../cumples/cumples_screen.dart';
import '../recibos/recibos_screen.dart';
import '../mas/mas_screen.dart'; // ✅ NUEVO: menú "Más" (aloja Tienda y futuras secciones)


class HomeScreen extends StatefulWidget {
  final AppSession session;

  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  int _noticiasBadgeCount = 0;
  int _cumplesBadgeCount = 0;

  // ✅ NUEVO: "Cambiar de socio" (Grupo Familiar + relación manual). Se
  // carga una sola vez al entrar; si viene vacía, el botón ni se muestra.
  final SocioService _socioService = SocioService();
  List<Map<String, dynamic>> _sociosRelacionados = [];
  bool _cambiandoSocio = false;

@override
  void initState() {
    super.initState();

    NotificationStore.instance.addListener(_onNotificationsChanged);
    WidgetsBinding.instance.addObserver(this); // ✅ NUEVO: auto-logout 8hs
    _cargarSociosRelacionados();
  }

  Future<void> _cargarSociosRelacionados() async {
    try {
      final socios = await _socioService.getSociosRelacionados(
        token: widget.session.token,
      );
      if (!mounted) return;
      setState(() => _sociosRelacionados = socios);
    } catch (e) {
      // Silencioso: si falla, simplemente no se muestra el selector. No es
      // una función crítica como para interrumpir al socio con un error.
      debugPrint('No se pudieron cargar los socios relacionados: $e');
    }
  }

  Future<void> _cambiarASocio(Map<String, dynamic> socio) async {
    if (_cambiandoSocio) return;
    setState(() => _cambiandoSocio = true);

    try {
      final data = await _socioService.cambiarSocio(
        token: widget.session.token,
        socioId: socio['id'].toString(),
      );

      await StorageService.saveSession(
        token: data['token'],
        socio: Map<String, dynamic>.from(data['socio']),
        club: Map<String, dynamic>.from(data['club']),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // cierra el bottom sheet

      final nuevaSesion = AppSession(
        token: data['token'],
        socio: Map<String, dynamic>.from(data['socio']),
        club: Map<String, dynamic>.from(data['club']),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(session: nuevaSesion)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar de socio: $e')),
      );
    } finally {
      if (mounted) setState(() => _cambiandoSocio = false);
    }
  }

  void _abrirSelectorSocios() {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.switch_account, color: scheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Cambiar de socio',
                        style: TextStyle(
                          color: scheme.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ..._sociosRelacionados.map(
                  (s) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: scheme.primary.withOpacity(0.1),
                      backgroundImage: (s['foto_url'] ?? '').toString().isNotEmpty
                          ? NetworkImage(s['foto_url'].toString())
                          : null,
                      child: (s['foto_url'] ?? '').toString().isEmpty
                          ? Icon(Icons.person, color: scheme.primary)
                          : null,
                    ),
                    title: Text('${s['apellido'] ?? ''} ${s['nombre'] ?? ''}'.trim()),
                    subtitle: Text('N° ${s['numero'] ?? ''}'),
                    trailing: _cambiandoSocio
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _cambiandoSocio ? null : () => _cambiarASocio(s),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ NUEVO: chequea expiración de sesión cada vez que la app vuelve
  // a foreground (por ej. el usuario la minimizó y la reabre horas después).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkSessionExpiry();
    }
  }

  Future<void> _checkSessionExpiry() async {
    final expirada = await StorageService.isSessionExpired();
    if (expirada && mounted) {
      await _logout();
    }
  }

  void _onNotificationsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _actualizarBadgeNoticias(int count) {
    if (!mounted) return;
    setState(() => _noticiasBadgeCount = count);
  }

  void _actualizarBadgeCumples(int count) {
    if (!mounted) return;
    setState(() => _cumplesBadgeCount = count);
  }

  Future<void> _logout() async {
    await StorageService.clearSession();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openInstagram() async {
    final club = widget.session.clubObj;
    final rawUrl = (club.instagramUrl ?? '').toString().trim();

    if (rawUrl.isEmpty) return;

    final urlString = rawUrl.startsWith('http')
        ? rawUrl
        : 'https://www.instagram.com/${rawUrl.replaceAll('@', '')}/';

    final uri = Uri.parse(urlString);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  int get _notificacionesNuevasTotal =>
      NotificationStore.instance.noLeidas;

  Widget _buildNavIconBadge({
    required IconData icon,
    required int count,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -10,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.primary, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionIconBadge({
    required Widget child,
    required int count,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        if (count > 0)
          Positioned(
            right: -4,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white, width: 1.2),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _abrirNotificaciones() {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            final nuevas = NotificationStore.instance.all
                .where((n) => !n.leida)
                .toList();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications, color: scheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Notificaciones',
                            style: TextStyle(
                              color: scheme.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (nuevas.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              nuevas.length > 99
                                  ? '99+'
                                  : '${nuevas.length}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (nuevas.isEmpty)
                      const Text('No tenés notificaciones nuevas')
                    else
                      ...nuevas.map(
                        (n) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.notifications_active,
                            color: scheme.primary,
                          ),
                          title: Text(n.titulo),
                          subtitle: Text(n.mensaje),
                          onTap: () async {
                            await NotificationStore.instance.marcarLeida(n);
                            setStateModal(() {});
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

@override
  void dispose() {
    NotificationStore.instance.removeListener(_onNotificationsChanged);
    WidgetsBinding.instance.removeObserver(this); // ✅ NUEVO
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.session.clubObj;
    final scheme = Theme.of(context).colorScheme;

    // 🔥 CLAVE: reconstruimos páginas en cada build
    final pages = [
      CarnetScreen(session: widget.session),

      // 👇 ESTE FIX RESUELVE TU PROBLEMA
      NoticiasScreen(
        key: ValueKey(_noticiasBadgeCount),
        session: widget.session,
        onUnreadCountChanged: _actualizarBadgeNoticias,
      ),

      CumplesScreen(
        session: widget.session,
        onHoyCountChanged: _actualizarBadgeCumples,
      ),

      RecibosScreen(session: widget.session),

      // ✅ NUEVO: "Más" — aloja Tienda (si el club la tiene habilitada) y
      // futuras secciones secundarias.
      MasScreen(session: widget.session),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),
            _HomeClubLogo(logoUrl: club.logoUrl),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                club.nombre,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _openInstagram,
            tooltip: 'Instagram',
            icon: Container(
              width: 30,
              height: 30,
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/icons/instagram.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          IconButton(
            onPressed: _abrirNotificaciones,
            icon: _buildActionIconBadge(
              count: _notificacionesNuevasTotal,
              child: Icon(
                Icons.notifications_none,
                color: scheme.onPrimary,
              ),
            ),
          ),
          // ✅ NUEVO: "Cambiar de socio" — solo se muestra si el socio
          // logueado tiene Grupo Familiar o relación manual configurada.
          if (_sociosRelacionados.isNotEmpty)
            IconButton(
              onPressed: _abrirSelectorSocios,
              tooltip: 'Cambiar de socio',
              icon: Icon(Icons.switch_account, color: scheme.onPrimary),
            ),
          IconButton(
            onPressed: _logout,
            icon: Icon(Icons.logout, color: scheme.onPrimary),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _index,
          children: pages,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: scheme.primary,
        selectedItemColor: scheme.onPrimary,
        unselectedItemColor: scheme.onPrimary.withOpacity(0.6),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.badge),
            label: 'Carnet',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIconBadge(
              icon: Icons.campaign,
              count: _noticiasBadgeCount,
            ),
            label: 'Noticias',
          ),
          BottomNavigationBarItem(
            icon: _buildNavIconBadge(
              icon: Icons.cake,
              count: _cumplesBadgeCount,
            ),
            label: 'Cumples',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Recibos',
          ),
          // ✅ NUEVO
          const BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'Más',
          ),
        ],
      ),
    );
  }
}

class _HomeClubLogo extends StatelessWidget {
  final String? logoUrl;

  const _HomeClubLogo({required this.logoUrl});

  @override
  Widget build(BuildContext context) {
    final hasLogo = (logoUrl ?? '').trim().isNotEmpty;

    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(4),
      child: ClipOval(
        child: hasLogo
            ? Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield_outlined, size: 16, color: Colors.black45),
              )
            : const Icon(Icons.shield_outlined, size: 16, color: Colors.black45),
      ),
    );
  }
}