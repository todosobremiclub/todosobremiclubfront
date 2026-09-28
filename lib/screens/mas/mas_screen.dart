// lib/screens/mas/mas_screen.dart
//
// ✅ NUEVO: pantalla del ítem "Más" del bottom nav — pensada para alojar
// secciones secundarias a futuro (por ahora solo "Tienda", condicionada a
// que el club la tenga habilitada). Si el club no tiene ninguna sección
// habilitada todavía, muestra un estado vacío en vez de una lista vacía.
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../tienda/tienda_screen.dart';

class MasScreen extends StatelessWidget {
  final AppSession session;

  const MasScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final club = session.clubObj;
    final scheme = Theme.of(context).colorScheme;

    final items = <_MasItem>[
      if (club.tiendaHabilitada)
        _MasItem(
          icon: Icons.storefront,
          titulo: 'Tienda',
          subtitulo: 'Productos del club para reservar',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TiendaScreen(session: session),
              ),
            );
          },
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Más',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Por ahora no hay secciones adicionales para tu club.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: item.onTap,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.black12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(item.icon, color: scheme.primary),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.titulo,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitulo,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.black38),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MasItem {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  _MasItem({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });
}
