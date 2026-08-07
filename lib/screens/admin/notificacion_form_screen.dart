import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class NotificacionFormScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const NotificacionFormScreen({
    super.key,
    required this.token,
    required this.clubId,
  });

  @override
  State<NotificacionFormScreen> createState() => _NotificacionFormScreenState();
}

class _NotificacionFormScreenState extends State<NotificacionFormScreen> {
  final _tituloController = TextEditingController();
  final _cuerpoController = TextEditingController();

  bool _enviando = false;
  bool _cargandoListas = true;

  List<String> _actividades = [];
  List<String> _categorias = [];
  List<int> _anios = [];

  // 'todos' | 'actividad' | 'categoria' | 'anio_nac' | 'cat_anio' | 'act_cat' | 'falta_pago'
  String _destinoTipo = 'todos';
  String? _valorActividad;
  String? _valorCategoria;
  int? _valorAnio;

  static const Map<String, String> _destinoLabels = {
    'todos': 'Todos los socios',
    'actividad': 'Por actividad',
    'categoria': 'Por categoría',
    'anio_nac': 'Por año de nacimiento',
    'cat_anio': 'Por categoría + año de nacimiento',
    'act_cat': 'Por actividad + categoría',
    'falta_pago': 'En falta de pago',
  };

  @override
  void initState() {
    super.initState();
    _cargarListas();
  }

  Future<void> _cargarListas() async {
    try {
      final actividades = await AdminApiService.getActividades(
        token: widget.token,
        clubId: widget.clubId,
      );
      final categorias = await AdminApiService.getCategorias(
        token: widget.token,
        clubId: widget.clubId,
      );
      final anios = await AdminApiService.getAniosNacimiento(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() {
        _actividades = actividades;
        _categorias = categorias;
        _anios = anios;
        _cargandoListas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoListas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando listas: $e')),
      );
    }
  }

  bool _destinoCompleto() {
    switch (_destinoTipo) {
      case 'todos':
      case 'falta_pago':
        return true;
      case 'actividad':
        return _valorActividad != null;
      case 'categoria':
        return _valorCategoria != null;
      case 'anio_nac':
        return _valorAnio != null;
      case 'cat_anio':
        return _valorCategoria != null && _valorAnio != null;
      case 'act_cat':
        return _valorActividad != null && _valorCategoria != null;
      default:
        return false;
    }
  }

  Future<void> _enviar() async {
    final titulo = _tituloController.text.trim();
    final cuerpo = _cuerpoController.text.trim();

    if (titulo.isEmpty || cuerpo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá título y mensaje')),
      );
      return;
    }

    if (!_destinoCompleto()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá el destino de la notificación')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      String? valor1;
      String? valor2;
      switch (_destinoTipo) {
        case 'actividad':
          valor1 = _valorActividad;
          break;
        case 'categoria':
          valor1 = _valorCategoria;
          break;
        case 'anio_nac':
          valor1 = _valorAnio?.toString();
          break;
        case 'cat_anio':
          valor1 = _valorCategoria;
          valor2 = _valorAnio?.toString();
          break;
        case 'act_cat':
          valor1 = _valorActividad;
          valor2 = _valorCategoria;
          break;
      }

      await AdminApiService.enviarNotificacion(
        token: widget.token,
        clubId: widget.clubId,
        titulo: titulo,
        cuerpo: cuerpo,
        destinoTipo: _destinoTipo,
        destinoValor1: valor1,
        destinoValor2: valor2,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Notificación enviada')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _cuerpoController.dispose();
    super.dispose();
  }

  Widget _buildCamposDestino() {
    switch (_destinoTipo) {
      case 'actividad':
        return DropdownButtonFormField<String>(
          value: _valorActividad,
          decoration: const InputDecoration(labelText: 'Actividad', border: OutlineInputBorder()),
          items: _actividades.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => setState(() => _valorActividad = v),
        );
      case 'categoria':
        return DropdownButtonFormField<String>(
          value: _valorCategoria,
          decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
          items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _valorCategoria = v),
        );
      case 'anio_nac':
        return DropdownButtonFormField<int>(
          value: _valorAnio,
          decoration: const InputDecoration(labelText: 'Año de nacimiento', border: OutlineInputBorder()),
          items: _anios.map((a) => DropdownMenuItem(value: a, child: Text(a.toString()))).toList(),
          onChanged: (v) => setState(() => _valorAnio = v),
        );
      case 'cat_anio':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _valorCategoria,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _valorCategoria = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _valorAnio,
              decoration: const InputDecoration(labelText: 'Año de nacimiento', border: OutlineInputBorder()),
              items: _anios.map((a) => DropdownMenuItem(value: a, child: Text(a.toString()))).toList(),
              onChanged: (v) => setState(() => _valorAnio = v),
            ),
          ],
        );
      case 'act_cat':
        return Column(
          children: [
            DropdownButtonFormField<String>(
              value: _valorActividad,
              decoration: const InputDecoration(labelText: 'Actividad', border: OutlineInputBorder()),
              items: _actividades.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
              onChanged: (v) => setState(() => _valorActividad = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _valorCategoria,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _valorCategoria = v),
            ),
          ],
        );
      default:
        // 'todos' y 'falta_pago' no necesitan campos extra.
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoListas) {
      return Scaffold(
        appBar: AppBar(title: const Text('Enviar notificación')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Enviar notificación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cuerpoController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _destinoTipo,
              decoration: const InputDecoration(labelText: 'Destino', border: OutlineInputBorder()),
              items: _destinoLabels.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() {
                _destinoTipo = v ?? 'todos';
                _valorActividad = null;
                _valorCategoria = null;
                _valorAnio = null;
              }),
            ),
            if (_destinoTipo != 'todos' && _destinoTipo != 'falta_pago') ...[
              const SizedBox(height: 12),
              _buildCamposDestino(),
            ],
            const SizedBox(height: 4),
            Text(
              'La notificación se enviará solo a los socios que cumplan el criterio seleccionado.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar y enviar'),
            ),
          ],
        ),
      ),
    );
  }
}