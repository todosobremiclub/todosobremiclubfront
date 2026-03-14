import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';

class CumplesScreen extends StatefulWidget {
  final AppSession session;
  const CumplesScreen({super.key, required this.session});

  @override
  State<CumplesScreen> createState() => _CumplesScreenState();
}

class _CumplesScreenState extends State<CumplesScreen> {
  late Future<_CumplesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadCumples();
  }

  Future<_CumplesData> _loadCumples() async {
    final clubId = widget.session.clubObj.id;
    final token = widget.session.token;

    final url = Uri.parse('${ApiConfig.baseUrl}/club/$clubId/cumples');

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode != 200) {
      throw Exception('Error al obtener cumpleaños');
    }

    final data = jsonDecode(res.body);

    if (data['ok'] != true) {
      throw Exception(data['error'] ?? 'Error al obtener cumpleaños');
    }

    final hoyList = List<Map<String, dynamic>>.from(
      data['hoy'] ?? const <Map<String, dynamic>>[],
    );
    final eventos = List<Map<String, dynamic>>.from(
      data['eventos'] ?? const <Map<String, dynamic>>[],
    );

    // Mes actual
    final ahora = DateTime.now();
    final mesActual = ahora.month;

    // IDs de los que cumplen HOY, para no repetirlos en "Este mes cumplen"
    final idsHoy = hoyList.map((e) => e['id'].toString()).toSet();

    // Filtramos eventos del mes actual, excluyendo los de hoy
    final mesList = <Map<String, dynamic>>[];

    for (final ev in eventos) {
      final dateStr = (ev['date'] ?? '').toString();
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;

      if (dt.month == mesActual && !idsHoy.contains(ev['id'].toString())) {
        mesList.add(ev);
      }
    }

    return _CumplesData(hoy: hoyList, mes: mesList);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<_CumplesData>(
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

        final data = snap.data!;
        final hoy = data.hoy;
        final mes = data.mes;

        // Si no hay nadie en todo el mes
        if (hoy.isEmpty && mes.isEmpty) {
          return Center(
            child: Text(
              'No hay cumpleaños registrados este mes.',
              style: TextStyle(
                fontSize: 16,
                color: scheme.onBackground,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ===== Cumpleaños de HOY =====
            Text(
              'Cumpleaños de hoy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onBackground,
                  ),
            ),
            const SizedBox(height: 8),
            if (hoy.isEmpty)
              Text(
                'Hoy no hay cumpleaños.',
                style: TextStyle(color: scheme.onBackground),
              )
            else
              ...hoy.map((s) => _buildCumpleHoyCard(context, s)),

            const SizedBox(height: 24),

            // ===== Este mes cumplen =====
            Text(
              'Este mes cumplen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onBackground,
                  ),
            ),
            const SizedBox(height: 8),
            if (mes.isEmpty)
              Text(
                'No hay más cumpleaños este mes.',
                style: TextStyle(color: scheme.onBackground),
              )
            else
              ...mes.map((ev) => _buildCumpleMesTile(context, ev)),
          ],
        );
      },
    );
  }

  // ---------- HOY: con foto + nombre y apellido, fondo primario + texto acento ----------
  Widget _buildCumpleHoyCard(BuildContext context, Map<String, dynamic> s) {
    final scheme = Theme.of(context).colorScheme;

    final foto = (s['foto_url'] ?? '').toString().trim();
    final nombre = '${s['nombre'] ?? ''} ${s['apellido'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.primary, // 🔥 Fondo PRIMARIO
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: Colors.black26,
          backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
          child: foto.isEmpty
              ? const Icon(Icons.person, size: 28, color: Colors.white70)
              : null,
        ),
        title: Text(
          nombre,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: scheme.onPrimary, // 🔥 Texto ACENTO
          ),
        ),
        subtitle: Text(
          '¡Feliz cumpleaños! 🎉',
          style: TextStyle(
            color: scheme.onPrimary.withOpacity(0.85),
          ),
        ),
      ),
    );
  }

  // ---------- ESTE MES: fondo primario + texto acento ----------
  Widget _buildCumpleMesTile(BuildContext context, Map<String, dynamic> ev) {
    final scheme = Theme.of(context).colorScheme;

    final title = (ev['title'] ?? '').toString();
    final dateStr = (ev['date'] ?? '').toString();
    final dt = DateTime.tryParse(dateStr);
    final dia = dt?.day ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.primary, // 🔥 Fondo PRIMARIO
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Icon(
          Icons.cake_outlined,
          color: scheme.onPrimary, // 🔥 Icono ACENTO
        ),
        title: Text(
          title,
          style: TextStyle(
            color: scheme.onPrimary, // 🔥 Texto ACENTO
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          dia > 0 ? 'Día $dia' : dateStr,
          style: TextStyle(
            color: scheme.onPrimary.withOpacity(0.8),
          ),
        ),
      ),
    );
  }
}

class _CumplesData {
  final List<Map<String, dynamic>> hoy;
  final List<Map<String, dynamic>> mes;

  _CumplesData({required this.hoy, required this.mes});
}
