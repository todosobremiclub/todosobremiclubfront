
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';

class CumplesScreen extends StatefulWidget {
  final AppSession session;
  final ValueChanged<int>? onHoyCountChanged;

  const CumplesScreen({
    super.key,
    required this.session,
    this.onHoyCountChanged,
  });

  @override
  State<CumplesScreen> createState() => _CumplesScreenState();
}

class _CumplesScreenState extends State<CumplesScreen>
    with SingleTickerProviderStateMixin {
  late Future<_CumplesData> _future;
  late final AnimationController _rainController;
  bool _rainTriggered = false;

  @override
  void initState() {
    super.initState();
    _rainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _future = _loadCumples();
  }

  @override
  void dispose() {
    _rainController.dispose();
    super.dispose();
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

    final ahora = DateTime.now();
    final mesActual = ahora.month;
    final idsHoy = hoyList.map((e) => e['id'].toString()).toSet();

    final mesList = <Map<String, dynamic>>[];
    for (final ev in eventos) {
      final dateStr = (ev['date'] ?? '').toString();
      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;
      if (dt.month == mesActual && !idsHoy.contains(ev['id'].toString())) {
        mesList.add(ev);
      }
    }

    widget.onHoyCountChanged?.call(hoyList.length);
    return _CumplesData(hoy: hoyList, mes: mesList);
  }

  void _playBirthdayRainIfNeeded(int hoyCount) {
    if (_rainTriggered || hoyCount <= 0) return;
    _rainTriggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rainController.forward(from: 0);
    });
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
        _playBirthdayRainIfNeeded(hoy.length);

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

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Text(
                      'Cumpleaños de hoy',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: scheme.onBackground,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (hoy.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${hoy.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
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
            ),
            if (hoy.isNotEmpty)
              IgnorePointer(
                ignoring: true,
                child: _BirthdayRain(
                  controller: _rainController,
                  color: scheme.onPrimary,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCumpleHoyCard(BuildContext context, Map<String, dynamic> s) {
    final scheme = Theme.of(context).colorScheme;
    final foto = (s['foto_url'] ?? '').toString().trim();
    final nombre = '${s['nombre'] ?? ''} ${s['apellido'] ?? ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.primary,
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
            color: scheme.onPrimary,
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

  Widget _buildCumpleMesTile(BuildContext context, Map<String, dynamic> ev) {
    final scheme = Theme.of(context).colorScheme;
    final title = (ev['title'] ?? '').toString();
    final dateStr = (ev['date'] ?? '').toString();
    final dt = DateTime.tryParse(dateStr);
    final dia = dt?.day ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.primary,
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
          color: scheme.onPrimary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: scheme.onPrimary,
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

class _BirthdayRain extends StatelessWidget {
  final Animation<double> controller;
  final Color color;

  const _BirthdayRain({
    required this.controller,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final items = List.generate(18, (i) => i);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;

            return Stack(
              children: items.map((i) {
                final start = (i % 6) * 0.05;
                final end = math.min(1.0, start + 0.55);
                final t = CurvedAnimation(
                  parent: controller,
                  curve: Interval(start, end, curve: Curves.easeOutCubic),
                ).value;

                final x = (w / 18) * i + (i.isEven ? 6.0 : -6.0);
                final y = -40 + (h + 120) * t;
                final rotation = (i.isEven ? 1 : -1) * t * 1.2;
                final size = 18.0 + (i % 4) * 4.0;
                final opacity = (1 - t).clamp(0.0, 1.0);

                return Positioned(
                  left: x,
                  top: y,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Opacity(
                      opacity: opacity,
                      child: Icon(
                        i % 2 == 0 ? Icons.cake : Icons.celebration,
                        size: size,
                        color: color,
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
