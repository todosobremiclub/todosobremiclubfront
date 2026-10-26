// lib/screens/clases/mis_clases_screen.dart
//
// "Mis clases / entrenamientos": las clases que el club le asignó al socio
// desde la Agenda, con sus días, horarios y próximas fechas.
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/clases_service.dart';
import '../espacios/espacios_utils.dart';

class MisClasesScreen extends StatefulWidget {
  final AppSession session;

  const MisClasesScreen({super.key, required this.session});

  @override
  State<MisClasesScreen> createState() => _MisClasesScreenState();
}

class _MisClasesScreenState extends State<MisClasesScreen> {
  final _service = ClasesService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getMisClases(token: widget.session.token);
  }

  Future<void> _refrescar() async {
    setState(() => _future = _service.getMisClases(token: widget.session.token));
    try {
      await _future;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: const Text('Mis clases / entrenamientos'),
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
                    icon: Icons.school_outlined,
                    texto: 'No tenés clases ni entrenamientos asignados por ahora.',
                  ),
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
        ),
      ),
    );
  }

  Widget _tarjeta(Map<String, dynamic> c) {
    final scheme = Theme.of(context).colorScheme;
    final titulo = (c['titulo'] ?? 'Clase').toString();
    final desc = (c['descripcion'] ?? '').toString().trim();
    final frecuencia = (c['frecuencia_texto'] ?? '').toString().trim();
    final desde = (c['hora_desde'] ?? '').toString();
    final hasta = (c['hora_hasta'] ?? '').toString();
    final proximas = List<Map<String, dynamic>>.from((c['proximas'] ?? []) as List);

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: scheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          ],
          const SizedBox(height: 12),
          if (frecuencia.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.event_repeat, size: 18, color: Colors.black45),
                const SizedBox(width: 8),
                Expanded(child: Text(frecuencia, style: const TextStyle(fontSize: 14))),
              ],
            ),
          if (desde.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: Colors.black45),
                const SizedBox(width: 8),
                Text(
                  hasta.isNotEmpty ? '$desde a $hasta hs' : '$desde hs',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
          if (proximas.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Próximas fechas',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in proximas)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      fechaCorta(p['fecha']?.toString()),
                      style: TextStyle(fontSize: 12.5, color: scheme.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
