import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class BuscarSocioScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const BuscarSocioScreen({super.key, required this.token, required this.clubId});

  @override
  State<BuscarSocioScreen> createState() => _BuscarSocioScreenState();
}

class _BuscarSocioScreenState extends State<BuscarSocioScreen> {
  final _buscarController = TextEditingController();

  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _seleccionado;
  bool _buscando = false;

  Future<void> _buscar() async {
    final q = _buscarController.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _buscando = true;
      _seleccionado = null;
    });

    try {
      final resultados = await AdminApiService.buscarSocios(
        token: widget.token,
        clubId: widget.clubId,
        query: q,
      );
      if (!mounted) return;
      setState(() => _resultados = resultados);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar socio')),
      body: _seleccionado == null ? _buildBusqueda() : _buildDetalle(),
    );
  }

  Widget _buildBusqueda() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscarController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre, apellido o DNI',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _buscar(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _buscando ? null : _buscar,
                child: const Text('Buscar'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_buscando) const Center(child: CircularProgressIndicator()),
          Expanded(
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final s = _resultados[index];
                return ListTile(
                  title: Text('${s['apellido']}, ${s['nombre']}'),
                  subtitle: Text('N° ${s['numero_socio'] ?? '-'} · ${s['actividad'] ?? '-'}'),
                  onTap: () => setState(() => _seleccionado = s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalle() {
    final s = _seleccionado!;

    Widget fila(String label, dynamic valor) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(child: Text(valor?.toString() ?? '—')),
            ],
          ),
        );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _seleccionado = null),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver a la búsqueda'),
          ),
          const SizedBox(height: 8),
          Text(
            '${s['apellido']}, ${s['nombre']}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          fila('N° Socio', s['numero_socio']),
          fila('DNI', s['dni']),
          fila('Categoría', s['categoria']),
          fila('Actividad', s['actividad']),
          fila('Teléfono', s['telefono']),
          fila('Dirección', s['direccion']),
          fila('Email', s['email']),
          fila('Fecha nacimiento', s['fecha_nacimiento']),
          fila('Activo', s['activo'] == true ? 'Sí' : 'No'),
          fila('Becado', s['becado'] == true ? 'Sí' : 'No'),
        ],
      ),
    );
  }
}