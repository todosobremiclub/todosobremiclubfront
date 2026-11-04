import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class IngresoFormScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const IngresoFormScreen({super.key, required this.token, required this.clubId});

  @override
  State<IngresoFormScreen> createState() => _IngresoFormScreenState();
}

class _IngresoFormScreenState extends State<IngresoFormScreen> {
  final _montoController = TextEditingController();
  final _observacionController = TextEditingController();

  List<Map<String, dynamic>> _tipos = [];
  List<Map<String, dynamic>> _responsables = [];
  String? _tipoId;
  String? _responsableId;
  DateTime _fecha = DateTime.now();
  Map<String, dynamic>? _socio; // ✅ NUEVO: socio asociado (opcional)

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarListas();
  }

  Future<void> _cargarListas() async {
    try {
      final tipos = await AdminApiService.getTiposIngreso(
        token: widget.token,
        clubId: widget.clubId,
      );
      final responsables = await AdminApiService.getResponsables(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() {
        _tipos = tipos;
        _responsables = responsables;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando listas: $e')),
      );
    }
  }

  // ✅ NUEVO: nombre legible de un socio ("Apellido Nombre (#N°)")
  String _nombreSocio(Map<String, dynamic> s) {
    final nombre = '${s['apellido'] ?? ''} ${s['nombre'] ?? ''}'.trim();
    final nro = s['numero_socio'];
    return nro != null ? '$nombre (#$nro)' : nombre;
  }

  Future<void> _elegirSocio() async {
    final elegido = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _SelectorSocioDialog(token: widget.token, clubId: widget.clubId),
    );
    if (elegido != null && mounted) setState(() => _socio = elegido);
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

Future<void> _guardar() async {
    final monto = double.tryParse(_montoController.text.replaceAll(',', '.'));

    if (_tipoId == null || _responsableId == null || monto == null || monto < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá Tipo de ingreso, Responsable y Monto')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final fechaStr =
          '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';

      await AdminApiService.registrarIngreso(
        token: widget.token,
        clubId: widget.clubId,
        tipoIngresoId: _tipoId!,
        fecha: fechaStr,
        monto: monto,
        observacion: _observacionController.text,
        cuentaId: _responsableId,
        socioId: _socio?['id']?.toString(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Ingreso registrado')),
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
    _montoController.dispose();
    _observacionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registrar ingreso')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar ingreso')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _tipoId,
              decoration: const InputDecoration(labelText: 'Tipo de ingreso', border: OutlineInputBorder()),
              items: _tipos
                  .map((t) => DropdownMenuItem(
                        value: t['id'].toString(),
                        child: Text(t['nombre'].toString()),
                      ))
                  .toList(),
              // ✅ NUEVO: si el tipo elegido tiene un monto habitual configurado
              // (Configuración > Tipos de ingreso, en el panel web), se completa
              // el campo Monto solo; se puede editar antes de guardar. Si el
              // tipo no tiene monto cargado, se limpia el campo en vez de
              // dejar el monto del tipo elegido anteriormente.
              onChanged: (v) => setState(() {
                _tipoId = v;
                final tipo = _tipos.firstWhere(
                  (t) => t['id'].toString() == v,
                  orElse: () => const {},
                );
                final monto = tipo['monto'];
                if (monto != null) {
                  _montoController.text = monto.toString();
                } else {
                  _montoController.clear();
                }
              }),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextField(
              controller: _montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            // ✅ NUEVO: socio opcional. Permite ver el ingreso después en
            // Reportes > Ingresos por socio.
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Socio (opcional)',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _elegirSocio,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          _socio == null ? 'Sin socio asignado' : _nombreSocio(_socio!),
                          style: TextStyle(color: _socio == null ? Colors.black45 : null),
                        ),
                      ),
                    ),
                  ),
                  if (_socio != null)
                    IconButton(
                      tooltip: 'Quitar socio',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => _socio = null),
                    )
                  else
                    IconButton(
                      tooltip: 'Elegir socio',
                      icon: const Icon(Icons.person_search),
                      onPressed: _elegirSocio,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _observacionController,
              decoration: const InputDecoration(labelText: 'Observación (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Registrar ingreso'),
            ),
          ],
        ),
      ),
    );
  }
}


// ✅ NUEVO: diálogo para buscar y elegir un socio (nombre, apellido, DNI o N°).
class _SelectorSocioDialog extends StatefulWidget {
  final String token;
  final String clubId;

  const _SelectorSocioDialog({required this.token, required this.clubId});

  @override
  State<_SelectorSocioDialog> createState() => _SelectorSocioDialogState();
}

class _SelectorSocioDialogState extends State<_SelectorSocioDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String texto) {
    _debounce?.cancel();
    final q = texto.trim();
    if (q.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _buscar(q));
  }

  Future<void> _buscar(String q) async {
    setState(() => _buscando = true);
    List<Map<String, dynamic>> res = [];
    try {
      res = await AdminApiService.buscarSocios(
        token: widget.token,
        clubId: widget.clubId,
        query: q,
      );
    } catch (_) {
      res = [];
    }
    if (!mounted) return;
    setState(() {
      _resultados = res;
      _buscando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Elegir socio'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                labelText: 'Nombre, apellido, DNI o N° de socio',
                border: const OutlineInputBorder(),
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _resultados.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Escribí al menos 2 letras o números', style: TextStyle(color: Colors.black54)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _resultados.length,
                      itemBuilder: (_, i) {
                        final s = _resultados[i];
                        final nombre = '${s['apellido'] ?? ''} ${s['nombre'] ?? ''}'.trim();
                        final nro = s['numero_socio'];
                        final dni = s['dni'];
                        return ListTile(
                          dense: true,
                          title: Text(nombre),
                          subtitle: Text([
                            if (nro != null) 'N° $nro',
                            if (dni != null && dni.toString().isNotEmpty) 'DNI $dni',
                          ].join(' · ')),
                          onTap: () => Navigator.of(context).pop(s),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
