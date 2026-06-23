import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';

class RecibosScreen extends StatefulWidget {
  final AppSession session;
  const RecibosScreen({super.key, required this.session});

  @override
  State<RecibosScreen> createState() => _RecibosScreenState();
}

class _RecibosScreenState extends State<RecibosScreen>
    with WidgetsBindingObserver {
  late Future<List<_ReciboPago>> _future;
  bool _transferBusy = false;
  bool _transferenciaHabilitada = false;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _reloadScreen();
}

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

void _reloadScreen() {
  _future = _loadRecibos();
  _loadTransferConfig();
}

  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    setState(() {
      _reloadScreen();
    });
  }
}


Future<void> _loadTransferConfig() async {
  try {
    final token = widget.session.token;

    final res = await http.get(
      Uri.parse(ApiConfig.transferConfigUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200 && data['ok'] == true) {
      setState(() {
        _transferenciaHabilitada =
            data['transferencia_habilitada'] == true;
      });

      print('✅ CONFIG transferencia: $_transferenciaHabilitada');
    } else {
      print('❌ config error: ${data['error']}');
    }
  } catch (e) {
    print('❌ error cargando config: $e');
  }
}

  Future<List<_ReciboPago>> _loadRecibos() async {
  final clubId = widget.session.clubObj.id;
  final socioId = widget.session.socioObj.id;
  final token = widget.session.token;
  final anioActual = DateTime.now().year;

  final url = Uri.parse(
    '${ApiConfig.baseUrl}/club/$clubId/pagos/$socioId?anio=$anioActual',
  );

  final res = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    },
  );

  if (res.statusCode != 200) {
    throw Exception('Error al obtener recibos de pago');
  }

  final data = jsonDecode(res.body);

  if (data['ok'] != true) {
    throw Exception(data['error'] ?? 'Error al obtener recibos de pago');
  }

  // 🚫 IMPORTANTE: NO tocar más _transferenciaHabilitada acá
  // Este valor ahora SOLO lo maneja _loadTransferConfig()

  final int anio = data['anio'] is int
      ? data['anio'] as int
      : int.tryParse('${data['anio']}') ?? anioActual;

  final List<dynamic> pagosRaw = data['pagos'] ?? [];

  final recibos = pagosRaw.map<_ReciboPago>((p) {
    final mes = int.tryParse('${p['mes']}') ?? 0;

    final monto = p['monto'] == null
        ? 0.0
        : double.tryParse(p['monto'].toString()) ?? 0.0;

    final fechaIso = (p['fecha_pago'] ?? p['fecha'] ?? '') as String;

    final cuenta = (p['cuenta'] ?? '').toString();

    final bool pendienteApi = p['pendiente'] == true;

    return _ReciboPago(
      anio: anio,
      mes: mes,
      monto: monto,
      fechaPagoIso: fechaIso,
      cuenta: cuenta,
      pendiente: pendienteApi,
      estadoTransferencia: p['estado_transferencia'],
    );
  }).toList();

// ✅ ORDENAR: mes actual primero, hacia atrás
recibos.sort((a, b) {
  final ka = a.anio * 100 + a.mes;
  final kb = b.anio * 100 + b.mes;
  return kb.compareTo(ka); // DESCENDENTE
});

  return recibos;
}

  @override
  Widget build(BuildContext context) {
    final club = widget.session.clubObj;
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<_ReciboPago>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(
            child: Text(
              'Error: ${snap.error}',
              style: TextStyle(color: scheme.onBackground),
            ),
          );
        }

        final recibos = snap.data ?? [];

        if (recibos.isEmpty) {
          return Center(
            child: Text(
              'No hay pagos registrados todavía.',
              style: TextStyle(color: scheme.onBackground),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: recibos.length,
          itemBuilder: (context, index) {
            return _buildReciboCard(
              context,
              club,
              recibos[index],
            );
          },
        );
      },
    );
  }

  Widget _buildReciboCard(
    BuildContext context,
    dynamic club,
    _ReciboPago recibo,
  ) {


    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            club.nombre,
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          _row('Mes', recibo.mesNombreConAnio, scheme),

          if (recibo.pendiente && _transferenciaHabilitada == true) ...[
  const SizedBox(height: 6),

  // ✅ EN REVISIÓN
  if (recibo.estadoTransferencia == 'en_revision') ...[
    _row('Estado', 'En revisión', scheme),
  ]

  // ✅ RECHAZADO (FIX NUEVO)
  else if (recibo.estadoTransferencia == 'rechazado') ...[
    _row('Estado', 'Rechazada, por favor comunicarse con el club', scheme),
  ]

  // ✅ PENDIENTE NORMAL
  else ...[
    _row('Estado', 'Pendiente', scheme),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _transferBusy ? null : () => _openTransferDialog(recibo),
        child: const Text('Informar transferencia realizada'),
      ),
    ),
  ],
]

