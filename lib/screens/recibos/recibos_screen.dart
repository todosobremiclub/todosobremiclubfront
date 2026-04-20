import 'dart:convert';
import 'package:flutter/material.dart';
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

class _RecibosScreenState extends State<RecibosScreen> {
  late Future<List<_ReciboPago>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadRecibos();
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

      return _ReciboPago(
        anio: anio,
        mes: mes,
        monto: monto,
        fechaPagoIso: fechaIso,
      );
    }).toList();

    // Orden descendente
    recibos.sort((a, b) {
      final ka = a.anio * 100 + a.mes;
      final kb = b.anio * 100 + b.mes;
      return kb.compareTo(ka);
    });

    return recibos;
  }

  @override
  Widget build(BuildContext context) {
    final socio = widget.session.socioObj;
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
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onBackground),
            ),
          );
        }

        final recibos = snap.data ?? [];

        if (recibos.isEmpty) {
          return Center(
            child: Text(
              'No hay pagos registrados todavía.',
              style: TextStyle(fontSize: 16, color: scheme.onBackground),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: recibos.length,
          itemBuilder: (context, index) {
            final r = recibos[index];
            return _buildReciboCard(context, club, socio, r);
          },
        );
      },
    );
  }

  Widget _buildReciboCard(
    BuildContext context,
    dynamic club,
    dynamic socio,
    _ReciboPago recibo,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final nombreCompleto = '${socio.apellido} ${socio.nombre}'.trim();
    final actividad = (socio.actividad ?? '').toString();
    final categoria = (socio.categoria ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER PEQUEÑO
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club.nombre,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Recibo de pago',
                      style: TextStyle(
                        color: scheme.onPrimary.withOpacity(0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '#${socio.numero}',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),
          Divider(color: scheme.onPrimary.withOpacity(0.25), height: 12),
          const SizedBox(height: 4),

          // DATOS REDUCIDOS
          _rowLabelValue(context, label: 'Socio', value: nombreCompleto, fontSize: 12),
          _rowLabelValue(context, label: 'DNI', value: socio.dni.toString(), fontSize: 12),
          _rowLabelValue(context, label: 'Actividad', value: actividad.isEmpty ? '—' : actividad, fontSize: 12),
          _rowLabelValue(context, label: 'Categoría', value: categoria.isEmpty ? '—' : categoria, fontSize: 12),

          const SizedBox(height: 6),
          Divider(color: scheme.onPrimary.withOpacity(0.25), height: 12),
          const SizedBox(height: 4),

          _rowLabelValue(context, label: 'Mes abonado', value: recibo.mesNombreConAnio, fontSize: 12),
          _rowLabelValue(context, label: 'Fecha de pago', value: recibo.fechaPagoDMY, fontSize: 12),
          _rowLabelValue(context, label: 'Monto', value: recibo.montoFormatoArs, fontSize: 12),

          // ❌ Sacado: "Válido como comprobante de pago"
        ],
      ),
    );
  }

  Widget _rowLabelValue(
    BuildContext context, {
    required String label,
    required String value,
    double fontSize = 13,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: scheme.onPrimary.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w500,
                fontSize: fontSize,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReciboPago {
  final int anio;
  final int mes;
  final double monto;
  final String fechaPagoIso;

  _ReciboPago({
    required this.anio,
    required this.mes,
    required this.monto,
    required this.fechaPagoIso,
  });

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
    try {
      final d = DateTime.parse(fechaPagoIso);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year}';
    } catch (_) {
      return fechaPagoIso.length >= 10
          ? fechaPagoIso.substring(0, 10)
          : fechaPagoIso;
    }
  }

  String get montoFormatoArs => _ars.format(monto);
}