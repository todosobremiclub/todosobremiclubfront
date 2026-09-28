// lib/screens/tienda/producto_detalle_screen.dart
//
// Detalle de un producto de la tienda + reserva. Sin pago online: el
// socio reserva y paga/retira en el club cuando el admin acepta la
// reserva (ver claude/tienda-online-plan.md).
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/tienda_service.dart';
import 'mis_reservas_screen.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final AppSession session;
  final Map<String, dynamic> producto;

  const ProductoDetalleScreen({
    super.key,
    required this.session,
    required this.producto,
  });

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  final _service = TiendaService();
  int _cantidad = 1;
  bool _reservando = false;

  int get _stock =>
      int.tryParse((widget.producto['stock'] ?? 0).toString()) ?? 0;

  String _formatPrecio(dynamic precio) {
    final n = num.tryParse((precio ?? '').toString());
    if (n == null) return '—';
    return '\$${n.toStringAsFixed(2)}';
  }

  Future<void> _reservar() async {
    final nombre = (widget.producto['nombre'] ?? '').toString();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: Text(
          '¿Reservar $_cantidad ${_cantidad == 1 ? 'unidad' : 'unidades'} de '
          '"$nombre"? El club te va a avisar cuando puedas retirarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reservar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    if (!mounted) return;

    setState(() => _reservando = true);

    try {
      await _service.crearReserva(
        token: widget.session.token,
        productoId: (widget.producto['id'] ?? '').toString(),
        cantidad: _cantidad,
      );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Listo!'),
          content: const Text(
            'Tu reserva fue enviada. El club te va a avisar cuando la acepte '
            'y puedas pasar a retirar el producto.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MisReservasScreen(session: widget.session),
                  ),
                );
              },
              child: const Text('Ver mis reservas'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _reservando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.producto;
    final nombre = (p['nombre'] ?? '').toString();
    final descripcion = (p['descripcion'] ?? '').toString();
    final imagenUrl = (p['imagen_url'] ?? '').toString();
    final sinStock = _stock <= 0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: Text(nombre),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Container(
              height: 260,
              width: double.infinity,
              color: Colors.grey.shade100,
              child: imagenUrl.isNotEmpty
                  ? Image.network(
                      imagenUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.image_outlined, size: 52, color: Colors.black26),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.black26),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombre,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatPrecio(p['precio']),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sinStock ? 'Sin stock disponible' : 'Stock disponible: $_stock',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sinStock ? Colors.red : Colors.black54,
                    ),
                  ),
                  if (descripcion.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Descripción',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descripcion,
                      style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (!sinStock) ...[
                    const Text(
                      'Cantidad',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _cantidad > 1
                              ? () => setState(() => _cantidad--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                          '$_cantidad',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          onPressed: _cantidad < _stock
                              ? () => setState(() => _cantidad++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _reservando ? null : _reservar,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _reservando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Reservar'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Sin pago online: el producto se paga y se retira en el club.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