else ...[
  _row('Fecha', recibo.fechaPagoDMY, scheme),
  _row('Monto', recibo.montoFormatoArs, scheme),
  _row('Método', recibo.metodoPagoLabel, scheme),
],
        ],
      ),
    );
  }

  Widget _row(String label, String value, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: scheme.onPrimary.withOpacity(0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: scheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openTransferDialog(_ReciboPago recibo) async {
    if (_transferBusy) return;
    if (!mounted) return;

    setState(() => _transferBusy = true);

    try {
      final scheme = Theme.of(context).colorScheme;
      final token = widget.session.token;

      // 1) START
      final startRes = await http.post(
        Uri.parse(ApiConfig.transferStartUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'anio': recibo.anio,
          'mes': recibo.mes,
        }),
      );

      if (startRes.statusCode != 200) {
        _showSnack('Error iniciando transferencia (HTTP ${startRes.statusCode})');
        return;
      }

      final startData = jsonDecode(startRes.body);
      if (startData is! Map || startData['ok'] != true) {
        _showSnack(startData['error']?.toString() ?? 'Error iniciando transferencia');
        return;
      }

      // Si backend dice que ya está en revisión, no permitir otro intento
      if (startData['estado'] == 'en_revision') {
        _showSnack('Ya está en revisión');
        return;
      }

      // 2) CONFIG
      final cfgRes = await http.get(
        Uri.parse(ApiConfig.transferConfigUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (cfgRes.statusCode != 200) {
        _showSnack('Error obteniendo datos (HTTP ${cfgRes.statusCode})');
        return;
      }

      final cfgData = jsonDecode(cfgRes.body);
      if (cfgData is! Map || cfgData['ok'] != true) {
        _showSnack(cfgData['error']?.toString() ?? 'Error obteniendo datos');
        return;
      }

      final alias = (cfgData['alias'] ?? '').toString();
      final cvu = (cfgData['cvu'] ?? '').toString();
      final titular = (cfgData['titular'] ?? '').toString();

      final controller = TextEditingController();

      if (!mounted) return;

      await showDialog(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            'Datos para la transferencia',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
  'Transferí a esta cuenta',
  style: const TextStyle(
    color: Colors.black,
    fontWeight: FontWeight.w800,
    fontSize: 17,
  ),
),
                      const SizedBox(height: 12),
                      _datoTransferencia(
                        label: 'Alias',
                        value: alias,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: alias));
                          _showSnack('Alias copiado');
                        },
                      ),
                      const SizedBox(height: 10),
                      _datoTransferencia(
                        label: 'CVU',
                        value: cvu,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: cvu));
                          _showSnack('CVU copiado');
                        },
                      ),
                      const SizedBox(height: 10),
                      _datoTransferencia(
                        label: 'Titular',
                        value: titular,
                        onCopy: null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Indique desde que cuenta se realiza la transferencia',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
  controller: controller,
  maxLines: 2,
  style: const TextStyle(color: Colors.black),
  decoration: InputDecoration(
    hintText: 'Ej: Juan Pérez, cuenta propia, etc.',
    hintStyle: TextStyle(color: Colors.grey.shade600),

    filled: true,
    fillColor: Colors.white,

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Colors.black,
        width: 1,
      ),
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: Colors.grey.shade500,
        width: 1.2,
      ),
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(
        color: Theme.of(context).primaryColor,
        width: 2,
      ),
    ),

    contentPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
  ),
),

              ],
            ),
          ),
          actions: [
            TextButton(
  onPressed: () {
    if (dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }
  },
  child: const Text('Cancelar'),
),
            ElevatedButton(
  onPressed: () async {
    final ok = await _sendTransferProof(
      anio: recibo.anio,
      mes: recibo.mes,
      comprobanteTexto: controller.text.trim(),
    );

    if (!ok) return;

    // Cerrar primero el diálogo usando SU PROPIO contexto
    if (dialogContext.mounted) {
      Navigator.of(dialogContext, rootNavigator: true).pop();
    }

    // Verificar que la pantalla siga viva antes de usar context o setState
    if (!mounted) return;

    _showSnack('Pago enviado para revisión');
    setState(() {
      _future = _loadRecibos();
    });
  },
  child: const Text('Ya transferí'),
),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _transferBusy = false);
    }
  }

  Future<bool> _sendTransferProof({
    required int anio,
    required int mes,
    String? comprobanteTexto,
  }) async {
    final token = widget.session.token;

    final proofRes = await http.post(
      Uri.parse(ApiConfig.transferProofUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'anio': anio,
        'mes': mes,
        if (comprobanteTexto != null && comprobanteTexto.isNotEmpty)
          'comprobante_texto': comprobanteTexto,
        if (comprobanteTexto == null || comprobanteTexto.isEmpty)
          'comprobante_texto': 'Transferencia realizada',
      }),
    );

    if (proofRes.statusCode != 200) {
      _showSnack('Error enviando comprobante (HTTP ${proofRes.statusCode})');
      return false;
    }

    final proofData = jsonDecode(proofRes.body);
    if (proofData is! Map || proofData['ok'] != true) {
      _showSnack(proofData['error']?.toString() ?? 'Error enviando comprobante');
      return false;
    }

    return true;
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _datoTransferencia({
    required String label,
    required String value,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
  color: Colors.black,
  fontSize: 13,
  fontWeight: FontWeight.w700,
),
              ),
              const SizedBox(height: 4),
              SelectableText(
                value.isNotEmpty ? value : '—',
                style: const TextStyle(
  color: Colors.black,
  fontSize: 15,
  fontWeight: FontWeight.w500,
),
              ),
            ],
          ),
        ),
        if (onCopy != null)
          IconButton(
            icon: const Icon(Icons.copy, size: 20, color: Colors.black87),
            onPressed: onCopy,
          ),
      ],
    );
  }
}

