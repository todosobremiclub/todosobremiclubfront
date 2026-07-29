import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class AsistenciaFormScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const AsistenciaFormScreen({
    super.key,
    required this.token,
    required this.clubId,
  });

  @override
  State<AsistenciaFormScreen> createState() => _AsistenciaFormScreenState();
}

class _AsistenciaFormScreenState extends State<AsistenciaFormScreen> {
  final _anioNacimientoController = TextEditingController();
  final _buscarInvitadoController = TextEditingController();

  String _tipo = 'entrenamiento';
  String? _actividad;
  String? _categoria;
  String? _actividadAdicional;
  DateTime _fecha = DateTime.now();

  List<String> _actividades = [];
  List<String> _categorias = [];
  List<String> _actividadesAdicionales = [];

  List<Map<String, dynamic>> _convocados = [];
  final Map<String, bool> _presentes = {};

  List<Map<String, dynamic>> _invitados = [];
  List<Map<String, dynamic>> _resultadosInvitado = [];
  bool _buscandoInvitado = false;

  bool _cargandoListas = true;
  bool _buscando = false;
  bool _guardando = false;
  bool _pasoDatos = true;

  @override
  void initState() {
    super.initState();
    _cargarListas();
  }

  Future<void> _cargarListas() async {
    try {
      final categorias = await AdminApiService.getCategorias(
        token: widget.token,
        clubId: widget.clubId,
      );
      final actividades = await AdminApiService.getActividades(
        token: widget.token,
        clubId: widget.clubId,
      );
      final adicionales = await AdminApiService.getActividadesAdicionalesNombres(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _actividades = actividades;
        _actividadesAdicionales = adicionales;
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

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _buscarConvocados() async {
    if (_actividad == null || _categoria == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí Actividad y Categoría')),
      );
      return;
    }

    setState(() => _buscando = true);

    try {
      final convocados = await AdminApiService.buscarConvocados(
        token: widget.token,
        clubId: widget.clubId,
        actividad: _actividad!,
        categoria: _categoria!,
        actividadAdicional: _actividadAdicional,
        anioNacimiento: _anioNacimientoController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _convocados = convocados;
        _presentes.clear();
        for (final s in convocados) {
          // ✅ Sin tilde por defecto
          _presentes[s['id'].toString()] = false;
        }
        _invitados = [];
        _resultadosInvitado = [];
        _pasoDatos = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _buscarInvitado() async {
    final q = _buscarInvitadoController.text.trim();
    if (q.isEmpty) return;

    setState(() => _buscandoInvitado = true);

    try {
      final resultados = await AdminApiService.buscarSocios(
        token: widget.token,
        clubId: widget.clubId,
        query: q,
      );

      final yaConvocado = _convocados.map((s) => s['id'].toString()).toSet();
      final yaInvitado = _invitados.map((s) => s['id'].toString()).toSet();

      if (!mounted) return;
      setState(() {
        _resultadosInvitado = resultados
            .where((s) =>
                !yaConvocado.contains(s['id'].toString()) &&
                !yaInvitado.contains(s['id'].toString()))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _buscandoInvitado = false);
    }
  }

  void _agregarInvitado(Map<String, dynamic> socio) {
    setState(() {
      _invitados.add(socio);
      _resultadosInvitado.removeWhere((s) => s['id'].toString() == socio['id'].toString());
      _buscarInvitadoController.clear();
    });
  }

  void _quitarInvitado(String id) {
    setState(() {
      _invitados.removeWhere((s) => s['id'].toString() == id);
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);

    try {
      final fechaStr =
          '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';

      final convocadosPayload = _convocados
          .map((s) => {
                'socioId': s['id'].toString(),
                'presente': _presentes[s['id'].toString()] ?? false,
              })
          .toList();

      final invitadosPayload =
          _invitados.map((s) => {'socioId': s['id'].toString()}).toList();

      await AdminApiService.guardarAsistencia(
        token: widget.token,
        clubId: widget.clubId,
        tipo: _tipo,
        actividad: _actividad!,
        categoria: _categoria!,
        fecha: fechaStr,
        convocados: convocadosPayload,
        invitados: invitadosPayload,
        actividadAdicional: _actividadAdicional,
        anioNacimiento: _anioNacimientoController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Asistencia guardada')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _anioNacimientoController.dispose();
    _buscarInvitadoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoListas) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registrar asistencia')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar asistencia')),
      body: SafeArea(
        child: _pasoDatos ? _buildPasoDatos() : _buildPasoLista(),
      ),
    );
  }

  Widget _buildPasoDatos() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          DropdownButtonFormField<String>(
            value: _tipo,
            decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'entrenamiento', child: Text('Entrenamiento')),
              DropdownMenuItem(value: 'partido', child: Text('Partido')),
            ],
            onChanged: (v) => setState(() => _tipo = v ?? _tipo),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _actividad,
            decoration: const InputDecoration(labelText: 'Actividad', border: OutlineInputBorder()),
            items: _actividades
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _actividad = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _categoria,
            decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
            items: _categorias
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _categoria = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _actividadAdicional,
            decoration: const InputDecoration(
              labelText: 'Actividad adicional (opcional)',
              border: OutlineInputBorder(),
            ),
            items: _actividadesAdicionales
                .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                .toList(),
            onChanged: (v) => setState(() => _actividadAdicional = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _anioNacimientoController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Año de nacimiento (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Fecha'),
            subtitle: Text(
              '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _elegirFecha,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _buscando ? null : _buscarConvocados,
            child: _buscando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Buscar socios'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasoLista() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_tipo == 'partido' ? 'Partido' : 'Entrenamiento'} · $_actividad · $_categoria'
                  '${_actividadAdicional != null ? ' · $_actividadAdicional' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _pasoDatos = true),
                child: const Text('Volver'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (_convocados.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay socios que coincidan con esos filtros.'),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'Convocados (${_convocados.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ..._convocados.map((s) {
                  final id = s['id'].toString();
                  return CheckboxListTile(
                    title: Text('${s['apellido']}, ${s['nombre']}'),
                    subtitle: Text('N° ${s['numero_socio'] ?? '-'}'),
                    value: _presentes[id] ?? false,
                    onChanged: (v) => setState(() => _presentes[id] = v ?? false),
                  );
                }),
              ],
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(
                  'Invitados de otra categoría (${_invitados.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buscarInvitadoController,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre o DNI',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _buscarInvitado(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _buscandoInvitado ? null : _buscarInvitado,
                      child: const Text('Buscar'),
                    ),
                  ],
                ),
              ),
              if (_resultadosInvitado.isNotEmpty)
                ..._resultadosInvitado.map((s) => ListTile(
                      dense: true,
                      title: Text('${s['apellido']}, ${s['nombre']}'),
                      subtitle: Text(s['categoria']?.toString() ?? ''),
                      trailing: TextButton(
                        onPressed: () => _agregarInvitado(s),
                        child: const Text('+ Agregar'),
                      ),
                    )),
              if (_invitados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _invitados.map((s) {
                      return Chip(
                        label: Text('${s['apellido']}, ${s['nombre']}'),
                        onDeleted: () => _quitarInvitado(s['id'].toString()),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
        // ✅ Botón siempre visible, fijo abajo (no scrollea con la lista)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, -2)),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_guardando || _convocados.isEmpty) ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar asistencia'),
            ),
          ),
        ),
      ],
    );
  }
}