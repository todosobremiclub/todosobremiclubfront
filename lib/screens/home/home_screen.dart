import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/storage_service.dart';
import '../../core/services/notification_store.dart';

import '../login/login_screen.dart';
import '../carnet/carnet_screen.dart';
import '../noticias/noticias_screen.dart';
import '../cumples/cumples_screen.dart';
import '../recibos/recibos_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSession session;

  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  int _noticiasBadgeCount = 0;
  int _cumplesBadgeCount = 0;

  @override
  void initState() {
    super.initState();

    NotificationStore.instance.addListener(_onNotificationsChanged);
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
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 12),
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
            icon: Image.asset('assets/icons/instagram.png', width: 24),
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
        ],
      ),
    );
  }
}