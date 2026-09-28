import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

/// Reporte de asistencia (versión app), equivalente simplificado a la
/// tarjeta "Asistencia a Entrenamientos y Partidos" del panel web
/// (backend/public/sections/reportes.html + backend/public/js/reportes.js).
///
/// Muestra, para una Actividad + Categoría de un mes, la lista de
/// entrenamientos/partidos cargados con su cantidad de presentes/ausentes,
/// permite ver el detalle de cada evento (y eliminarlo o agregar un socio
/// que faltó cargar), y buscar el historial de asistencia de un socio.
class AsistenciaReporteScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const AsistenciaReporteScreen({
    super.key,
    required this.token,
    required this.clubId,
  });

  @override
  State<AsistenciaReporteScreen> createState() => _AsistenciaReporteScreenState();
}

class _AsistenciaReporteScreenState extends State<AsistenciaReporteScreen> {
  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  final _buscarSocioController = TextEditingController();

  bool _cargandoListas = true;
  List<String> _actividades = [];
  List<String> _actividadesAdicionales = [];

  // ✅ NUEVO: cascada Actividad -> Categoría -> Año de nacimiento, basada
  // en los eventos de asistencia ya cargados (no en los socios), igual
  // que en la web (backend/public/js/reportes.js). Solo ofrece elegir
  // combinaciones que efectivamente tienen algún entrenamiento o partido
  // registrado.
  List<String> _categoriasDisponibles = [];
  bool _cargandoCategorias = false;

  List<int> _aniosDisponibles = [];
  String? _anioNacimiento;
  bool _cargandoAnios = false;

  String? _actividad;
  String? _categoria;
  String? _actividadAdicional;

  late int _anio;
  late int _mes;

  bool _cargandoMes = false;
  String? _errorMes;
  List<Map<String, dynamic>> _eventosRaw = [];
  List<Map<String, dynamic>> _sociosRaw = [];

  bool _mostrarSoloEntrenamientos = false;
  bool _mostrarSoloPartidos = false;

