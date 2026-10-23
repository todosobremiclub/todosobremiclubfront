// lib/screens/espacios/clases_screen.dart
//
// Clases del club. Dos pestañas:
//  - "Mis clases": donde el socio está inscripto, con sus próximas fechas
//    (las canceladas se marcan en rojo).
//  - "Todas": todas las clases activas con horarios y cupo. Las inscripciones
//    las hace el club desde el panel.
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/espacios_service.dart';
import 'espacios_utils.dart';

class ClasesScreen extends StatelessWidget {
  final AppSession session;

  const ClasesScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          title: const Text('Clases'),
          bottom: TabBar(
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onPrimary.withOpacity(0.7),
            indicatorColor: scheme.onPrimary,
            tabs: const [Tab(text: 'Mis clases'), Tab(text: 'Todas')],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _ListaClases(session: session, mias: true),
              _ListaClases(session: session, mias: false),
            ],
          ),
        ),
      ),
    );
  }
}

class _ListaClases extends StatefulWidget {
  final AppSession session;
  final bool mias;

  const _ListaClases({required this.session, required this.mias});

  @override
  State<_ListaClases> createState() => _ListaClasesState();
}

class _ListaClasesState extends State<_ListaClases> with AutomaticKeepAliveClientMixin {
  final _service = EspaciosService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => widget.mias
      ? _service.getMisClases(token: widget.session.token)
      : _service.getClases(token: widget.session.token);

  Future<void> _refrescar() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      onRefresh: _refrescar,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              const SizedBox(height: 80),
              EstadoError(mensaje: mensajeError(snap.error!), onReintentar: _refrescar),
            ]);
          }
          final lista = snap.data ?? [];
          if (lista.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              EstadoVacio(
                icon: Icons.school_outlined,
                texto: widget.mias
                    ? 'Todavía no estás inscripto en ninguna clase. Consultá en el club para sumarte.'
                    : 'El club todavía no cargó clases.',
              ),
            ]);
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: lista.length + (widget.mias ? 0 : 1),
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == lista.length) {
                return const Text(
                  'Para inscribirte en una clase, consultá en el club.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                );
              }
              return _tarjeta(lista[i]);
            },
          );
        },
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> c) {
    final scheme = Theme.of(context).colorScheme;
    final color = colorDesdeHex(c['color']?.toString()) ?? scheme.primary;
    final profesor = (c['profesor'] ?? '').toString().trim();
    final desc = (c['descripcion'] ?? '').toString().trim();
    final recurso = (c['recurso_nombre'] ?? '').toString().trim();
    final cupo = c['cupo'];
    final inscriptos = c['inscriptos'];
    final inscripto = c['inscripto'] == true;
    final proximas = List<Map<String, dynamic>>.from((c['proximas'] ?? []) as List);

    String lugares = '';
    if (!widget.mias) {
      if (cupo != null) {
        final libres = (int.tryParse(cupo.toString()) ?? 0) - (int.tryParse((inscriptos ?? 0).toString()) ?? 0);
        lugares = libres > 0 ? 'Quedan $libres de $cupo lugares' : 'Cupo completo';
      } else {
        lugares = 'Sin límite de cupo';
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (c['nombre'] ?? '').toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                        if (!widget.mias && inscripto)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text('Inscripto',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                          ),
                      ],
                    ),
                    if (profesor.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Con $profesor', style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    ],
                    const SizedBox(height: 6),
                    Text((c['horarios_texto'] ?? '').toString(), style: const TextStyle(color: Colors.black87)),
                    if (recurso.isNotEmpty)
                      Text(recurso, style: const TextStyle(fontSize: 13, color: Colors.black54)),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                    if (lugares.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(lugares, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                    if (widget.mias && proximas.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Próximas clases', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: proximas.map((p) {
                          final cancelada = p['cancelada'] == true;
                          final motivo = (p['motivo_cancelacion'] ?? '').toString().trim();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: cancelada ? Colors.red.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${fechaCorta(p['fecha']?.toString())} ${p['hora_desde']}'
                              '${cancelada ? ' · Cancelada${motivo.isNotEmpty ? ' ($motivo)' : ''}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                color: cancelada ? Colors.red.shade800 : Colors.black87,
                                decoration: cancelada ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
