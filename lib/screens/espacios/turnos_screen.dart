// lib/screens/espacios/turnos_screen.dart
//
// Turnos libres de un espacio: se elige el día y UNO O VARIOS horarios (hasta
// 6, también de distintos días), y se confirma con un comentario opcional.
// Cada horario queda como una reserva "pendiente" hasta que el club la acepte
// (el socio recibe una notificación con la respuesta).
import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/espacios_service.dart';
import 'espacios_utils.dart';
import 'mis_reservas_espacios_screen.dart';

class TurnosScreen extends StatefulWidget {
  final AppSession session;
  final Map<String, dynamic> recurso;

  const TurnosScreen({super.key, required this.session, required this.recurso});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  final _service = EspaciosService();

  bool _cargando = true;
  String? _error;
  List<Map<String, dynamic>> _dias = []; // solo días con al menos un turno libre
  String? _fechaSel;
  bool _enviando = false;

  /// Máximo de horarios que se pueden pedir de una vez (el backend también lo valida).
  static const int _maxTurnos = 6;

  /// Horarios elegidos: clave 'YYYY-MM-DD|HH:MM'. Se conservan al cambiar de día.
  final Set<String> _sel = <String>{};

  String get _recursoId => (widget.recurso['id'] ?? '').toString();
  String get _nombre => (widget.recurso['nombre'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final hoy = DateTime.now();
      final maxDias = (int.tryParse((widget.recurso['anticipacion_max_dias'] ?? '').toString()) ?? 30).clamp(1, 90).toInt();
      // El backend acepta hasta 31 días por consulta: se pide en tandas.
      final tandas = <Future<List<Map<String, dynamic>>>>[];
      var offset = 0;
      while (offset <= maxDias) {
        final fin = (offset + 13) > maxDias ? maxDias : offset + 13;
        tandas.add(_service.getTurnos(
          token: widget.session.token,
          recursoId: _recursoId,
          desde: fechaIso(hoy.add(Duration(days: offset))),
          hasta: fechaIso(hoy.add(Duration(days: fin))),
        ));
        offset = fin + 1;
      }
      final resultados = await Future.wait(tandas);
      final dias = resultados
          .expand((x) => x)
          .where((d) => ((d['turnos'] ?? []) as List).isNotEmpty)
          .toList()
        ..sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));
      if (!mounted) return;
      setState(() {
        _dias = dias;
        if (_fechaSel == null || !dias.any((d) => d['fecha'] == _fechaSel)) {
          _fechaSel = dias.isNotEmpty ? dias.first['fecha'] as String : null;
        }
        // Se descartan los horarios elegidos que ya no están libres
        final vigentes = <String>{
          for (final d in dias)
            for (final t in (d['turnos'] as List))
              _clave(d['fecha'] as String, (t as Map)['hora_desde']),
        };
        _sel.removeWhere((k) => !vigentes.contains(k));
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mensajeError(e);
        _cargando = false;
      });
    }
  }

  List<Map<String, dynamic>> get _turnosDelDia {
    final d = _dias.where((x) => x['fecha'] == _fechaSel);
    if (d.isEmpty) return [];
    return List<Map<String, dynamic>>.from(d.first['turnos'] as List);
  }

  String _clave(String fecha, dynamic horaDesde) => '$fecha|$horaDesde';

  int _cantidadElegidosDelDia(String fecha) => _sel.where((k) => k.startsWith('$fecha|')).length;

  void _alternar(String fecha, Map<String, dynamic> turno) {
    final k = _clave(fecha, turno['hora_desde']);
    setState(() {
      if (_sel.contains(k)) {
        _sel.remove(k);
      } else if (_sel.length >= _maxTurnos) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Podés pedir hasta $_maxTurnos horarios por vez.')),
        );
      } else {
        _sel.add(k);
      }
    });
  }

  /// Horarios elegidos, ordenados por día y hora: [{fecha, hora_desde, hora_hasta}].
  List<Map<String, String>> get _elegidos {
    final out = <Map<String, String>>[];
    for (final d in _dias) {
      final fecha = d['fecha'] as String;
      for (final t in (d['turnos'] as List)) {
        final m = t as Map;
        if (_sel.contains(_clave(fecha, m['hora_desde']))) {
          out.add({
            'fecha': fecha,
            'hora_desde': (m['hora_desde'] ?? '').toString(),
            'hora_hasta': (m['hora_hasta'] ?? '').toString(),
          });
        }
      }
    }
    return out;
  }

  Future<void> _reservar() async {
    final elegidos = _elegidos;
    if (elegidos.isEmpty || _enviando) return;
    final comentarioCtrl = TextEditingController();
    final horasCancel = widget.recurso['cancelar_hasta_horas'];

    // Resumen agrupado por día
    final porDia = <String, List<Map<String, String>>>{};
    for (final e in elegidos) {
      porDia.putIfAbsent(e['fecha']!, () => []).add(e);
    }
    final plural = elegidos.length > 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(plural ? 'Confirmar ${elegidos.length} horarios' : 'Confirmar reserva'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              for (final e in porDia.entries) ...[
                Text(fechaLarga(e.key), style: const TextStyle(fontWeight: FontWeight.w600)),
                for (final t in e.value) Text('  ${t['hora_desde']} a ${t['hora_hasta']}'),
                const SizedBox(height: 6),
              ],
              const SizedBox(height: 6),
              TextField(
                controller: comentarioCtrl,
                maxLength: 300,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Comentario para el club (opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${plural ? 'Cada horario queda como una solicitud pendiente' : 'La reserva queda pendiente'} hasta que el club la confirme. Te avisamos por notificación.'
                '${horasCancel != null ? ' Una vez confirmada, podés cancelarla hasta $horasCancel h antes.' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(plural ? 'Pedir ${elegidos.length} horarios' : 'Pedir turno'),
          ),
        ],
      ),
    );

    final comentario = comentarioCtrl.text;
    comentarioCtrl.dispose();
    if (ok != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      var creadas = 1;
      var fallidos = <Map<String, dynamic>>[];
      if (elegidos.length == 1) {
        final e = elegidos.first;
        await _service.crearReserva(
          token: widget.session.token,
          recursoId: _recursoId,
          fecha: e['fecha']!,
          horaDesde: e['hora_desde']!,
          comentario: comentario,
        );
      } else {
        final r = await _service.crearReservasMultiples(
          token: widget.session.token,
          recursoId: _recursoId,
          turnos: [
            for (final e in elegidos) {'fecha': e['fecha']!, 'hora_desde': e['hora_desde']!},
          ],
          comentario: comentario,
        );
        creadas = r.reservas.length;
        fallidos = r.fallidos;
      }
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _sel.clear();
      });

      final detalleFallidos = fallidos
          .map((f) => '• ${fechaCorta(f['fecha']?.toString())} ${f['hora_desde']}: ${f['error'] ?? 'no se pudo pedir'}')
          .join('\n');
      final base = creadas > 1
          ? 'Enviamos $creadas solicitudes. Te avisamos cuando el club las confirme.'
          : 'Tu reserva quedó pendiente. Te avisamos cuando el club la confirme.';
      final mensaje = fallidos.isEmpty
          ? base
          : '$base\n\nNo se pudieron pedir estos horarios:\n$detalleFallidos';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(fallidos.isEmpty ? '¡Pedido enviado!' : 'Pedido enviado con avisos'),
          content: Text(mensaje),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Listo')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MisReservasEspaciosScreen(session: widget.session)),
                );
              },
              child: const Text('Ver mis reservas'),
            ),
          ],
        ),
      );
      if (mounted) _cargar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensajeError(e))));
      _cargar(); // por si algún turno ya lo tomó otra persona
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget cuerpo;
    if (_cargando) {
      cuerpo = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      cuerpo = EstadoError(mensaje: _error!, onReintentar: _cargar);
    } else if (_dias.isEmpty) {
      cuerpo = const EstadoVacio(
        icon: Icons.event_busy,
        texto: 'No hay turnos libres en los próximos días. Probá más adelante.',
      );
    } else {
      final turnos = _turnosDelDia;
      cuerpo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Elegí el día', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _dias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _dias[i]['fecha'] as String;
                final sel = f == _fechaSel;
                final partes = fechaCorta(f).split(' '); // ["Lun", "26/10"]
                final cantSel = _cantidadElegidosDelDia(f);
                return GestureDetector(
                  onTap: () => setState(() => _fechaSel = f),
                  child: Container(
                    width: 68,
                    decoration: BoxDecoration(
                      color: sel ? scheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: sel ? scheme.primary : Colors.black12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(partes.first,
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: sel ? scheme.onPrimary : Colors.black87)),
                        const SizedBox(height: 2),
                        Text(partes.length > 1 ? partes[1] : '',
                            style: TextStyle(fontSize: 12, color: sel ? scheme.onPrimary : Colors.black54)),
                        if (cantSel > 0) ...[
                          const SizedBox(height: 2),
                          Text('$cantSel ✓',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: sel ? scheme.onPrimary : scheme.primary)),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
            child: Text(
              _fechaSel == null ? 'Horarios libres' : 'Horarios libres · ${fechaLarga(_fechaSel)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Podés elegir más de un horario (hasta $_maxTurnos), también de otros días.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: turnos.map((t) {
                  final fecha = _fechaSel ?? '';
                  final elegido = _sel.contains(_clave(fecha, t['hora_desde']));
                  final texto = '${t['hora_desde']} - ${t['hora_hasta']}';
                  return elegido
                      ? FilledButton.icon(
                          onPressed: _enviando ? null : () => _alternar(fecha, t),
                          icon: const Icon(Icons.check, size: 18),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          label: Text(texto),
                        )
                      : OutlinedButton(
                          onPressed: _enviando ? null : () => _alternar(fecha, t),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            side: BorderSide(color: scheme.primary),
                          ),
                          child: Text(texto),
                        );
                }).toList(),
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: Text(_nombre),
      ),
      bottomNavigationBar: _sel.isEmpty || _cargando
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _sel.length == 1 ? '1 horario elegido' : '${_sel.length} horarios elegidos',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: _enviando ? null : () => setState(_sel.clear),
                      child: const Text('Limpiar'),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: _enviando ? null : _reservar,
                      child: Text(_sel.length == 1 ? 'Continuar' : 'Pedir ${_sel.length}'),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: cuerpo),
            if (_enviando)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x55FFFFFF),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
