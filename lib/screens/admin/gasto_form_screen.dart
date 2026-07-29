import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class GastoFormScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const GastoFormScreen({super.key, required this.token, required this.clubId});

  @override
  State<GastoFormScreen> createState() => _GastoFormScreenState();
}

class _GastoFormScreenState extends State<GastoFormScreen> {
  final _montoController = TextEditingController();
  final _descripcionController = TextEditingController();

  List<Map<String, dynamic>> _tipos = [];
  List<Map<String, dynamic>> _responsables = [];
  String? _tipoId;
  String? _responsableId;
  DateTime _fecha = DateTime.now();

  bool _cargando = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarListas();
  }

  Future<void> _cargarListas() async {
    try {
      final tipos = await AdminApiService.getTiposGasto(token: widget.token, clubId: widget.clubId);
      final responsables = await AdminApiService.getResponsables(token: widget.token, clubId: widget.clubId);
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
        const SnackBar(content: Text('Completá Tipo de gasto, Responsable y Monto')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final fechaStr =
          '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}-${_fecha.day.toString().padLeft(2, '0')}';
      final periodo = '${_fecha.year.toString().padLeft(4, '0')}-${_fecha.month.toString().padLeft(2, '0')}';

await AdminApiService.registrarGasto(
        token: widget.token,
        clubId: widget.clubId,
        periodo: periodo,
        fechaGasto: fechaStr,
        tipoGastoId: _tipoId!,
        responsableId: _responsableId!,
        monto: monto,
        descripcion: _descripcionController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Gasto registrado')),
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
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return Scaffold(
        appBar: AppBar(title: const Text('Registrar gasto')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar gasto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _tipoId,
              decoration: const InputDecoration(labelText: 'Tipo de gasto', border: OutlineInputBorder()),
              items: _tipos
                  .map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['nombre'].toString())))
                  .toList(),
              onChanged: (v) => setState(() => _tipoId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _responsableId,
              decoration: const InputDecoration(labelText: 'Responsable', border: OutlineInputBorder()),
              items: _responsables
                  .map((r) => DropdownMenuItem(value: r['id'].toString(), child: Text(r['nombre'].toString())))
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
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Registrar gasto'),
            ),
          ],
        ),
      ),
    );
  }
}