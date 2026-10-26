// lib/screens/espacios/mis_reservas_espacios_screen.dart
//
// "Mis reservas y abonos" del socio: dos pestañas.
//  - Reservas: estado de cada pedido, mensaje del club y cancelación
//    (el backend informa si todavía se puede cancelar: puede_cancelar).
//  - Abonos: turnos fijos semanales del socio (solo lectura; los gestiona el club).
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/espacios_service.dart';
import 'espacios_utils.dart';

class MisReservasEspaciosScreen extends StatelessWidget {
  final AppSession session;

  const MisReservasEspaciosScreen({super.key, required this.session});

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
          title: const Text('Mis reservas'),
          bottom: TabBar(
            labelColor: scheme.onPrimary,
            unselectedLabelColor: scheme.onPrimary.withOpacity(0.7),
            indicatorColor: scheme.onPrimary,
            tabs: const [Tab(text: 'Reservas'), Tab(text: 'Abonos')],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _ReservasTab(session: session),
              _AbonosTab(session: session),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Reservas
// ---------------------------------------------------------------------
class _ReservasTab extends StatefulWidget {
  final AppSession session;
  const _ReservasTab({required this.session});

  @override
  State<_ReservasTab> createState() => _ReservasTabState();
}

class _ReservasTabState extends State<_ReservasTab> with AutomaticKeepAliveClientMixin {
  final _service = EspaciosService();
  late Future<List<Map<String, dynamic>>> _future;
  String? _cancelando;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => _service.getMisReservas(token: widget.session.token);

  Future<void> _refrescar() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  Future<void> _cancelar(Map<String, dynamic> r) async {
    final id = (r['id'] ?? '').toString();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text(
          '¿Cancelar ${r['recurso_nombre']} el ${fechaLarga(r['fecha']?.toString())} a las ${r['hora_desde']}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, cancelar')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _cancelando = id);
    try {
      await _service.cancelarReserva(token: widget.session.token, id: id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserva cancelada')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeError(e))));
    } finally {
      if (mounted) {
        setState(() => _cancelando = null);
        _refrescar();
      }
    }
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
            return ListView(children: const [
              SizedBox(height: 80),
              EstadoVacio(icon: Icons.event_available, texto: 'Todavía no hiciste reservas de espacios.'),
            ]);
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: lista.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) => _tarjeta(lista[i]),
          );
        },
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> r) {
    final est = estadoReserva((r['estado'] ?? '').toString());
    final id = (r['id'] ?? '').toString();
    final msg = (r['mensaje_admin'] ?? '').toString().trim();
    final com = (r['comentario'] ?? '').toString().trim();
    final puedeCancelar = r['puede_cancelar'] == true;
    final activa = r['estado'] == 'pendiente' || r['estado'] == 'aceptada';
    // Si el socio figura como participante (no es el titular), no puede cancelar.
    final esParticipante = r['rol'] == 'participante';
    final titular = (r['titular'] ?? '').toString().trim();
    final participantes = List<String>.from(((r['participantes'] ?? []) as List).map((x) => x.toString()));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  (r['recurso_nombre'] ?? '').toString(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: est.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(est.label,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: est.color)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${fechaLarga(r['fecha']?.toString())} · ${r['hora_desde']} a ${r['hora_hasta']}',
            style: const TextStyle(color: Colors.black87),
          ),
          if (esParticipante && titular.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Reserva de $titular (vas como participante)',
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ] else if (participantes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Van con vos: ${participantes.join(', ')}',
                style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
          if (com.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Tu comentario: $com', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
          if (msg.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Mensaje del club: $msg', style: const TextStyle(fontSize: 13, color: Colors.black87)),
          ],
          if (activa && !esParticipante) ...[
            const SizedBox(height: 10),
            if (puedeCancelar)
              OutlinedButton.icon(
                onPressed: _cancelando == id ? null : () => _cancelar(r),
                icon: _cancelando == id
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.close, size: 18),
                label: const Text('Cancelar reserva'),
              )
            else if (r['estado'] == 'aceptada' && r['cancelar_hasta_horas'] != null)
              Text(
                'Ya no se puede cancelar desde la app (hasta ${r['cancelar_hasta_horas']} h antes). Si no vas a poder asistir, avisale al club.',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Abonos
// ---------------------------------------------------------------------
class _AbonosTab extends StatefulWidget {
  final AppSession session;
  const _AbonosTab({required this.session});

  @override
  State<_AbonosTab> createState() => _AbonosTabState();
}

class _AbonosTabState extends State<_AbonosTab> with AutomaticKeepAliveClientMixin {
  final _service = EspaciosService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() => _service.getMisAbonos(token: widget.session.token);

  Future<void> _refrescar() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {}
  }

  String _rangoLiberada(Map<String, dynamic> e) {
    final d = e['fecha_desde']?.toString();
    final h = e['fecha_hasta']?.toString();
    final base = (h == null || h == d) ? fechaCorta(d) : '${fechaCorta(d)} al ${fechaCorta(h)}';
    final motivo = (e['motivo'] ?? '').toString().trim();
    return motivo.isEmpty ? base : '$base ($motivo)';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scheme = Theme.of(context).colorScheme;
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
            return ListView(children: const [
              SizedBox(height: 80),
              EstadoVacio(
                icon: Icons.repeat,
                texto: 'No tenés abonos. Un abono es un turno fijo todas las semanas; se contrata en el club.',
              ),
            ]);
          }
          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: lista.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == lista.length) {
                return const Text(
                  'Para liberar una fecha o dar de baja un abono, comunicate con el club.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                );
              }
              final a = lista[i];
              final liberadas = List<Map<String, dynamic>>.from((a['fechas_liberadas'] ?? []) as List);
              final dia = int.tryParse((a['dia_semana'] ?? '').toString()) ?? 0;
              final esParticipante = a['rol'] == 'participante';
              final titular = (a['titular'] ?? '').toString().trim();
              final participantes = List<String>.from(((a['participantes'] ?? []) as List).map((x) => x.toString()));
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black12),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.repeat, color: scheme.primary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (a['recurso_nombre'] ?? '').toString(),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Todos los ${diaLargo(dia).toLowerCase()} · ${a['hora_desde']} a ${a['hora_hasta']}',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    if (esParticipante && titular.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Abono de $titular (vas como participante)',
                          style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ] else if (participantes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Van con vos: ${participantes.join(', ')}',
                          style: const TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      a['proxima_fecha'] != null
                          ? 'Próximo turno: ${fechaLarga(a['proxima_fecha']?.toString())}'
                          : 'Sin próximos turnos',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    Text(
                      a['vigente_hasta'] != null
                          ? 'Vigente hasta el ${fechaDMY(a['vigente_hasta']?.toString())}'
                          : 'Vigente desde el ${fechaDMY(a['vigente_desde']?.toString())}, sin fecha de fin',
                      style: const TextStyle(fontSize: 13, color: Colors.black54),
                    ),
                    if (liberadas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Fechas liberadas', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ...liberadas.map((e) => Text('• ${_rangoLiberada(e)}',
                          style: const TextStyle(fontSize: 12, color: Colors.black54))),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
