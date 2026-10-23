// lib/screens/espacios/turnos_screen.dart
//
// Turnos libres de un espacio: se elige el día y el horario, y se confirma
// con un comentario opcional. La reserva queda "pendiente" hasta que el club
// la acepte (el socio recibe una notificación con la respuesta).
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

  Future<void> _reservar(Map<String, dynamic> turno) async {
    final fecha = _fechaSel;
    if (fecha == null || _enviando) return;
    final comentarioCtrl = TextEditingController();
    final horasCancel = widget.recurso['cancelar_hasta_horas'];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('${fechaLarga(fecha)} · ${turno['hora_desde']} a ${turno['hora_hasta']}'),
              const SizedBox(height: 12),
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
                'La reserva queda pendiente hasta que el club la confirme. Te avisamos por notificación.'
                '${horasCancel != null ? ' Una vez confirmada, podés cancelarla hasta $horasCancel h antes.' : ''}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pedir turno')),
        ],
      ),
    );

    final comentario = comentarioCtrl.text;
    comentarioCtrl.dispose();
    if (ok != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      await _service.crearReserva(
        token: widget.session.token,
        recursoId: _recursoId,
        fecha: fecha,
        horaDesde: (turno['hora_desde'] ?? '').toString(),
        comentario: comentario,
      );
      if (!mounted) return;
      setState(() => _enviando = false);
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¡Pedido enviado!'),
          content: const Text('Tu reserva quedó pendiente. Te avisamos cuando el club la confirme.'),
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
      _cargar(); // por si el turno ya lo tomó otra persona
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
            height: 74,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _dias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _dias[i]['fecha'] as String;
                final sel = f == _fechaSel;
                final partes = fechaCorta(f).split(' '); // ["Lun", "26/10"]
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
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              _fechaSel == null ? 'Horarios libres' : 'Horarios libres · ${fechaLarga(_fechaSel)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: turnos.map((t) {
                  return OutlinedButton(
                    onPressed: _enviando ? null : () => _reservar(t),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      side: BorderSide(color: scheme.primary),
                    ),
                    child: Text('${t['hora_desde']} - ${t['hora_hasta']}'),
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
