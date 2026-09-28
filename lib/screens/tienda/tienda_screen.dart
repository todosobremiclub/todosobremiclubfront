// lib/screens/tienda/tienda_screen.dart
//
// Catálogo de productos de la Tienda Online del club (lado socio).
// Consume GET /app/tienda/productos (solo productos activos, y el
// backend ya devuelve 403 si el club no tiene tienda_habilitada — pero
// no debería llegarse acá en ese caso, porque MasScreen no muestra el
// ítem "Tienda" si club.tiendaHabilitada es false).
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/tienda_service.dart';
import 'producto_detalle_screen.dart';
import 'mis_reservas_screen.dart';

class TiendaScreen extends StatefulWidget {
  final AppSession session;

  const TiendaScreen({super.key, required this.session});

  @override
  State<TiendaScreen> createState() => _TiendaScreenState();
}

class _TiendaScreenState extends State<TiendaScreen> {
  final _service = TiendaService();
  late Future<List<Map<String, dynamic>>> _future;

  // ✅ NUEVO: búsqueda por nombre/descripción + filtro por tipificación.
  final _searchController = TextEditingController();
  String _busqueda = '';
  String? _categoriaSeleccionada; // null = "Todos"

  @override
  void initState() {
    super.initState();
    _future = _load();
    _searchController.addListener(() {
      setState(() => _busqueda = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return _service.getProductos(token: widget.session.token);
  }

  Future<void> _refrescar() async {
    setState(() => _future = _load());
    await _future;
  }

  // ✅ Tipificaciones distintas presentes en el catálogo, para armar los chips
  // de filtro (se calculan a partir de los productos ya cargados, sin pegarle
  // a un endpoint aparte).
  List<String> _categoriasDisponibles(List<Map<String, dynamic>> productos) {
    final set = <String>{};
    for (final p in productos) {
      final nombre = (p['categoria_nombre'] ?? '').toString().trim();
      if (nombre.isNotEmpty) set.add(nombre);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Map<String, dynamic>> _productosFiltrados(List<Map<String, dynamic>> productos) {
    return productos.where((p) {
      if (_busqueda.isNotEmpty) {
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        final descripcion = (p['descripcion'] ?? '').toString().toLowerCase();
        if (!nombre.contains(_busqueda) && !descripcion.contains(_busqueda)) {
          return false;
        }
      }
      if (_categoriaSeleccionada != null) {
        final categoria = (p['categoria_nombre'] ?? '').toString();
        if (categoria != _categoriaSeleccionada) return false;
      }
      return true;
    }).toList();
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: const Text('Tienda'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Mis reservas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MisReservasScreen(session: widget.session),
                ),
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

              final productos = snap.data ?? [];

              if (productos.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 80),
                    Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Todavía no hay productos publicados en la tienda del club.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    ),
                  ],
                );
              }

              // ✅ NUEVO: buscador por nombre/descripción + filtro por
              // tipificación (chips), sobre el catálogo ya cargado.
              final categorias = _categoriasDisponibles(productos);
              final productosFiltrados = _productosFiltrados(productos);

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar producto...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _busqueda.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _searchController.clear(),
                              ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  if (categorias.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: ChoiceChip(
                                label: const Text('Todos'),
                                selected: _categoriaSeleccionada == null,
                                onSelected: (_) => setState(() => _categoriaSeleccionada = null),
                              ),
                            ),
                            for (final cat in categorias)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(cat),
                                  selected: _categoriaSeleccionada == cat,
                                  onSelected: (_) => setState(() {
                                    _categoriaSeleccionada = _categoriaSeleccionada == cat ? null : cat;
                                  }),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: productosFiltrados.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    'No se encontraron productos con ese criterio.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: productosFiltrados.length,
                            itemBuilder: (context, i) {
                              final p = productosFiltrados[i];
                              final nombre = (p['nombre'] ?? '').toString();
                              final imagenUrl = (p['imagen_url'] ?? '').toString();
                              final stock = int.tryParse((p['stock'] ?? 0).toString()) ?? 0;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductoDetalleScreen(
                                        session: widget.session,
                                        producto: p,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
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
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Container(
                                            color: Colors.grey.shade100,
                                            child: imagenUrl.isNotEmpty
                                                ? Image.network(
                                                    imagenUrl,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => const Center(
                                                      child: Icon(
                                                        Icons.image_outlined,
                                                        size: 36,
                                                        color: Colors.black26,
                                                      ),
                                                    ),
                                                  )
                                                : const Center(
                                                    child: Icon(
                                                      Icons.shopping_bag_outlined,
                                                      size: 40,
                                                      color: Colors.black26,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                nombre,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _formatPrecio(p['precio']),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                stock > 0 ? 'Stock: $stock' : 'Sin stock',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: stock > 0 ? Colors.black45 : Colors.red,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
