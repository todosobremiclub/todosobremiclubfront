import 'dart:convert';
import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class PagoFormScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const PagoFormScreen({
    super.key,
    required this.token,
    required this.clubId,
  });

  @override
  State<PagoFormScreen> createState() => _PagoFormScreenState();
}

class _PagoFormScreenState extends State<PagoFormScreen> {
  final _buscarController = TextEditingController();
  final _montoParcialController = TextEditingController();

  List<Map<String, dynamic>> _resultados = [];
  Map<String, dynamic>? _socio;

  List<Map<String, dynamic>> _responsables = [];
  String? _responsableId;

  List<Map<String, dynamic>> _conceptos = []; // {tipo, nombre, monto, seleccionado, yaPagado}
  List<int> _mesesPagados = [];
  List<Map<String, dynamic>> _pagosDelAnio = []; // detalle crudo por mes

  bool _buscando = false;
  bool _cargandoDetalle = false;
  bool _guardando = false;
  bool _esParcial = false;
  bool _perteneceGrupoFamiliarComoMiembro = false;

  int _anio = DateTime.now().year;
  int _mes = DateTime.now().month;
  DateTime _fechaPago = DateTime.now();

  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _cargarResponsables();
  }

  Future<void> _cargarResponsables() async {
    try {
      final responsables = await AdminApiService.getResponsables(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() => _responsables = responsables);
    } catch (_) {}
  }

  Future<void> _buscar() async {
    final q = _buscarController.text.trim();
    if (q.isEmpty) return;

    setState(() => _buscando = true);

    try {
      final resultados = await AdminApiService.buscarSocios(
        token: widget.token,
        clubId: widget.clubId,
        query: q,
      );
      setState(() => _resultados = resultados);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _elegirSocio(Map<String, dynamic> socio) async {
    setState(() {
      _socio = socio;
      _cargandoDetalle = true;
    });
    await _cargarDetalleSocio();
  }

  /// Parsea el campo actividades_adicionales, que llega como STRING JSON
  /// desde el backend (ej: '["Basquet"]'), no como lista directa.
  List<String> _parseAdicionalesDelSocio(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  List<dynamic> _parseDetallePago(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw;
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded;
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  Future<void> _cargarDetalleSocio() async {
    if (_socio == null) return;

    setState(() => _cargandoDetalle = true);

    try {
      final actividades = await AdminApiService.getActividadesConPrecio(
        token: widget.token,
        clubId: widget.clubId,
      );
      final adicionalesConfig = await AdminApiService.getActividadesAdicionalesConPrecio(
        token: widget.token,
        clubId: widget.clubId,
      );
      final pagosData = await AdminApiService.getPagosSocio(
        token: widget.token,
        clubId: widget.clubId,
        socioId: _socio!['id'].toString(),
        anio: _anio,
      );

      final conceptosBase = <Map<String, dynamic>>[];

      final esMiembro = _socio!['es_miembro_plan_familiar'] == true;
      final esJefe = _socio!['es_jefe_plan_familiar'] == true;
      final excepcionId = _socio!['excepcion_cuota_id'];

      if (!esMiembro) {
        if (esJefe) {
          final gf = actividades.firstWhere(
            (a) => a['nombre'] == 'Grupo Familiar',
            orElse: () => {'nombre': 'Grupo Familiar', 'precio_mensual': 0},
          );
          conceptosBase.add({
            'tipo': 'base',
            'nombre': 'Grupo Familiar',
            'monto': double.tryParse(gf['precio_mensual'].toString()) ?? 0,
          });
        } else if (excepcionId != null) {
          conceptosBase.add({
            'tipo': 'base',
            'nombre': _socio!['excepcion_cuota_nombre']?.toString() ?? 'Excepción',
            'monto': double.tryParse(_socio!['excepcion_cuota_monto']?.toString() ?? '0') ?? 0,
          });
        } else {
          final act = actividades.firstWhere(
            (a) => a['nombre'] == _socio!['actividad'],
            orElse: () => {'nombre': _socio!['actividad'], 'precio_mensual': 0},
          );
          conceptosBase.add({
            'tipo': 'base',
            'nombre': _socio!['actividad']?.toString() ?? '',
            'monto': double.tryParse(act['precio_mensual'].toString()) ?? 0,
          });
        }
      }

      final nombresAdicionales = _parseAdicionalesDelSocio(_socio!['actividades_adicionales']);

      for (final nombre in nombresAdicionales) {
        final item = adicionalesConfig.firstWhere(
          (a) => a['nombre'].toString().trim() == nombre.trim(),
          orElse: () => {'nombre': nombre, 'precio_mensual': 0},
        );
        conceptosBase.add({
          'tipo': 'adicional',
          'nombre': nombre,
          'monto': double.tryParse(item['precio_mensual'].toString()) ?? 0,
        });
      }

      if (!mounted) return;
      setState(() {
        _perteneceGrupoFamiliarComoMiembro = esMiembro;
        _mesesPagados = List<int>.from(pagosData['mesesPagados'] ?? []);
        _pagosDelAnio = List<Map<String, dynamic>>.from(pagosData['pagos'] ?? []);
        _ajustarMesDisponible();
        _conceptos = _construirConceptosParaMes(conceptosBase, _mes);
        _cargandoDetalle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoDetalle = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// Cruza los conceptos "base" (actividad + adicionales del socio) contra
  /// lo que ya se cobró ese mes específico (detalle_pago existente), y
  /// marca como "yaPagado" (bloqueado, no seleccionable) lo que corresponda.
  List<Map<String, dynamic>> _construirConceptosParaMes(
    List<Map<String, dynamic>> conceptosBase,
    int mes,
  ) {
    final pagoDelMes = _pagosDelAnio.firstWhere(
      (p) => int.tryParse(p['mes'].toString()) == mes,
      orElse: () => <String, dynamic>{},
    );

    final detalle = _parseDetallePago(pagoDelMes['detalle_pago']);
    final pagoCompletoSinDetalle =
        pagoDelMes['pago_completo'] == true && detalle.isEmpty;

    return conceptosBase.map((c) {
      final yaPagado = pagoCompletoSinDetalle ||
          detalle.any((d) =>
              d is Map &&
              d['seleccionado'] == true &&
              (d['tipo']?.toString() ?? '') == c['tipo'] &&
              (d['nombre']?.toString() ?? '').trim() == c['nombre'].toString().trim());

      return {
        ...c,
        'seleccionado': !yaPagado,
        'yaPagado': yaPagado,
      };
    }).toList();
  }

  void _ajustarMesDisponible() {
    if (_mesesPagados.contains(_mes)) {
      final libre = List.generate(12, (i) => i + 1).firstWhere(
        (m) => !_mesesPagados.contains(m),
        orElse: () => _mes,
      );
      _mes = libre;
    }
  }

  void _cambiarMes(int nuevoMes) {
    setState(() {
      _mes = nuevoMes;
      // Reconstruir conceptos (misma lista base, cruzando contra el mes nuevo)
      final base = _conceptos
          .map((c) => {'tipo': c['tipo'], 'nombre': c['nombre'], 'monto': c['monto']})
          .toList();
      _conceptos = _construirConceptosParaMes(base, _mes);
    });
  }

  Future<void> _cambiarAnio(int nuevoAnio) async {
    setState(() => _anio = nuevoAnio);
    await _cargarDetalleSocio();
  }

  Future<void> _elegirFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaPago,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (elegida != null) setState(() => _fechaPago = elegida);
  }

  double get _montoTotalTeorico {
    return _conceptos
        .where((c) => c['seleccionado'] == true)
        .fold(0.0, (sum, c) => sum + (c['monto'] as double));
  }

  Future<void> _guardar() async {
    if (_responsableId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un Responsable')),
      );
      return;
    }

    final conceptosParaEnviar = _conceptos
        .where((c) => c['yaPagado'] != true)
        .map((c) => {
              'tipo': c['tipo'],
              'nombre': c['nombre'],
              'monto': c['monto'],
              'seleccionado': c['seleccionado'],
            })
        .toList();

    if (conceptosParaEnviar.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay conceptos pendientes para cobrar este mes')),
      );
      return;
    }

    double? montoParcial;
    if (_esParcial) {
      montoParcial = double.tryParse(_montoParcialController.text.replaceAll(',', '.'));
      if (montoParcial == null || montoParcial < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para pago parcial, indicá un monto válido')),
        );
        return;
      }
    }

    setState(() => _guardando = true);

    try {
      await AdminApiService.registrarPago(
        token: widget.token,
        clubId: widget.clubId,
        socioId: _socio!['id'].toString(),
        anio: _anio,
        mes: _mes,
        fechaPago:
            '${_fechaPago.year.toString().padLeft(4, '0')}-${_fechaPago.month.toString().padLeft(2, '0')}-${_fechaPago.day.toString().padLeft(2, '0')}',
        cuentaId: _responsableId!,
        detallePago: conceptosParaEnviar,
        montoTotalTeorico: _montoTotalTeorico,
        esParcial: _esParcial,
        montoParcial: montoParcial,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Pago registrado')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  void dispose() {
    _buscarController.dispose();
    _montoParcialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar pago de cuota')),
      body: _socio == null ? _buildBusqueda() : _buildFormularioPago(),
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
                    labelText: 'Buscar por nombre, DNI o número de socio',
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
                  onTap: () => _elegirSocio(s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioPago() {
    if (_cargandoDetalle) {
      return const Center(child: CircularProgressIndicator());
    }

    final s = _socio!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          tileColor: Colors.black.withOpacity(0.04),
          title: Text('${s['apellido']}, ${s['nombre']}'),
          subtitle: Text('N° ${s['numero_socio'] ?? '-'} · ${s['actividad'] ?? '-'}'),
          trailing: TextButton(
            onPressed: () => setState(() {
              _socio = null;
              _conceptos = [];
              _mesesPagados = [];
              _pagosDelAnio = [];
            }),
            child: const Text('Cambiar'),
          ),
        ),
        if (_perteneceGrupoFamiliarComoMiembro) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Este socio pertenece a un Grupo Familiar. La cuota base se cobra a través del jefe/a del grupo — acá solo se pueden registrar sus actividades adicionales.',
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _mes,
                decoration: const InputDecoration(labelText: 'Mes', border: OutlineInputBorder()),
                items: List.generate(12, (i) => i + 1).map((m) {
                  final pagado = _mesesPagados.contains(m);
                  return DropdownMenuItem(
                    value: m,
                    enabled: !pagado,
                    child: Text(
                      pagado ? '${_meses[m - 1]} (ya pagado)' : _meses[m - 1],
                      style: pagado ? const TextStyle(color: Colors.grey) : null,
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null && !_mesesPagados.contains(v)) {
                    _cambiarMes(v);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              child: TextFormField(
                initialValue: _anio.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Año', border: OutlineInputBorder()),
                onFieldSubmitted: (v) {
                  final nuevo = int.tryParse(v);
                  if (nuevo != null) _cambiarAnio(nuevo);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Fecha de pago'),
          subtitle: Text(
            '${_fechaPago.day.toString().padLeft(2, '0')}/${_fechaPago.month.toString().padLeft(2, '0')}/${_fechaPago.year}',
          ),
          trailing: const Icon(Icons.calendar_today),
          onTap: _elegirFecha,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _responsableId,
          decoration: const InputDecoration(labelText: 'Responsable', border: OutlineInputBorder()),
          items: _responsables
              .map((r) => DropdownMenuItem(
                    value: r['id'].toString(),
                    child: Text(r['nombre'].toString()),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _responsableId = v),
        ),
        const SizedBox(height: 16),
        const Text('Conceptos a cobrar', style: TextStyle(fontWeight: FontWeight.bold)),
        if (_conceptos.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Este socio no tiene conceptos configurados para cobrar.'),
          )
        else
          ..._conceptos.map((c) {
            final yaPagado = c['yaPagado'] == true;
            return CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${c['tipo'] == 'base' ? 'Cuota' : 'Adicional'}: ${c['nombre']}'
                '${yaPagado ? ' (ya pagado)' : ''}',
                style: yaPagado ? const TextStyle(color: Colors.grey) : null,
              ),
              subtitle: Text('\$${(c['monto'] as double).toStringAsFixed(0)} por mes'),
              value: c['seleccionado'] as bool,
              onChanged: yaPagado
                  ? null
                  : (v) => setState(() => c['seleccionado'] = v ?? false),
            );
          }),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Total a cobrar ahora: \$${_montoTotalTeorico.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('¿Es un pago parcial?'),
          value: _esParcial,
          onChanged: (v) => setState(() => _esParcial = v),
        ),
        if (_esParcial) ...[
          const SizedBox(height: 4),
          TextField(
            controller: _montoParcialController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monto que está pagando ahora',
              border: OutlineInputBorder(),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Registrar pago'),
        ),
      ],
    );
  }
}