  bool _buscandoSocio = false;
  List<Map<String, dynamic>> _resultadosSocio = [];
  String? _socioSeleccionadoId;
  String? _socioSeleccionadoNombre;
  List<Map<String, dynamic>> _historialSocio = [];
  bool _cargandoHistorial = false;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _anio = ahora.year;
    _mes = ahora.month;
    _cargarListas();
  }

  @override
  void dispose() {
    _buscarSocioController.dispose();
    super.dispose();
  }

  Future<void> _cargarListas() async {
    try {
      final actividades = await AdminApiService.getActividadesDisponiblesAsistencia(token: widget.token, clubId: widget.clubId);
      final adicionales = await AdminApiService.getActividadesAdicionalesNombres(token: widget.token, clubId: widget.clubId);
      if (!mounted) return;
      setState(() {
        _actividades = actividades;
        _actividadesAdicionales = adicionales;
        _cargandoListas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoListas = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando filtros: $e')));
    }
  }

  // ✅ NUEVO: al elegir Actividad, la Categoría (y el año) quedan
  // obsoletos; se resetean y se traen en cascada solo las categorías que
  // ya tienen algún entrenamiento o partido cargado en esa actividad.
  Future<void> _onActividadChanged(String? actividad) async {
    setState(() {
      _actividad = actividad;
      _categoria = null;
      _categoriasDisponibles = [];
      _anioNacimiento = null;
      _aniosDisponibles = [];
    });
    _cargarMes();

    if (actividad == null || actividad.isEmpty) return;

    setState(() => _cargandoCategorias = true);
    try {
      final categorias = await AdminApiService.getCategoriasDisponiblesAsistencia(
        token: widget.token,
        clubId: widget.clubId,
        actividad: actividad,
      );
      if (!mounted) return;
      setState(() => _categoriasDisponibles = categorias);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando categorías: $e')));
    } finally {
      if (mounted) setState(() => _cargandoCategorias = false);
    }
  }

  // ✅ NUEVO: al elegir Categoría (con Actividad ya elegida), trae solo los
  // años que ya tienen algún entrenamiento o partido cargado en esa
  // combinación de actividad + categoría.
  Future<void> _onCategoriaChanged(String? categoria) async {
    setState(() {
      _categoria = categoria;
      _anioNacimiento = null;
      _aniosDisponibles = [];
    });
    _cargarMes();

    if (_actividad == null || categoria == null || categoria.isEmpty) return;

    setState(() => _cargandoAnios = true);
    try {
      final anios = await AdminApiService.getAniosDisponiblesAsistencia(
        token: widget.token,
        clubId: widget.clubId,
        actividad: _actividad!,
        categoria: categoria,
      );
      if (!mounted) return;
      setState(() => _aniosDisponibles = anios);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando años: $e')));
    } finally {
      if (mounted) setState(() => _cargandoAnios = false);
    }
  }

  Future<void> _cargarMes() async {
    if (_actividad == null || _categoria == null) {
      setState(() {
        _eventosRaw = [];
        _sociosRaw = [];
        _errorMes = null;
      });
      return;
    }

    setState(() {
      _cargandoMes = true;
      _errorMes = null;
      _mostrarSoloEntrenamientos = false;
      _mostrarSoloPartidos = false;
    });

    try {
      final data = await AdminApiService.getAsistenciaMatrizMes(
        token: widget.token,
        clubId: widget.clubId,
        anio: _anio,
        mes: _mes,
        actividad: _actividad!,
        categoria: _categoria!,
        actividadAdicional: _actividadAdicional,
        anioNacimiento: _anioNacimiento ?? '',
      );
      if (!mounted) return;
      setState(() {
        _eventosRaw = List<Map<String, dynamic>>.from(data['eventos'] ?? []);
        _sociosRaw = List<Map<String, dynamic>>.from(data['socios'] ?? []);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMes = e.toString());
    } finally {
      if (mounted) setState(() => _cargandoMes = false);
    }
  }

  void _cambiarMes(int delta) {
    setState(() {
      var nuevoMes = _mes + delta;
      var nuevoAnio = _anio;
      if (nuevoMes > 12) { nuevoMes = 1; nuevoAnio++; }
      if (nuevoMes < 1) { nuevoMes = 12; nuevoAnio--; }
      _mes = nuevoMes;
      _anio = nuevoAnio;
    });
    _cargarMes();
  }

  List<Map<String, dynamic>> get _eventosFiltrados {
    if (!_mostrarSoloEntrenamientos && !_mostrarSoloPartidos) return _eventosRaw;
    return _eventosRaw.where((ev) {
      final tipo = ev['tipo']?.toString();
      return (_mostrarSoloEntrenamientos && tipo == 'entrenamiento') ||
          (_mostrarSoloPartidos && tipo == 'partido');
    }).toList();
  }

  // Para cada evento visible, cuenta presentes/ausentes recorriendo las
  // celdas de todos los socios (mismo cálculo que hace la web, pero acá
  // agregado por evento en vez de por socio).
  Map<String, List<int>> get _conteoPorEvento {
    final mapa = <String, List<int>>{};
    for (final ev in _eventosFiltrados) {
      final id = ev['id'].toString();
      var presentes = 0;
      var ausentes = 0;
      for (final s in _sociosRaw) {
        final celdas = Map<String, dynamic>.from(s['celdas'] ?? {});
        if (!celdas.containsKey(id)) continue;
        if (celdas[id] == true) {
          presentes++;
        } else {
          ausentes++;
        }
      }
      mapa[id] = [presentes, ausentes];
    }
    return mapa;
  }

  Future<void> _buscarSocio() async {
    final q = _buscarSocioController.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _buscandoSocio = true;
      _socioSeleccionadoId = null;
      _historialSocio = [];
    });

    try {
      final resultados = await AdminApiService.buscarSocioAsistReporte(
        token: widget.token,
        clubId: widget.clubId,
        query: q,
      );
      if (!mounted) return;
      setState(() => _resultadosSocio = resultados);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _buscandoSocio = false);
    }
  }

  Future<void> _verHistorialSocio(Map<String, dynamic> socio) async {
    setState(() {
      _socioSeleccionadoId = socio['id'].toString();
      _socioSeleccionadoNombre = '${socio['apellido']}, ${socio['nombre']}';
      _cargandoHistorial = true;
      _historialSocio = [];
    });

    try {
      final historial = await AdminApiService.getHistorialAsistSocio(
        token: widget.token,
        clubId: widget.clubId,
        socioId: socio['id'].toString(),
      );
      if (!mounted) return;
      setState(() => _historialSocio = historial);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _cargandoHistorial = false);
    }
  }

  String _fechaDMY(String? fecha) {
    if (fecha == null || fecha.length < 10) return fecha ?? '';
    final soloFecha = fecha.substring(0, 10);
    final partes = soloFecha.split('-');
    if (partes.length != 3) return fecha;
    return '${partes[2]}/${partes[1]}/${partes[0]}';
  }

  Future<void> _abrirDetalleEvento(Map<String, dynamic> evento) async {
    final scaffold = ScaffoldMessenger.of(context);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => _DetalleEventoSheet(
        token: widget.token,
        clubId: widget.clubId,
        evento: evento,
        fechaLabel: _fechaDMY(evento['fecha']?.toString()),
        onEliminado: () {
          Navigator.of(ctx).pop();
          scaffold.showSnackBar(const SnackBar(content: Text('Evento eliminado')));
          _cargarMes();
        },
        onSocioAgregado: () => _cargarMes(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_cargandoListas) {
      return Scaffold(
        appBar: AppBar(title: const Text('Reporte de asistencia')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final eventos = _eventosFiltrados;
    final conteo = _conteoPorEvento;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(title: const Text('Reporte de asistencia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          _card(
            titulo: 'Filtros',
            icono: Icons.filter_alt_outlined,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _actividad,
                  decoration: const InputDecoration(labelText: 'Actividad', border: OutlineInputBorder(), isDense: true),
                  items: _actividades.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                  onChanged: (v) => _onActividadChanged(v),
                ),
                const SizedBox(height: 10),
                // ✅ NUEVO: la Categoría depende de la Actividad elegida
                // arriba (solo categorías con socios en esa actividad).
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
                  items: _categoriasDisponibles.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (_actividad == null || _cargandoCategorias) ? null : (v) => _onCategoriaChanged(v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _actividadAdicional,
                  decoration: const InputDecoration(labelText: 'Actividad adicional (opcional)', border: OutlineInputBorder(), isDense: true),
                  items: _actividadesAdicionales.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                  onChanged: (v) {
                    setState(() => _actividadAdicional = v);
                    _cargarMes();
                  },
                ),
                const SizedBox(height: 10),
                // ✅ NUEVO: "Año de nacimiento" pasó de número libre a un
                // selector con los años que tienen socios en la actividad +
                // categoría elegidas arriba.
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
                  items: _aniosDisponibles.map((a) => DropdownMenuItem(value: a.toString(), child: Text(a.toString()))).toList(),
                  onChanged: (_categoria == null || _cargandoAnios)
                      ? null
                      : (v) {
                          setState(() => _anioNacimiento = v);
                          _cargarMes();
                        },
                ),
              ],
            ),
          ),

          _card(
            titulo: 'Entrenamientos y partidos del mes',
            icono: Icons.calendar_month_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => _cambiarMes(-1), icon: const Icon(Icons.chevron_left)),
                    Expanded(
                      child: Text(
                        '${_meses[_mes - 1]} $_anio',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    IconButton(onPressed: () => _cambiarMes(1), icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                if (_actividad == null || _categoria == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Seleccioná Actividad y Categoría para ver los entrenamientos/partidos del mes.',
                      style: TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                  )
                else if (_cargandoMes)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_errorMes != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_errorMes!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
                  )
                else if (_eventosRaw.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No hay entrenamientos ni partidos cargados este mes para esos filtros.',
                      style: TextStyle(color: Colors.black54, fontSize: 12.5),
                    ),
                  )
                else ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('🏋️ Entrenamientos'),
                        selected: _mostrarSoloEntrenamientos,
                        onSelected: (v) => setState(() => _mostrarSoloEntrenamientos = v),
                        selectedColor: const Color(0xFFDCFCE7),
                      ),
                      FilterChip(
                        label: const Text('🏆 Partidos'),
                        selected: _mostrarSoloPartidos,
                        onSelected: (v) => setState(() => _mostrarSoloPartidos = v),
                        selectedColor: const Color(0xFFFFF7ED),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (eventos.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Ningún evento coincide con ese filtro.', style: TextStyle(color: Colors.black54, fontSize: 12.5)),
                    )
                  else
                    ...eventos.map((ev) {
                      final id = ev['id'].toString();
                      final esPartido = ev['tipo']?.toString() == 'partido';
                      final conteoEv = conteo[id] ?? [0, 0];
                      final total = conteoEv[0] + conteoEv[1];
                      final ratio = total == 0 ? 0.0 : conteoEv[0] / total;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black.withOpacity(0.08)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          onTap: () => _abrirDetalleEvento(ev),
                          leading: CircleAvatar(
                            backgroundColor: esPartido ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                            child: Text(esPartido ? '🏆' : '🏋️', style: const TextStyle(fontSize: 16)),
                          ),
                          title: Text(_fechaDMY(ev['fecha']?.toString()), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 5,
                                backgroundColor: const Color(0xFFFEE2E2),
                                valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
                              ),
                            ),
                          ),
                          trailing: Text(
                            '${conteoEv[0]}✔ / ${conteoEv[1]}✘',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),

          _card(
            titulo: 'Buscar historial por socio',
            icono: Icons.person_search_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _buscarSocioController,
                        decoration: const InputDecoration(
                          hintText: 'Nombre, apellido, DNI o N° de socio...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _buscarSocio(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _buscandoSocio ? null : _buscarSocio,
                      child: _buscandoSocio
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Buscar'),
                    ),
                  ],
                ),
                if (_resultadosSocio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._resultadosSocio.map((s) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${s['apellido']}, ${s['nombre']}', style: const TextStyle(fontSize: 13.5)),
                        subtitle: Text('${s['categoria'] ?? ''} · N° ${s['numero_socio'] ?? '-'}', style: const TextStyle(fontSize: 11.5)),
                        onTap: () => _verHistorialSocio(s),
                      )),
                ],
                if (_socioSeleccionadoId != null) ...[
                  const Divider(),
                  Text(_socioSeleccionadoNombre ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (_cargandoHistorial)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
                  else if (_historialSocio.isEmpty)
                    const Text('Este socio no tiene asistencias registradas.', style: TextStyle(color: Colors.black54, fontSize: 12.5))
                  else
                    ..._historialSocio.map((h) {
                      final presente = h['presente'] == true;
                      final esPartido = h['tipo']?.toString() == 'partido';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_fechaDMY(h['fecha']?.toString())} · ${esPartido ? 'Partido' : 'Entren.'} · ${h['actividad']} (${h['categoria']})',
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            Text(
                              presente ? '✔ Presente' : '✘ Ausente',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: presente ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String titulo, required IconData icono, required Widget child}) {
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
              Icon(icono, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(titulo, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// Bottom sheet de detalle de un evento: presentes / ausentes / invitados,
/// eliminar evento, y agregar un socio que faltó cargar.
class _DetalleEventoSheet extends StatefulWidget {
  final String token;
  final String clubId;
  final Map<String, dynamic> evento;
  final String fechaLabel;
  final VoidCallback onEliminado;
  final VoidCallback onSocioAgregado;

  const _DetalleEventoSheet({
    required this.token,
    required this.clubId,
    required this.evento,
    required this.fechaLabel,
    required this.onEliminado,
    required this.onSocioAgregado,
  });

  @override
  State<_DetalleEventoSheet> createState() => _DetalleEventoSheetState();
}

class _DetalleEventoSheetState extends State<_DetalleEventoSheet> {
  final _buscarController = TextEditingController();

  bool _cargando = true;
  String? _error;
  Map<String, dynamic>? _eventoInfo;
  // ✅ NUEVO: estado local de edición. Cada item tiene _quitar (marcado
  // para sacar, todavía no confirmado) y _nuevo (agregado en esta misma
  // edición, todavía no existe en el servidor). No se manda nada al
  // servidor hasta que el usuario aprieta "Guardar cambios".
  List<Map<String, dynamic>> _items = [];
  bool _eliminando = false;
  bool _buscandoParaAgregar = false;
  List<Map<String, dynamic>> _resultadosAgregar = [];
  // ✅ NUEVO: si hay cambios locales sin guardar.
  bool _dirty = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  @override
  void dispose() {
    _buscarController.dispose();
    super.dispose();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final data = await AdminApiService.getAsistenciaDetalleEvento(
        token: widget.token,
        clubId: widget.clubId,
        eventoId: widget.evento['id'].toString(),
      );
      if (!mounted) return;
      setState(() {
        _eventoInfo = data['evento'];
        _items = List<Map<String, dynamic>>.from(data['detalle'] ?? [])
            .map((d) => {...d, '_quitar': false, '_nuevo': false})
            .toList();
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _confirmarEliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text('¿Seguro que querés eliminar este evento de asistencia? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _eliminando = true);
    try {
      await AdminApiService.eliminarEventoAsistencia(
        token: widget.token,
        clubId: widget.clubId,
        eventoId: widget.evento['id'].toString(),
      );
      widget.onEliminado();
    } catch (e) {
      if (!mounted) return;
      setState(() => _eliminando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _buscarParaAgregar() async {
    final q = _buscarController.text.trim();
    if (q.isEmpty) return;
    setState(() => _buscandoParaAgregar = true);
    try {
      // ✅ No se filtran los socios ya cargados: si el usuario elige uno
      // que ya está en el evento, _agregarSocioLocal le pregunta si
      // quiere cambiarle la condición presente/ausente en vez de fallar.
      final resultados = await AdminApiService.buscarSocios(token: widget.token, clubId: widget.clubId, query: q);
      if (!mounted) return;
      setState(() => _resultadosAgregar = resultados);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _buscandoParaAgregar = false);
    }
  }

  // ✅ NUEVO: agrega (o reactiva, o ajusta) un socio en el estado local
  // de edición. No pega al servidor hasta "Guardar cambios". Si el
  // socio ya estaba cargado en el evento, en vez de tirar error
  // pregunta si se le quiere cambiar la condición presente/ausente.
  Future<void> _agregarSocioLocal(Map<String, dynamic> socio) async {
    final socioId = socio['id'].toString();
    final index = _items.indexWhere((d) => (d['socio_id'] ?? d['id']).toString() == socioId);

    if (index != -1) {
      final existente = _items[index];

      if (existente['_quitar'] == true) {
        setState(() {
          _items[index] = {...existente, '_quitar': false};
          _dirty = true;
        });
        return;
      }

      final presenteActual = existente['presente'] == true;
      final estadoActual = presenteActual ? 'Presente' : 'Ausente';
      final estadoNuevo = presenteActual ? 'Ausente' : 'Presente';
      final cambiar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Socio ya cargado'),
          content: Text('${socio['apellido']}, ${socio['nombre']} ya está cargado como $estadoActual. ¿Querés cambiarlo a $estadoNuevo?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text('Cambiar a $estadoNuevo')),
          ],
        ),
      );
      if (cambiar == true) {
        setState(() {
          _items[index] = {...existente, 'presente': !presenteActual};
          _dirty = true;
        });
      }
      return;
    }

    setState(() {
      _items.add({
        'socio_id': socio['id'],
        'nombre': socio['nombre'],
        'apellido': socio['apellido'],
        'categoria_socio': _eventoInfo?['categoria'],
        'origen': 'convocado',
        'presente': true,
        '_quitar': false,
        '_nuevo': true,
      });
      _dirty = true;
    });
    _buscarController.clear();
    setState(() => _resultadosAgregar = []);
  }

  // ✅ NUEVO: marca/desmarca localmente a un socio para quitarlo del
  // evento. No pega al servidor hasta "Guardar cambios".
  void _toggleQuitarSocio(Map<String, dynamic> detalle) {
    final socioId = (detalle['socio_id'] ?? detalle['id']).toString();
    final index = _items.indexWhere((d) => (d['socio_id'] ?? d['id']).toString() == socioId);
    if (index == -1) return;
    setState(() {
      _items[index] = {..._items[index], '_quitar': !(_items[index]['_quitar'] == true)};
      _dirty = true;
    });
  }

  // ✅ NUEVO: manda TODOS los cambios pendientes (quitar / agregar /
  // cambiar presente-ausente) juntos, en un solo pedido al servidor.
  Future<void> _guardarCambios() async {
    setState(() => _guardando = true);
    try {
      final quitar = _items
          .where((d) => d['_quitar'] == true && d['_nuevo'] != true)
          .map((d) => (d['socio_id'] ?? d['id']).toString())
          .toList();
      final agregarOModificar = _items
          .where((d) => d['_quitar'] != true)
          .map((d) => {
                'socioId': (d['socio_id'] ?? d['id']).toString(),
                'presente': d['presente'] == true,
              })
          .toList();

      await AdminApiService.guardarCambiosDetalleEventoAsistencia(
        token: widget.token,
        clubId: widget.clubId,
        eventoId: widget.evento['id'].toString(),
        quitar: quitar,
        agregarOModificar: agregarOModificar,
      );
      widget.onSocioAgregado();
      await _cargarDetalle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esPartido = widget.evento['tipo']?.toString() == 'partido';
    final convocados = _items.where((d) => d['origen'] == 'convocado').toList();
    final invitados = _items.where((d) => d['origen'] == 'invitado').toList();
    final presentes = convocados.where((d) => d['presente'] == true).toList();
    final ausentes = convocados.where((d) => d['presente'] != true).toList();
    final presentesActivos = presentes.where((d) => d['_quitar'] != true).length;
    final ausentesActivos = ausentes.where((d) => d['_quitar'] != true).length;
    final invitadosActivos = invitados.where((d) => d['_quitar'] != true).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                  : ListView(
                      controller: scrollController,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: esPartido ? const Color(0xFFFFF7ED) : const Color(0xFFF0FDF4),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      esPartido ? '🏆 Partido' : '🏋️ Entrenamiento',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: esPartido ? const Color(0xFFF97316) : const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${_eventoInfo?['actividad'] ?? ''}'
                                    '${(_eventoInfo?['actividad_adicional'] ?? '').toString().isNotEmpty ? ' + ${_eventoInfo?['actividad_adicional']}' : ''}'
                                    ' · ${_eventoInfo?['categoria'] ?? ''} · ${widget.fechaLabel}',
                                    style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _eliminando ? null : _confirmarEliminar,
                              icon: _eliminando
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _listaSocios('✔ Presentes ($presentesActivos)', const Color(0xFF16A34A), presentes)),
                            const SizedBox(width: 12),
                            Expanded(child: _listaSocios('✘ Ausentes ($ausentesActivos)', const Color(0xFFDC2626), ausentes)),
                          ],
                        ),
                        if (invitados.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Text('★ Invitados de otra categoría ($invitadosActivos)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                          const SizedBox(height: 6),
                          ...invitados.map((d) {
                            final quitado = d['_quitar'] == true;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Opacity(
                                opacity: quitado ? 0.5 : 1,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${d['apellido']}, ${d['nombre']} (${d['categoria_socio'] ?? ''})${d['_nuevo'] == true ? ' · nuevo' : ''}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          decoration: quitado ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _toggleQuitarSocio(d),
                                      icon: Icon(quitado ? Icons.undo : Icons.close, size: 16, color: quitado ? const Color(0xFF16A34A) : Colors.red),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        const Divider(height: 28),
                        Text('+ Agregar socio que faltó cargar', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _buscarController,
                                decoration: const InputDecoration(
                                  hintText: 'Buscar por nombre, apellido o DNI...',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _buscarParaAgregar(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _buscandoParaAgregar ? null : _buscarParaAgregar,
                              child: const Text('Buscar'),
                            ),
                          ],
                        ),
                        if (_resultadosAgregar.isNotEmpty)
                          ..._resultadosAgregar.map((s) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text('${s['apellido']}, ${s['nombre']}', style: const TextStyle(fontSize: 13)),
                                subtitle: Text(s['categoria']?.toString() ?? '', style: const TextStyle(fontSize: 11.5)),
                                trailing: TextButton(
                                  onPressed: () => _agregarSocioLocal(s),
                                  child: const Text('+ Agregar'),
                                ),
                              )),
                        const SizedBox(height: 12),
                        // ✅ NUEVO: barra de "Guardar cambios" / "Descartar",
                        // sólo visible mientras haya cambios locales sin guardar.
                        if (_dirty)
                          Container(
                            padding: const EdgeInsets.only(top: 12),
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: Color(0xFFEEF0F3))),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text('Tenés cambios sin guardar', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                ),
                                TextButton(
                                  onPressed: _guardando ? null : _cargarDetalle,
                                  child: const Text('Descartar'),
                                ),
                                const SizedBox(width: 6),
                                ElevatedButton.icon(
                                  onPressed: _guardando ? null : _guardarCambios,
                                  icon: _guardando
                                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.save, size: 16),
                                  label: const Text('Guardar cambios'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }

  Widget _listaSocios(String titulo, Color color, List<Map<String, dynamic>> lista) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: color)),
        const SizedBox(height: 6),
        if (lista.isEmpty)
          const Text('—', style: TextStyle(color: Colors.black38, fontSize: 12.5))
        else
          ...lista.map((d) {
            final quitado = d['_quitar'] == true;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Opacity(
                opacity: quitado ? 0.5 : 1,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${d['apellido']}, ${d['nombre']}${d['_nuevo'] == true ? ' · nuevo' : ''}',
                        style: TextStyle(
                          fontSize: 12.5,
                          decoration: quitado ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _toggleQuitarSocio(d),
                      icon: Icon(quitado ? Icons.undo : Icons.close, size: 16, color: quitado ? const Color(0xFF16A34A) : Colors.red),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
