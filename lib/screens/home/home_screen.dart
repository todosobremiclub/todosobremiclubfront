import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/storage_service.dart';
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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      CarnetScreen(session: widget.session),
      NoticiasScreen(session: widget.session),
      CumplesScreen(session: widget.session),
      RecibosScreen(session: widget.session),
    ];
  }

  Future<void> _logout() async {
    await StorageService.clearSession();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Abre la URL de Instagram del club en la app / navegador
  Future<void> _openInstagram() async {
    final club = widget.session.clubObj;

    // 👇 Ajustá este nombre de propiedad si en tu modelo se llama distinto
    final rawUrl = (club.instagramUrl ?? '').toString().trim();
    if (rawUrl.isEmpty) return;

    // Si el usuario sólo cargó @usuario, armamos la URL completa
    final urlString = rawUrl.startsWith('http')
        ? rawUrl
        : 'https://www.instagram.com/${rawUrl.replaceAll('@', '')}/';

    final uri = Uri.parse(urlString);

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.session.clubObj;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      // ===========================
      //        APP BAR
      // ===========================
      appBar: AppBar(
        backgroundColor: scheme.primary,      // 🔥 Fondo primario
        foregroundColor: scheme.onPrimary,    // 🔥 Texto e iconos
        title: Text(
          club.nombre,
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          // === BOTÓN INSTAGRAM (sólo si hay URL configurada) ===
          Builder(
            builder: (context) {
              // 👇 Ajustar nombre de propiedad si fuera necesario
              final ig = (club.instagramUrl ?? '').toString().trim();
              if (ig.isEmpty) return const SizedBox.shrink();

              return IconButton(
  tooltip: 'Instagram del club',
  onPressed: _openInstagram,
  icon: Image.asset(
    'assets/icons/instagram.png',
    width: 24,
    height: 24,
    fit: BoxFit.contain,
    // 👈 SIN "color:", dejamos los colores reales del PNG
  ),
);

            },
          ),

          // === BOTÓN CERRAR SESIÓN ===
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: Icon(Icons.logout, color: scheme.onPrimary),
            onPressed: _logout,
          ),
        ],
      ),

      // ===========================
      //          BODY
      // ===========================
      body: SafeArea(
        child: _pages[_index],
      ),

      // ===========================
      //   BOTTOM NAVIGATION BAR
      // ===========================
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,

        // 🎨 Colores dinámicos según club
        backgroundColor: scheme.primary,              // Fondo primario
        selectedItemColor: scheme.onPrimary,          // Texto/Icono activo
        unselectedItemColor: scheme.onPrimary.withOpacity(0.6),

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.badge),
            label: 'Carnet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign),
            label: 'Noticias',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cake),
            label: 'Cumples',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Recibos',
          ),
        ],
      ),
    );
  }
}
