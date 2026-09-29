// lib/services/carrito_tienda.dart
//
// Estado en memoria del carrito de compras de la Tienda Online (lado
// socio). Vive durante toda la sesión de la app: se vacía al confirmar
// el pedido (POST /app/tienda/reservas con { items: [...] }) o si el
// socio cierra sesión. No persiste en disco a propósito: es un carrito
// de "una sola pasada", no un borrador que deba sobrevivir a reinicios.
import 'package:flutter/foundation.dart';

class CarritoItem {
  final String productoId;
  final String nombre;
  final String? imagenUrl;
  final num precio;
  final String? talleId;
  final String? talle;
  final int stockDisponible;
  int cantidad;

  CarritoItem({
    required this.productoId,
    required this.nombre,
    this.imagenUrl,
    required this.precio,
    this.talleId,
    this.talle,
    required this.stockDisponible,
    this.cantidad = 1,
  });

  /// Un producto sin talle y el mismo producto con dos talles distintos
  /// son líneas separadas del carrito.
  String get key => '$productoId|${talleId ?? ''}';

  num get subtotal => precio * cantidad;

  Map<String, dynamic> toItemPedido() => {
        'producto_id': productoId,
        if (talleId != null) 'talle_id': talleId,
        'cantidad': cantidad,
      };
}

/// Singleton simple (no depende de ningún paquete de manejo de estado)
/// para que TiendaScreen, ProductoDetalleScreen y CarritoScreen compartan
/// el mismo carrito sin pasarlo a mano por los constructores.
class CarritoTienda extends ChangeNotifier {
  CarritoTienda._();
  static final CarritoTienda instance = CarritoTienda._();

  final List<CarritoItem> _items = [];

  List<CarritoItem> get items => List.unmodifiable(_items);

  bool get estaVacio => _items.isEmpty;

  int get cantidadTotal => _items.fold(0, (acc, i) => acc + i.cantidad);

  num get total => _items.fold<num>(0, (acc, i) => acc + i.subtotal);

  /// Agrega un ítem al carrito. Si ya existe una línea para el mismo
  /// producto+talle, suma la cantidad (topeada al stock disponible) en
  /// vez de crear una línea duplicada.
  void agregar(CarritoItem nuevo) {
    final idx = _items.indexWhere((i) => i.key == nuevo.key);
    if (idx >= 0) {
      final actual = _items[idx];
      final sumada = actual.cantidad + nuevo.cantidad;
      actual.cantidad = sumada > actual.stockDisponible ? actual.stockDisponible : sumada;
    } else {
      _items.add(nuevo);
    }
    notifyListeners();
  }

  void actualizarCantidad(String key, int cantidad) {
    final idx = _items.indexWhere((i) => i.key == key);
    if (idx < 0) return;
    if (cantidad <= 0) {
      _items.removeAt(idx);
    } else {
      final tope = _items[idx].stockDisponible;
      _items[idx].cantidad = cantidad > tope ? tope : cantidad;
    }
    notifyListeners();
  }

  void quitar(String key) {
    _items.removeWhere((i) => i.key == key);
    notifyListeners();
  }

  void limpiar() {
    _items.clear();
    notifyListeners();
  }
}
