import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';
import 'asistencia_reporte_screen.dart';

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
  final _buscarInvitadoController = TextEditingController();
  final _anioAdicionalController = TextEditingController(); // ✅ NUEVO
  final _buscarConvocadoController = TextEditingController(); // ✅ NUEVO: filtro de convocados

  String _tipo = 'entrenamiento';
  String? _actividad;
  String? _categoria;
  String? _actividadAdicional;
  DateTime _fecha = DateTime.now();

  List<String> _actividades = [];
  List<String> _actividadesAdicionales = [];

  // ✅ NUEVO: cascada Actividad -> Categoría -> Año de nacimiento. El
  // catálogo completo de categorías del club se guarda aparte para poder
  // filtrarlo por actividad sin perder el orden configurado (mismo criterio
  // que usa la web en backend/public/js/asistencia.js).
  List<String> _todasCategorias = [];
  List<String> _categoriasDisponibles = [];
  bool _cargandoCategorias = false;

  // ✅ NUEVO: "Año de nacimiento" deja de ser un número libre y pasa a ser
  // un selector con los años que realmente tienen socios en la actividad +
  // categoría elegidas.
  List<int> _aniosDisponibles = [];
  String? _anioNacimiento;
  bool _cargandoAnios = false;

  // ✅ NUEVO: para ampliar la búsqueda de convocados a otras categorías/años
  // (chicos que entrenan/juegan con más de una categoría). No afectan la
  // categoría/año "principal" que queda guardada en el evento.
  final List<String> _categoriasAdicionales = [];
  final List<String> _aniosAdicionales = [];

  List<Map<String, dynamic>> _convocados = [];
  final Map<String, bool> _presentes = {};

  // ✅ NUEVO: texto del buscador de convocados (filtra sin refetch)
  String _filtroConvocados = '';

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
        _todasCategorias = categorias;
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

  // ✅ NUEVO: al elegir Actividad, la Categoría (y el año, que depende de
  // ella) quedan obsoletos, así que se resetean y se traen en cascada solo
  // las categorías que tienen socios en esa actividad.
  Future<void> _onActividadChanged(String? actividad) async {
    setState(() {
      _actividad = actividad;
      _categoria = null;
      _categoriasDisponibles = [];
      _categoriasAdicionales.clear();
      _anioNacimiento = null;
      _aniosDisponibles = [];
    });

    if (actividad == null || actividad.isEmpty) return;

    setState(() => _cargandoCategorias = true);
    try {
      final categorias = await AdminApiService.getCategoriasPorActividad(
        token: widget.token,
        clubId: widget.clubId,
        actividad: actividad,
      );
      if (!mounted) return;
      // Se filtra el catálogo completo (mantiene el orden configurado) en
      // vez de usar directamente lo que devuelve el endpoint.
      final nombresSet = categorias.toSet();
      setState(() {
        _categoriasDisponibles = _todasCategorias.where((c) => nombresSet.contains(c)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando categorías: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargandoCategorias = false);
    }
  }

  // ✅ NUEVO: al elegir Categoría (con Actividad ya elegida), trae solo los
  // años de nacimiento que tienen socios en esa combinación.
  Future<void> _onCategoriaChanged(String? categoria) async {
    setState(() {
      _categoria = categoria;
      _anioNacimiento = null;
      _aniosDisponibles = [];
    });

    if (_actividad == null || categoria == null || categoria.isEmpty) return;

    setState(() => _cargandoAnios = true);
    try {
      final anios = await AdminApiService.getAniosPorActividadCategoria(
        token: widget.token,
        clubId: widget.clubId,
        actividad: _actividad!,
        categoria: categoria,
      );
      if (!mounted) return;
      setState(() => _aniosDisponibles = anios);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando años: $e')),
      );
    } finally {
      if (mounted) setState(() => _cargandoAnios = false);
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

  void _abrirReporte() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AsistenciaReporteScreen(token: widget.token, clubId: widget.clubId),
      ),
    );
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
        anioNacimiento: _anioNacimiento ?? '',
        categoriasAdicionales: _categoriasAdicionales, // ✅ NUEVO
        aniosAdicionales: _aniosAdicionales, // ✅ NUEVO
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
        _filtroConvocados = '';
        _buscarConvocadoController.clear();
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

  // ✅ NUEVO: tocar una categoría adicional la prende/apaga (como un filtro)
  void _toggleCategoriaAdicional(String categoria) {
    setState(() {
      if (_categoriasAdicionales.contains(categoria)) {
        _categoriasAdicionales.remove(categoria);
      } else {
        _categoriasAdicionales.add(categoria);
      }
    });
  }

  // ✅ NUEVO: agrega un año adicional desde el input (valida 4 dígitos)
  void _agregarAnioAdicional() {
    final valor = _anioAdicionalController.text.trim();
    if (valor.isEmpty) return;

    if (!RegExp(r'^\d{4}$').hasMatch(valor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El año adicional debe tener 4 dígitos (ej: 2011).')),
      );
      return;
    }

    setState(() {
      if (!_aniosAdicionales.contains(valor)) _aniosAdicionales.add(valor);
      _anioAdicionalController.clear();
    });
  }

  void _quitarAnioAdicional(String anio) {
    setState(() => _aniosAdicionales.remove(anio));
  }

  // ✅ NUEVO: convocados visibles según el texto del buscador (nombre,
  // apellido o N° de socio). No toca `_convocados` ni `_presentes`.
  List<Map<String, dynamic>> get _convocadosVisibles {
    final q = _filtroConvocados.trim().toLowerCase();
    if (q.isEmpty) return _convocados;
    return _convocados.where((s) {
      final texto = '${s['apellido'] ?? ''} ${s['nombre'] ?? ''} ${s['numero_socio'] ?? ''}'.toLowerCase();
      return texto.contains(q);
    }).toList();
  }

  int get _totalPresentes => _presentes.values.where((v) => v).length;

  String _iniciales(String? nombre, String? apellido) {
    final a = (apellido ?? '').trim();
    final n = (nombre ?? '').trim();
    final ai = a.isNotEmpty ? a[0] : '';
    final ni = n.isNotEmpty ? n[0] : '';
    final res = (ai + ni).toUpperCase();
    return res.isEmpty ? '?' : res;
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
        anioNacimiento: _anioNacimiento ?? '',
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
    _buscarInvitadoController.dispose();
    _anioAdicionalController.dispose(); // ✅ NUEVO
    _buscarConvocadoController.dispose(); // ✅ NUEVO
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
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('Registrar asistencia'),
        actions: [
          IconButton(
            tooltip: 'Ver reporte de asistencia',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: _abrirReporte,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepper(),
            Expanded(
              child: _pasoDatos ? _buildPasoDatos() : _buildPasoLista(),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NUEVO: indicador de paso 1/2, para que quede claro dónde está parado.
  Widget _buildStepper() {
    final primary = Theme.of(context).colorScheme.primary;

    Widget pill(String texto, bool activo) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: activo ? primary : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: activo ? Colors.white : Colors.black45,
            ),
          ),
        );

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          pill('1. Datos', _pasoDatos),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.black.withOpacity(0.08),
            ),
          ),
          pill('2. Convocados', !_pasoDatos),
        ],
      ),
    );
  }

  Widget _seccionCard({required String titulo, IconData? icono, required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icono != null) ...[
                Icon(icono, size: 16, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
              ],
              Text(
                titulo,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildPasoDatos() {
    return Column(
      children: [
        Expanded(child: _buildPasoDatosLista()),
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
              onPressed: _buscando ? null : _buscarConvocados,
              child: _buscando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Buscar socios ▶'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasoDatosLista() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      children: [
        _seccionCard(
          titulo: 'Tipo y fecha',
          icono: Icons.event_note_outlined,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _tipo,
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'entrenamiento', child: Text('🏋️ Entrenamiento')),
                  DropdownMenuItem(value: 'partido', child: Text('🏆 Partido')),
                ],
                onChanged: (v) => setState(() => _tipo = v ?? _tipo),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.black.withOpacity(0.12)),
                ),
                tileColor: Colors.transparent,
                title: const Text('Fecha', style: TextStyle(fontSize: 13)),
                subtitle: Text(
                  '${_fecha.day.toString().padLeft(2, '0')}/${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.calendar_today, size: 18),
                onTap: _elegirFecha,
              ),
            ],
          ),
        ),
        _seccionCard(
          titulo: 'Actividad y categoría',
          icono: Icons.sports_soccer_outlined,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _actividad,
                decoration: const InputDecoration(labelText: 'Actividad', border: OutlineInputBorder(), isDense: true),
                items: _actividades
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => _onActividadChanged(v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _actividadAdicional,
                decoration: const InputDecoration(
                  labelText: 'Actividad adicional (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: _actividadesAdicionales
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setState(() => _actividadAdicional = v),
              ),
              const SizedBox(height: 10),
              // ✅ NUEVO: la Categoría depende de la Actividad elegida arriba
              // (solo muestra categorías que tienen socios en esa actividad).
              DropdownButtonFormField<String>(
                value: _categoria,
                decoration: InputDecoration(
                  labelText: 'Categoría',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: _actividad == null
                      ? 'Elegí una actividad primero'
                      : (_cargandoCategorias ? 'Cargando categorías...' : null),
                  suffixIcon: _cargandoCategorias
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                items: _categoriasDisponibles
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (_actividad == null || _cargandoCategorias) ? null : (v) => _onCategoriaChanged(v),
              ),
            ],
          ),
        ),
        _seccionCard(
          titulo: 'Ampliar búsqueda (opcional)',
          icono: Icons.filter_alt_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoriasAdicionales(),
              const SizedBox(height: 14),
              // ✅ NUEVO: "Año de nacimiento" pasó de número libre a un
              // selector con los años que efectivamente tienen socios en la
              // actividad + categoría elegidas arriba.
              DropdownButtonFormField<String>(
                value: _anioNacimiento,
                decoration: InputDecoration(
                  labelText: 'Año de nacimiento (opcional)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: _categoria == null
                      ? 'Elegí actividad y categoría'
                      : (_cargandoAnios ? 'Cargando años...' : 'Todos los años'),
                  suffixIcon: _cargandoAnios
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                items: _aniosDisponibles
                    .map((a) => DropdownMenuItem(value: a.toString(), child: Text(a.toString())))
                    .toList(),
                onChanged: (_categoria == null || _cargandoAnios) ? null : (v) => setState(() => _anioNacimiento = v),
              ),
              const SizedBox(height: 14),
              _buildAniosAdicionales(),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ NUEVO: chips de categorías adicionales, directo en el formulario
  // principal (sin bloque plegable). Usa el color del club para que se vea
  // consistente con el resto de los botones/chips de la app.
  Widget _buildCategoriasAdicionales() {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Categorías adicionales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (_actividad == null)
          const Text('Elegí una actividad primero', style: TextStyle(fontSize: 12, color: Colors.black45))
        else if (_categoriasDisponibles.isEmpty)
          Text(
            _cargandoCategorias ? 'Cargando categorías...' : 'Sin categorías para esta actividad',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          )
        else
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _categoriasDisponibles.map((c) {
            final seleccionada = _categoriasAdicionales.contains(c);
            return FilterChip(
              label: Text(c),
              selected: seleccionada,
              onSelected: (_) => _toggleCategoriaAdicional(c),
              selectedColor: primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: seleccionada ? Colors.white : Colors.black87,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ✅ NUEVO: chips de años de nacimiento adicionales, directo en el
  // formulario principal (sin bloque plegable).
  Widget _buildAniosAdicionales() {
    final primary = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Años de nacimiento adicionales', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _anioAdicionalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Ej: 2011',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _agregarAnioAdicional(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _agregarAnioAdicional,
              child: const Text('+ Agregar'),
            ),
          ],
        ),
        if (_aniosAdicionales.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _aniosAdicionales.map((anio) {
              return Chip(
                label: Text(anio),
                backgroundColor: primary,
                labelStyle: const TextStyle(color: Colors.white),
                deleteIconColor: Colors.white,
                onDeleted: () => _quitarAnioAdicional(anio),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildPasoLista() {
    final primary = Theme.of(context).colorScheme.primary;
    final visibles = _convocadosVisibles;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_tipo == 'partido' ? '🏆 Partido' : '🏋️ Entrenamiento'} · $_actividad · $_categoria'
                  '${_actividadAdicional != null ? ' · $_actividadAdicional' : ''}'
                  '${_categoriasAdicionales.isNotEmpty ? ' (+ ${_categoriasAdicionales.join(', ')})' : ''}'
                  '${_aniosAdicionales.isNotEmpty ? ' · años ${_aniosAdicionales.join(', ')}' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
            children: [
              if (_convocados.isNotEmpty) ...[
                TextField(
                  controller: _buscarConvocadoController,
                  decoration: InputDecoration(
                    hintText: 'Filtrar convocados por nombre o N°...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (v) => setState(() => _filtroConvocados = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$_totalPresentes de ${_convocados.length} presentes',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primary),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        for (final s in _convocados) {
                          _presentes[s['id'].toString()] = true;
                        }
                      }),
                      child: const Text('Marcar todos', style: TextStyle(fontSize: 12.5)),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        for (final s in _convocados) {
                          _presentes[s['id'].toString()] = false;
                        }
                      }),
                      child: const Text('Ninguno', style: TextStyle(fontSize: 12.5)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (_convocados.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay socios que coincidan con esos filtros.'),
                )
              else if (visibles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Ningún convocado coincide con esa búsqueda.'),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: Column(
                    children: visibles.map((s) {
                      final id = s['id'].toString();
                      final categoria = s['categoria']?.toString();
                      final presente = _presentes[id] ?? false;
                      return CheckboxListTile(
                        value: presente,
                        onChanged: (v) => setState(() => _presentes[id] = v ?? false),
                        secondary: CircleAvatar(
                          radius: 16,
                          backgroundColor: primary.withOpacity(0.12),
                          child: Text(
                            _iniciales(s['nombre']?.toString(), s['apellido']?.toString()),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
                          ),
                        ),
                        title: Text('${s['apellido']}, ${s['nombre']}', style: const TextStyle(fontSize: 13.5)),
                        subtitle: Text(
                          'N° ${s['numero_socio'] ?? '-'}${categoria != null && categoria.isNotEmpty ? ' · $categoria' : ''}',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        controlAffinity: ListTileControlAffinity.trailing,
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 22),
              Text(
                'Invitados de otra categoría (${_invitados.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _buscarInvitadoController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o DNI',
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              if (_resultadosInvitado.isNotEmpty)
                ..._resultadosInvitado.map((s) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${s['apellido']}, ${s['nombre']}'),
                      subtitle: Text(s['categoria']?.toString() ?? ''),
                      trailing: TextButton(
                        onPressed: () => _agregarInvitado(s),
                        child: const Text('+ Agregar'),
                      ),
                    )),
              if (_invitados.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
