// lib/screens/mas/mas_screen.dart
//
// Pantalla del ítem "Más" del bottom nav — aloja las secciones secundarias:
//  - "Tienda" (si el club la tiene habilitada).
//  - "Reservar un recurso" y "Mis reservas y abonos" (si el club tiene el
//    módulo Recursos habilitado).
//  - "Mis clases / entrenamientos" (solo si el socio tiene al menos una clase
//    asignada desde la Agenda).
// Si no hay ninguna sección disponible, muestra un estado vacío.
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/clases_service.dart';
import '../clases/mis_clases_screen.dart';
import '../espacios/espacios_screen.dart';
import '../espacios/mis_reservas_espacios_screen.dart';
import '../tienda/tienda_screen.dart';

class MasScreen extends StatefulWidget {
  final AppSession session;

  const MasScreen({super.key, required this.session});

  @override
  State<MasScreen> createState() => _MasScreenState();
}

class _MasScreenState extends State<MasScreen> {
  AppSession get session => widget.session;

  // Se activa cuando el socio tiene al menos una clase asignada; si falla la consulta, el ítem no aparece.
  bool _tieneClases = false;

  @override
  void initState() {
    super.initState();
    _cargarClases();
  }

  Future<void> _cargarClases() async {
    try {
      final clases = await ClasesService().getMisClases(token: session.token);
      if (!mounted) return;
      setState(() => _tieneClases = clases.isNotEmpty);
    } catch (_) {
      // Sin conexión o backend sin actualizar: no mostramos el ítem.
    }
  }

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
      if (club.espaciosHabilitado) ...[
        _MasItem(
          icon: Icons.stadium,
          titulo: 'Reservar un recurso',
          subtitulo: 'Canchas, salones y espacios del club',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EspaciosScreen(session: session),
              ),
            );
          },
        ),
        _MasItem(
          icon: Icons.event_note,
          titulo: 'Mis reservas y abonos',
          subtitulo: 'Tus turnos y abonos fijos, propios o compartidos',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MisReservasEspaciosScreen(session: session),
              ),
            );
          },
        ),
      ],
      if (_tieneClases)
        _MasItem(
          icon: Icons.school,
          titulo: 'Mis clases / entrenamientos',
          subtitulo: 'Tus días y horarios',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MisClasesScreen(session: session),
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