class _ReciboPago {
  final int anio;
  final int mes;
  final double monto;
  final String fechaPagoIso;
  final String? cuenta;
  final bool pendiente;
  final String? estadoTransferencia; // en_revision | rechazado

  _ReciboPago({
    required this.anio,
    required this.mes,
    required this.monto,
    required this.fechaPagoIso,
    this.cuenta,
    this.pendiente = false,
    this.estadoTransferencia,
  });

  factory _ReciboPago.pendiente({
    required int anio,
    required int mes,
  }) {
    return _ReciboPago(
      anio: anio,
      mes: mes,
      monto: 0,
      fechaPagoIso: '',
      pendiente: true,
      estadoTransferencia: null,
    );
  }

  static const List<String> _meses = [
    '',
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static final NumberFormat _ars =
      NumberFormat.currency(locale: 'es_AR', symbol: '\$ ');

  String get mesNombre =>
      (mes >= 1 && mes <= 12) ? _meses[mes] : 'Mes $mes';

  String get mesNombreConAnio => '$mesNombre $anio';

  String get fechaPagoDMY {
    if (fechaPagoIso.isEmpty) return '—';
    final d = DateTime.tryParse(fechaPagoIso);
    if (d == null) return fechaPagoIso;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String get montoFormatoArs => _ars.format(monto);

  String get metodoPagoLabel {
    if (pendiente) {
      if (estadoTransferencia == 'en_revision') return 'En revisión';
      if (estadoTransferencia == 'rechazado') return 'Rechazado';
      return 'Pendiente';
    }

    return cuenta?.isNotEmpty == true ? cuenta! : '—';
  }
}
