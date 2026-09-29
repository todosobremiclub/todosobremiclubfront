// lib/screens/tienda/carrito_screen.dart
//
// ✅ NUEVO: carrito de compras de la Tienda Online (lado socio). Junta
// varias líneas (CarritoTienda, en memoria) y las confirma en un solo
// pedido con POST /app/tienda/reservas { items: [...] } — todas las
// líneas quedan agrupadas bajo un mismo pedido_id y el club las gestiona
// como una sola unidad (ver claude/tienda-talles-carrito-venta-manual-plan.md).
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/tienda_service.dart';
import '../../services/carrito_tienda.dart';
import 'mis_reservas_screen.dart';

class CarritoScreen extends StatefulWidget {
  final AppSession session;

  const CarritoScreen({super.key, required this.session});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  final _service = TiendaService();
  bool _confirmando = false;

  String _formatPrecio(num precio) {
    final negativo = precio < 0;
    final centavos = (precio.abs() * 100).round();
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

  Future<void> _confirmarPedido() async {
    final carrito = CarritoTienda.instance;
    if (carrito.estaVacio) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar pedido'),
        content: Text(
          '¿Confirmar el pedido por ${carrito.cantidadTotal} '
          '${carrito.cantidadTotal == 1 ? 'unidad' : 'unidades'} '
          '(${_formatPrecio(carrito.total)})? El club te va a avisar cuando '
          'puedas retirarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    if (!mounted) return;

    setState(() => _confirmando = true);

    try {
      await _service.crearPedido(
        token: widget.session.token,
        items: carrito.items.map((i) => i.toItemPedido()).toList(),
      );

      carrito.limpiar();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Listo!'),
          content: const Text(
            'Tu pedido fue enviado. El club te va a avisar cuando lo acepte '
            'y puedas pasar a retirarlo.',
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

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _confirmando = false);
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
        title: const Text('Carrito'),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: CarritoTienda.instance,
          builder: (context, _) {
            final items = CarritoTienda.instance.items;

            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'Tu carrito está vacío. Agregá productos desde la tienda.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              );
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = items[i];

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
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
                                width: 56,
                                height: 56,
                                color: Colors.grey.shade100,
                                child: (item.imagenUrl ?? '').isNotEmpty
                                    ? Image.network(
                                        item.imagenUrl!,
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
                                  Text(
                                    item.talle != null
                                        ? '${item.nombre} (talle ${item.talle})'
                                        : item.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatPrecio(item.precio),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: scheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _MiniBoton(
                                        icon: Icons.remove,
                                        onTap: () => CarritoTienda.instance
                                            .actualizarCantidad(item.key, item.cantidad - 1),
                                      ),
                                      SizedBox(
                                        width: 32,
                                        child: Text(
                                          '${item.cantidad}',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      _MiniBoton(
                                        icon: Icons.add,
                                        onTap: item.cantidad < item.stockDisponible
                                            ? () => CarritoTienda.instance.actualizarCantidad(
                                                  item.key,
                                                  item.cantidad + 1,
                                                )
                                            : null,
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatPrecio(item.subtotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => CarritoTienda.instance.quitar(item.key),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            Text(
                              _formatPrecio(CarritoTienda.instance.total),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _confirmando ? null : _confirmarPedido,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _confirmando
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Confirmar pedido'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniBoton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _MiniBoton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final habilitado = onTap != null;
    final color = habilitado ? Colors.black87 : Colors.black26;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.2),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
