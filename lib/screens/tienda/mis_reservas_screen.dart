// lib/screens/tienda/mis_reservas_screen.dart
//
// Historial de reservas del socio logueado (GET /app/tienda/reservas/mias).
// Muestra el estado de cada reserva y el mensaje que haya dejado el admin
// al aceptarla/rechazarla.
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/tienda_service.dart';

class MisReservasScreen extends StatefulWidget {
  final AppSession session;

  const MisReservasScreen({super.key, required this.session});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _EstadoInfo {
  final String label;
  final Color color;

  const _EstadoInfo(this.label, this.color);
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  final _service = TiendaService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return _service.getMisReservas(token: widget.session.token);
  }

  Future<void> _refrescar() async {
    setState(() => _future = _load());
    await _future;
  }

  String _formatPrecio(dynamic precio) {
    final n = num.tryParse((precio ?? '').toString());
    if (n == null) return '—';
    return '\$${n.toStringAsFixed(2)}';
  }

  String _formatFecha(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  _EstadoInfo _estadoInfo(String estado) {
    switch (estado) {
      case 'pendiente':
        return const _EstadoInfo('Pendiente', Colors.orange);
      case 'aceptada':
        return const _EstadoInfo('Aceptada · a retirar', Colors.green);
      case 'rechazada':
        return const _EstadoInfo('Rechazada', Colors.red);
      case 'retirada':
        return const _EstadoInfo('Retirada', Colors.blueGrey);
      case 'cancelada':
        return const _EstadoInfo('Cancelada', Colors.grey);
      default:
        return _EstadoInfo(estado, Colors.grey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: const Text('Mis reservas'),
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Error: ${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final reservas = snap.data ?? [];

              if (reservas.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Todavía no hiciste ninguna reserva en la tienda.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reservas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final r = reservas[i];
                  final estado = (r['estado'] ?? '').toString();
                  final info = _estadoInfo(estado);
                  final productoNombre = (r['producto_nombre'] ?? '').toString();
                  final imagenUrl = (r['producto_imagen_url'] ?? '').toString();
                  final cantidad = (r['cantidad'] ?? 1).toString();
                  final mensajeAdmin = (r['mensaje_admin'] ?? '').toString();
                  final fecha = _formatFecha(r['created_at']?.toString());

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade100,
                            child: imagenUrl.isNotEmpty
                                ? Image.network(
                                    imagenUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_outlined,
                                      color: Colors.black26,
                                    ),
                                  )
                                : const Icon(Icons.shopping_bag_outlined, color: Colors.black26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      productoNombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: info.color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      info.label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: info.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Cantidad: $cantidad · ${_formatPrecio(r['producto_precio'])}',
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              if (fecha.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Reservado el $fecha',
                                    style: const TextStyle(fontSize: 11, color: Colors.black38),
                                  ),
                                ),
                              if (mensajeAdmin.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.black45),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          mensajeAdmin,
                                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
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
