import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class AgendaScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const AgendaScreen({super.key, required this.token, required this.clubId});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  bool _cargando = true;
  List<Map<String, dynamic>> _eventos = [];

  // Lunes de la semana que se está mostrando (sin horas/min/seg)
  late DateTime _lunesActual;

  @override
  void initState() {
    super.initState();
    _lunesActual = _lunesDeLaSemana(DateTime.now());
    _cargarAgenda();
  }

  DateTime _lunesDeLaSemana(DateTime d) {
    final soloFecha = DateTime(d.year, d.month, d.day);
    // DateTime.weekday: lunes=1 ... domingo=7
    return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
  }

  Future<void> _cargarAgenda() async {
    setState(() => _cargando = true);
    try {
      final data = await AdminApiService.getAgendaEventos(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() {
        _eventos = List<Map<String, dynamic>>.from(data['eventos'] ?? []);
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando agenda: $e')),
      );
    }
  }

  DateTime? _fechaDelEvento(Map<String, dynamic> e) {
    final raw = (e['date'] ?? e['start'])?.toString();
    if (raw == null || raw.length < 10) return null;
    return DateTime.tryParse(raw.substring(0, 10));
  }

  void _semanaAnterior() {
    setState(() => _lunesActual = _lunesActual.subtract(const Duration(days: 7)));
  }

  void _semanaSiguiente() {
    setState(() => _lunesActual = _lunesActual.add(const Duration(days: 7)));
  }

  void _irAHoy() {
    setState(() => _lunesActual = _lunesDeLaSemana(DateTime.now()));
  }

  Future<void> _nuevoEvento() async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NuevoEventoSheet(token: widget.token, clubId: widget.clubId),
    );
    if (creado == true) {
      await _cargarAgenda();
    }
  }

  static const List<String> _diasSemana = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  String _fmtDia(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  bool _esMismaFecha(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final domingo = _lunesActual.add(const Duration(days: 6));
    final tituloSemana = '${_fmtDia(_lunesActual)} — ${_fmtDia(domingo)} / ${domingo.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      floatingActionButton: FloatingActionButton(
        onPressed: _nuevoEvento,
        tooltip: 'Cargar evento',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            color: Colors.black.withOpacity(0.03),
            child: Row(
              children: [
                IconButton(onPressed: _semanaAnterior, icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(
                      tituloSemana,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(onPressed: _semanaSiguiente, icon: const Icon(Icons.chevron_right)),
                TextButton(onPressed: _irAHoy, child: const Text('Hoy')),
              ],
            ),
          ),
          Expanded(
            child: _cargando ? const Center(child: CircularProgressIndicator()) : _buildSemana(),
          ),
        ],
      ),
    );
  }

  Widget _buildSemana() {
    final dias = List.generate(7, (i) => _lunesActual.add(Duration(days: i)));

    return RefreshIndicator(
      onRefresh: _cargarAgenda,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        children: [
          for (int i = 0; i < 7; i++) _buildDia(dias[i], _diasSemana[i]),
        ],
      ),
    );
  }

  Widget _buildDia(DateTime dia, String nombreDia) {
    final eventosDelDia = _eventos.where((e) {
      final f = _fechaDelEvento(e);
      return f != null && _esMismaFecha(f, dia);
    }).toList();

    // Cumpleaños primero, luego actividades ordenadas por hora
    eventosDelDia.sort((a, b) {
      final kindA = (a['extendedProps']?['kind'] ?? '').toString();
      final kindB = (b['extendedProps']?['kind'] ?? '').toString();
      if (kindA != kindB) return kindA == 'cumple' ? -1 : 1;
      final hA = (a['extendedProps']?['hora_desde'] ?? '').toString();
      final hB = (b['extendedProps']?['hora_desde'] ?? '').toString();
      return hA.compareTo(hB);
    });

    final esHoy = _esMismaFecha(dia, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: esHoy ? Theme.of(context).colorScheme.primary : Colors.black.withOpacity(0.08),
          width: esHoy ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              '$nombreDia ${_fmtDia(dia)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: esHoy ? Theme.of(context).colorScheme.primary : Colors.black87,
              ),
            ),
          ),
          if (eventosDelDia.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text('Sin eventos', style: TextStyle(color: Colors.black45, fontSize: 12.5)),
            )
          else
            ...eventosDelDia.map(_buildEventoTile),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildEventoTile(Map<String, dynamic> e) {
    final props = Map<String, dynamic>.from(e['extendedProps'] ?? {});
    final esCumple = props['kind']?.toString() == 'cumple';

    if (esCumple) {
      final edad = props['edad'];
      return ListTile(
        dense: true,
        leading: const Text('🎂', style: TextStyle(fontSize: 18)),
        title: Text((e['title'] ?? '').toString()),
        subtitle: Text([
          if ((props['categoria'] ?? '').toString().isNotEmpty) props['categoria'].toString(),
          if ((props['actividad'] ?? '').toString().isNotEmpty) props['actividad'].toString(),
          if (edad != null) '$edad años',
        ].join(' · ')),
      );
    }

    final hd = (props['hora_desde'] ?? '').toString();
    final hh = (props['hora_hasta'] ?? '').toString();
    return ListTile(
      dense: true,
      leading: const Icon(Icons.event_note, color: Colors.green),
      title: Text(props['titulo']?.toString() ?? (e['title'] ?? '').toString()),
      subtitle: Text([
        if (hd.isNotEmpty && hh.isNotEmpty) '$hd - $hh',
        if ((props['descripcion'] ?? '').toString().isNotEmpty) props['descripcion'].toString(),
      ].join(' · ')),
    );
  }
}

// ======================================================
// Bottom sheet: cargar nuevo evento
// ======================================================
class _NuevoEventoSheet extends StatefulWidget {
  final String token;
  final String clubId;

  const _NuevoEventoSheet({required this.token, required this.clubId});

  @override
  State<_NuevoEventoSheet> createState() => _NuevoEventoSheetState();
}

class _NuevoEventoSheetState extends State<_NuevoEventoSheet> {
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();

  DateTime _fecha = DateTime.now();
  TimeOfDay _horaDesde = const TimeOfDay(hour: 18, minute: 0);
  TimeOfDay _horaHasta = const TimeOfDay(hour: 19, minute: 0);

  bool _guardando = false;

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _elegirHora(bool desde) async {
    final elegida = await showTimePicker(
      context: context,
      initialTime: desde ? _horaDesde : _horaHasta,
    );
    if (elegida != null) {
      setState(() {
        if (desde) {
          _horaDesde = elegida;
        } else {
          _horaHasta = elegida;
        }
      });
    }
  }

  String _fmtHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    final titulo = _tituloController.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá el título del evento')),
      );
      return;
    }

    final hd = _fmtHora(_horaDesde);
    final hh = _fmtHora(_horaHasta);
    if (hd.compareTo(hh) >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El horario "hasta" debe ser posterior al "desde"')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final fechaStr =
          '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';

      await AdminApiService.crearEventoAgenda(
        token: widget.token,
        clubId: widget.clubId,
        fecha: fechaStr,
        horaDesde: hd,
        horaHasta: hh,
        titulo: titulo,
        descripcion: _descripcionController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Evento cargado')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nuevo evento', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descripcionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
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
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Desde'),
                    subtitle: Text(_fmtHora(_horaDesde)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _elegirHora(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hasta'),
                    subtitle: Text(_fmtHora(_horaHasta)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _elegirHora(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar evento'),
            ),
          ],
        ),
      ),
    );
  }
}