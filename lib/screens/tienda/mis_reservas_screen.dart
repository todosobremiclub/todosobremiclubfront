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

  // ✅ Formatea con separador de miles "." y decimales con "," (ej: $25.000,00).
  String _formatPrecio(dynamic precio) {
    final n = num.tryParse((precio ?? '').toString());
    if (n == null) return '—';

    final negativo = n < 0;
    final centavos = (n.abs() * 100).round();
    final entero = centavos ~/ 100;
    final decimales = (centavos % 100).toString().padLeft(2, '0');

    final enteroStr = entero.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < enteroStr.length; i++) {
      final posDesdeElFinal = enteroStr.length - i;
      buffer.write(enteroStr[i]);
      if (posDesdeElFinal > 1 && posDesdeElFinal % 3 == 1) {
        buffer.write('.');
      }
    }

    return '\$${negativo ? '-' : ''}${buffer.toString()},$decimales';
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

              // ✅ NUEVO: agrupa las líneas por pedido_id (un pedido con
              // varios productos del carrito se muestra como una sola
              // tarjeta con todas sus líneas, ya que el club lo gestiona
              // como una unidad).
              final pedidos = <String, List<Map<String, dynamic>>>{};
              final ordenPedidos = <String>[];
              for (final r in reservas) {
                final pedidoId = (r['pedido_id'] ?? r['id'] ?? '').toString();
                if (!pedidos.containsKey(pedidoId)) {
                  pedidos[pedidoId] = [];
                  ordenPedidos.add(pedidoId);
                }
                pedidos[pedidoId]!.add(r);
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ordenPedidos.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final lineas = pedidos[ordenPedidos[i]]!;
                  final primera = lineas.first;
                  final estado = (primera['estado'] ?? '').toString();
                  final info = _estadoInfo(estado);
                  final fecha = _formatFecha(primera['created_at']?.toString());
                  final esVariasLineas = lineas.length > 1;
                  final totalPedido = lineas.fold<num>(0, (acc, r) {
                    final precio = num.tryParse((r['producto_precio'] ?? 0).toString()) ?? 0;
                    final cant = num.tryParse((r['cantidad'] ?? 1).toString()) ?? 1;
                    return acc + precio * cant;
                  });

                  final mensajeAdmin = (primera['mensaje_admin'] ?? '').toString();

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                esVariasLineas ? 'Pedido con ${lineas.length} productos' : 'Pedido',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black54,
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
                        const SizedBox(height: 10),
                        for (final r in lineas)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 52,
                                    height: 52,
                                    color: Colors.grey.shade100,
                                    child: ((r['producto_imagen_url'] ?? '').toString()).isNotEmpty
                                        ? Image.network(
                                            (r['producto_imagen_url'] ?? '').toString(),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(
                                              Icons.image_outlined,
                                              color: Colors.black26,
                                            ),
                                          )
                                        : const Icon(Icons.shopping_bag_outlined, color: Colors.black26),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (r['talle'] ?? '').toString().isNotEmpty
                                            ? '${r['producto_nombre'] ?? ''} (talle ${r['talle']})'
                                            : (r['producto_nombre'] ?? '').toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Cantidad: ${r['cantidad'] ?? 1} · ${_formatPrecio(r['producto_precio'])}',
                                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (esVariasLineas)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Total: ${_formatPrecio(totalPedido)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ),
                        if (fecha.isNotEmpty)
                          Text(
                            'Reservado el $fecha',
                            style: const TextStyle(fontSize: 11, color: Colors.black38),
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
