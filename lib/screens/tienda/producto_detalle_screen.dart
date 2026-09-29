// lib/screens/tienda/producto_detalle_screen.dart
//
// Detalle de un producto de la tienda + reserva. Sin pago online: el
// socio reserva y paga/retira en el club cuando el admin acepta la
// reserva (ver claude/tienda-online-plan.md).
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/tienda_service.dart';
import '../../services/carrito_tienda.dart';
import 'carrito_screen.dart';

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
  int _cantidad = 1;
  bool _agregando = false;

  // ✅ NUEVO: talles configurables por producto (GET /app/tienda/productos
  // ya devuelve `tiene_talles` + `talles: [{id, talle, stock}]`).
  late final bool _tieneTalles = widget.producto['tiene_talles'] == true;
  late final List<Map<String, dynamic>> _talles =
      List<Map<String, dynamic>>.from(widget.producto['talles'] ?? []);
  Map<String, dynamic>? _talleSeleccionado;

  // ✅ NUEVO: hasta 3 fotos por producto, mostradas tipo carrete (deslizando).
  // El backend ya devuelve `imagenes` (sin huecos); si por algún motivo no
  // viene (versión vieja de la API), se arma con `imagen_url` solo.
  late final List<String> _imagenes = () {
    final lista = ((widget.producto['imagenes'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty)
        .toList();
    if (lista.isNotEmpty) return lista;
    final unica = (widget.producto['imagen_url'] ?? '').toString();
    return unica.isNotEmpty ? [unica] : <String>[];
  }();
  final _fotosController = PageController();
  int _fotoActual = 0;

  @override
  void dispose() {
    _fotosController.dispose();
    super.dispose();
  }

  int get _stockTotal =>
      int.tryParse((widget.producto['stock'] ?? 0).toString()) ?? 0;

  /// Stock disponible según el talle elegido (o el stock total del
  /// producto si no vende por talle).
  int get _stock {
    if (!_tieneTalles) return _stockTotal;
    if (_talleSeleccionado == null) return 0;
    return int.tryParse((_talleSeleccionado!['stock'] ?? 0).toString()) ?? 0;
  }

  // ✅ Formatea con separador de miles "." y decimales con "," (ej: $25.000,00),
  // sin depender de datos de locale de `intl` (evita romper si el paquete no
  // trae "es_AR" cargado).
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

  // ✅ NUEVO: en vez de reservar directo, agrega la línea al carrito
  // compartido (CarritoTienda) y deja que el socio siga sumando productos
  // antes de confirmar el pedido completo desde CarritoScreen.
  void _agregarAlCarrito() {
    if (_tieneTalles && _talleSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un talle antes de agregar al carrito.')),
      );
      return;
    }

    setState(() => _agregando = true);

    CarritoTienda.instance.agregar(
      CarritoItem(
        productoId: (widget.producto['id'] ?? '').toString(),
        nombre: (widget.producto['nombre'] ?? '').toString(),
        imagenUrl: (widget.producto['imagen_url'] ?? '').toString(),
        precio: num.tryParse((widget.producto['precio'] ?? 0).toString()) ?? 0,
        talleId: _tieneTalles ? (_talleSeleccionado!['id'] ?? '').toString() : null,
        talle: _tieneTalles ? (_talleSeleccionado!['talle'] ?? '').toString() : null,
        stockDisponible: _stock,
        cantidad: _cantidad,
      ),
    );

    setState(() => _agregando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Agregado al carrito'),
        action: SnackBarAction(
          label: 'Ver carrito',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CarritoScreen(session: widget.session),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = widget.producto;
    final nombre = (p['nombre'] ?? '').toString();
    final descripcion = (p['descripcion'] ?? '').toString();
    // Sin talles: "sin stock" mira el stock total del producto. Con talles:
    // el producto puede seguir teniendo talles con stock aunque el socio
    // todavía no haya elegido ninguno, así que acá miramos el stock total
    // sumado (para saber si mostrar la grilla de talles) y más abajo se
    // valida el stock del talle elegido puntual.
    final sinStockTotal = _tieneTalles ? _stockTotal <= 0 : _stock <= 0;
    final puedeElegirCantidad = _tieneTalles
        ? (_talleSeleccionado != null && _stock > 0)
        : !sinStockTotal;

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
            // ✅ NUEVO: hasta 3 fotos, tipo carrete (deslizando horizontalmente).
            SizedBox(
              height: 260,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 260,
                    color: Colors.grey.shade100,
                    child: _imagenes.isEmpty
                        ? const Center(
                            child: Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.black26),
                          )
                        : PageView.builder(
                            controller: _fotosController,
                            itemCount: _imagenes.length,
                            onPageChanged: (i) => setState(() => _fotoActual = i),
                            itemBuilder: (context, i) {
                              return Image.network(
                                _imagenes[i],
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Icon(Icons.image_outlined, size: 52, color: Colors.black26),
                                ),
                              );
                            },
                          ),
                  ),
                  if (_imagenes.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_imagenes.length, (i) {
                          final activo = i == _fotoActual;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: activo ? 18 : 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: activo ? scheme.primary : Colors.black26,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
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
                    sinStockTotal
                        ? 'Sin stock disponible'
                        : (_tieneTalles
                            ? 'Stock total: $_stockTotal'
                            : 'Stock disponible: $_stock'),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sinStockTotal ? Colors.red : Colors.black54,
                    ),
                  ),
                  if (_tieneTalles && !sinStockTotal) ...[
                    const SizedBox(height: 18),
                    const Text(
                      'Talles',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _talles.map((t) {
                        final stockTalle = int.tryParse((t['stock'] ?? 0).toString()) ?? 0;
                        final sinStockTalle = stockTalle <= 0;
                        final seleccionado = _talleSeleccionado != null &&
                            _talleSeleccionado!['id'] == t['id'];
                        return _TalleCuadradito(
                          talle: (t['talle'] ?? '').toString(),
                          disponible: !sinStockTalle,
                          seleccionado: seleccionado,
                          color: scheme.primary,
                          onTap: sinStockTalle
                              ? null
                              : () => setState(() {
                                    _talleSeleccionado = t;
                                    _cantidad = 1;
                                  }),
                        );
                      }).toList(),
                    ),
                  ],
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
                  if (puedeElegirCantidad) ...[
                    const Text(
                      'Cantidad',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _CantidadBoton(
                          icon: Icons.remove,
                          habilitado: _cantidad > 1,
                          color: scheme.primary,
                          onTap: () => setState(() => _cantidad--),
                        ),
                        SizedBox(
                          width: 44,
                          child: Text(
                            '$_cantidad',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        _CantidadBoton(
                          icon: Icons.add,
                          habilitado: _cantidad < _stock,
                          color: scheme.primary,
                          onTap: () => setState(() => _cantidad++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _agregando ? null : _agregarAlCarrito,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _agregando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Agregar al carrito'),
                      ),
                    ),
                  ] else if (_tieneTalles && !sinStockTotal) ...[
                    const Text(
                      'Elegí un talle para agregarlo al carrito.',
                      style: TextStyle(fontSize: 13, color: Colors.black54),
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

// ✅ NUEVO: "cuadradito" de talle (según el diseño que pasó el club: una
// grilla de talles, y los que no tienen stock se ven tachados con una
// línea diagonal y no son seleccionables).
class _TalleCuadradito extends StatelessWidget {
  final String talle;
  final bool disponible;
  final bool seleccionado;
  final Color color;
  final VoidCallback? onTap;

  const _TalleCuadradito({
    required this.talle,
    required this.disponible,
    required this.seleccionado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = seleccionado ? color : (disponible ? Colors.black26 : Colors.black12);
    final bgColor = seleccionado ? color.withOpacity(0.12) : Colors.white;
    final textColor = !disponible ? Colors.black38 : (seleccionado ? color : Colors.black87);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: seleccionado ? 2 : 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              talle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            if (!disponible)
              CustomPaint(
                size: const Size(44, 44),
                painter: _LineaDiagonalPainter(color: Colors.black26),
              ),
          ],
        ),
      ),
    );
  }
}

class _LineaDiagonalPainter extends CustomPainter {
  final Color color;

  const _LineaDiagonalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(4, size.height - 4), Offset(size.width - 4, 4), paint);
  }

  @override
  bool shouldRepaint(covariant _LineaDiagonalPainter oldDelegate) => oldDelegate.color != color;
}

// ✅ NUEVO: botón +/- de cantidad con borde propio, siempre visible
// (reemplaza a los IconButton sueltos, que en algunos temas quedaban con
// el ícono "+" prácticamente invisible por el color por defecto).
class _CantidadBoton extends StatelessWidget {
  final IconData icon;
  final bool habilitado;
  final Color color;
  final VoidCallback onTap;

  const _CantidadBoton({
    required this.icon,
    required this.habilitado,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorActivo = habilitado ? color : Colors.black26;

    return InkWell(
      onTap: habilitado ? onTap : null,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colorActivo, width: 1.4),
        ),
        child: Icon(icon, size: 20, color: colorActivo),
      ),
    );
  }
}
