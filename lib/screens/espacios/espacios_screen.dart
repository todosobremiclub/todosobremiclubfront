// lib/screens/espacios/espacios_screen.dart
//
// Lista de espacios reservables del club (canchas, salones, etc.).
// Al tocar uno se abre TurnosScreen para elegir día y horario.
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/espacios_service.dart';
import 'espacios_utils.dart';
import 'mis_reservas_espacios_screen.dart';
import 'turnos_screen.dart';

class EspaciosScreen extends StatefulWidget {
  final AppSession session;

  const EspaciosScreen({super.key, required this.session});

  @override
  State<EspaciosScreen> createState() => _EspaciosScreenState();
}

class _EspaciosScreenState extends State<EspaciosScreen> {
  final _service = EspaciosService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => _service.getRecursos(token: widget.session.token);

  Future<void> _refrescar() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  IconData _icono(String? tipo) {
    switch (tipo) {
      case 'cancha':
        return Icons.sports_soccer;
      case 'salon':
        return Icons.meeting_room;
      case 'espacio':
        return Icons.stadium;
      default:
        return Icons.place;
    }
  }

  String _fmtDuracion(dynamic min) {
    final m = int.tryParse((min ?? '').toString());
    if (m == null) return '';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '$h h' : '$h h $r min';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: const Text('Reservar un espacio'),
        actions: [
          IconButton(
            tooltip: 'Mis reservas y abonos',
            icon: const Icon(Icons.event_note),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MisReservasEspaciosScreen(session: widget.session)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refrescar,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return ListView(
                  children: [
                    const SizedBox(height: 80),
                    EstadoError(mensaje: mensajeError(snap.error!), onReintentar: _refrescar),
                  ],
                );
              }
              final recursos = snap.data ?? [];
              if (recursos.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    EstadoVacio(
                      icon: Icons.stadium_outlined,
                      texto: 'Por ahora el club no tiene espacios disponibles para reservar desde la app.',
                    ),
                  ],
                );
              }
              return ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: recursos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = recursos[i];
                  final img = (r['imagen_url'] ?? '').toString();
                  final dur = _fmtDuracion(r['duracion_turno_min']);
                  final cap = r['capacidad'];
                  final desc = (r['descripcion'] ?? '').toString().trim();
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TurnosScreen(session: widget.session, recurso: r),
                          ),
                        );
                      },
                      child: Container(
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
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (img.isNotEmpty)
                              Image.network(
                                img,
                                height: 150,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: scheme.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_icono(r['tipo']?.toString()), color: scheme.primary),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (r['nombre'] ?? '').toString(),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          [
                                            if (dur.isNotEmpty) 'Turnos de $dur',
                                            if (cap != null) 'Hasta $cap personas',
                                          ].join(' · '),
                                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                                        ),
                                        if (desc.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            desc,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: Colors.black87),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.black38),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
