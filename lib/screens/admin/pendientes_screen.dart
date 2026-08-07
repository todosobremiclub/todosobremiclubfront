import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/admin_api_service.dart';

class PendientesScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const PendientesScreen({super.key, required this.token, required this.clubId});

  @override
  State<PendientesScreen> createState() => _PendientesScreenState();
}

class _PendientesScreenState extends State<PendientesScreen> {
  bool _cargandoSocios = true;
  bool _cargandoTransfer = true;

  List<Map<String, dynamic>> _pendientesSocios = [];
  List<Map<String, dynamic>> _pendientesTransfer = [];

  @override
  void initState() {
    super.initState();
    _cargarSocios();
    _cargarTransfer();
  }

  Future<void> _cargarSocios() async {
    setState(() => _cargandoSocios = true);
    try {
      final items = await AdminApiService.getPendientesSocios(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() {
        _pendientesSocios = items;
        _cargandoSocios = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoSocios = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando pendientes: $e')),
      );
    }
  }

  Future<void> _cargarTransfer() async {
    setState(() => _cargandoTransfer = true);
    try {
      final items = await AdminApiService.getTransferenciasPendientes(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() {
        _pendientesTransfer = items;
        _cargandoTransfer = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoTransfer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando transferencias: $e')),
      );
    }
  }

  Future<String?> _pedirMotivo() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Motivo de rechazo'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '(opcional)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Confirmar')),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _abrirComprobante(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ======================================================
  // Acciones: socios pendientes
  // ======================================================
  Future<void> _aceptarSocio(Map<String, dynamic> p) async {
    final esFoto = (p['tipo']?.toString() ?? '') == 'foto';
    final ok = await _confirmar(
      esFoto ? 'Aplicar foto' : 'Aceptar postulación',
      esFoto
          ? '¿Aceptar la solicitud y actualizar la foto del socio?'
          : '¿Aceptar la postulación y crear el socio?',
    );
    if (!ok) return;

    try {
      await AdminApiService.aceptarPendiente(
        token: widget.token,
        clubId: widget.clubId,
        id: p['id'].toString(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Aceptado')),
      );
      await _cargarSocios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rechazarSocio(Map<String, dynamic> p) async {
    final motivo = await _pedirMotivo();
    if (motivo == null) return; // canceló

    try {
      await AdminApiService.rechazarPendiente(
        token: widget.token,
        clubId: widget.clubId,
        id: p['id'].toString(),
        motivo: motivo.isEmpty ? null : motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Rechazado')),
      );
      await _cargarSocios();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  // ======================================================
  // Acciones: transferencias pendientes
  // ======================================================
  Future<void> _confirmarTransferencia(Map<String, dynamic> t) async {
    final ok = await _confirmar(
      'Confirmar transferencia',
      '¿Confirmar esta transferencia y generar el recibo?',
    );
    if (!ok) return;

    final hoy = DateTime.now();
    final fechaStr =
        '${hoy.year.toString().padLeft(4, '0')}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

    try {
      await AdminApiService.confirmarTransferencia(
        token: widget.token,
        clubId: widget.clubId,
        id: t['id'].toString(),
        fechaPago: fechaStr,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Transferencia confirmada y recibo generado')),
      );
      await _cargarTransfer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rechazarTransferencia(Map<String, dynamic> t) async {
    final motivo = await _pedirMotivo();
    if (motivo == null) return;

    try {
      await AdminApiService.rechazarTransferencia(
        token: widget.token,
        clubId: widget.clubId,
        id: t['id'].toString(),
        motivo: motivo.isEmpty ? null : motivo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Transferencia rechazada')),
      );
      await _cargarTransfer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pendientes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Socios'),
              Tab(text: 'Transferencias'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildSocios(),
            _buildTransferencias(),
          ],
        ),
      ),
    );
  }

  Widget _buildSocios() {
    if (_cargandoSocios) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _cargarSocios,
      child: _pendientesSocios.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay postulaciones pendientes.', textAlign: TextAlign.center),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _pendientesSocios.length,
              itemBuilder: (context, i) => _buildSocioCard(_pendientesSocios[i]),
            ),
    );
  }

  Widget _buildSocioCard(Map<String, dynamic> p) {
    final esFoto = (p['tipo']?.toString() ?? '') == 'foto';
    final fotoUrl = p['foto_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
                  CircleAvatar(radius: 22, backgroundImage: NetworkImage(fotoUrl)),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['apellido'] ?? ''}, ${p['nombre'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        esFoto ? 'Actualización de foto' : 'Alta',
                        style: const TextStyle(fontSize: 12.5, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('DNI: ${p['dni'] ?? '—'}'),
            if ((p['actividad'] ?? '').toString().isNotEmpty) Text('Actividad: ${p['actividad']}'),
            if ((p['categoria'] ?? '').toString().isNotEmpty) Text('Categoría: ${p['categoria']}'),
            if ((p['telefono'] ?? '').toString().isNotEmpty) Text('Teléfono: ${p['telefono']}'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _aceptarSocio(p),
                    child: Text(esFoto ? 'Aplicar foto' : 'Aceptar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rechazarSocio(p),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Rechazar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferencias() {
    if (_cargandoTransfer) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _cargarTransfer,
      child: _pendientesTransfer.isEmpty
          ? ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay transferencias pendientes.', textAlign: TextAlign.center),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _pendientesTransfer.length,
              itemBuilder: (context, i) => _buildTransferCard(_pendientesTransfer[i]),
            ),
    );
  }

  String _moneyArs(dynamic n) {
    final v = double.tryParse(n?.toString() ?? '') ?? 0;
    return '\$${v.toStringAsFixed(0)}';
  }

  Widget _buildTransferCard(Map<String, dynamic> t) {
    final socioLabel =
        '#${t['numero_socio'] ?? '—'} ${t['apellido'] ?? ''} ${t['nombre'] ?? ''}'.trim();
    final periodo = '${t['mes']}/${t['anio']}';
    final comprobanteTexto = t['comprobante_texto']?.toString();
    final comprobanteUrl = t['comprobante_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(socioLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Período: $periodo'),
            Text('Monto esperado: ${_moneyArs(t['monto_esperado'])}'),
            if ((t['referencia'] ?? '').toString().isNotEmpty)
              Text('Referencia: ${t['referencia']}'),
            if ((t['fecha_formateada'] ?? '').toString().isNotEmpty)
              Text('Fecha: ${t['fecha_formateada']}'),
            if (comprobanteTexto != null && comprobanteTexto.isNotEmpty)
              Text('Comprobante: $comprobanteTexto'),
            if (comprobanteUrl != null && comprobanteUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton.icon(
                  onPressed: () => _abrirComprobante(comprobanteUrl),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Ver comprobante'),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmarTransferencia(t),
                    child: const Text('Aceptar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rechazarTransferencia(t),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Rechazar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}