import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
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
                const SizedBox(height: 10),
                if (hoy.isEmpty)
                  Text(
                    'Hoy no hay cumpleaños.',
                    style: TextStyle(color: scheme.onBackground),
                  )
                else
                  ...hoy.map((s) => _buildCumpleHoyCard(context, s)),
                const SizedBox(height: 28),
                Text(
                  'Este mes cumplen',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onBackground,
                      ),
                ),
                const SizedBox(height: 10),
                if (mes.isEmpty)
                  Text(
                    'No hay más cumpleaños este mes.',
                    style: TextStyle(color: scheme.onBackground),
                  )
                else
                  _buildListaMes(context, mes),
              ],
            ),
            if (hoy.isNotEmpty)
              IgnorePointer(
                ignoring: true,
                child: _BirthdayRain(
                  controller: _rainController,
                  color: scheme.primary,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.primary, width: 2.5),
                  ),
                  child: ClipOval(
                    child: Builder(
                      builder: (context) {
                        final dataBytes = _bytesFromDataImageUrl(foto);

                        if (dataBytes != null) {
                          return Image.memory(dataBytes, fit: BoxFit.cover);
                        }

                        if (foto.isNotEmpty) {
                          return Image.network(
                            foto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: scheme.primary.withOpacity(0.12),
                              child: Icon(
                                Icons.person,
                                color: scheme.primary.withOpacity(0.6),
                              ),
                            ),
                          );
                        }

                        return Container(
                          color: scheme.primary.withOpacity(0.12),
                          child: Icon(
                            Icons.person,
                            color: scheme.primary.withOpacity(0.6),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.cake, size: 13, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '¡Feliz cumpleaños! 🎉',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'HOY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaMes(BuildContext context, List<Map<String, dynamic>> mes) {
    final scheme = Theme.of(context).colorScheme;

    final ordenados = [...mes]
      ..sort((a, b) {
        final da = DateTime.tryParse((a['date'] ?? '').toString())?.day ?? 99;
        final db = DateTime.tryParse((b['date'] ?? '').toString())?.day ?? 99;
        return da.compareTo(db);
      });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        children: List.generate(ordenados.length, (index) {
          final ev = ordenados[index];
          final title = (ev['title'] ?? '').toString();
          final dateStr = (ev['date'] ?? '').toString();
          final dt = DateTime.tryParse(dateStr);
          final dia = dt?.day ?? 0;
          final esUltimo = index == ordenados.length - 1;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: esUltimo
                  ? null
                  : Border(
                      bottom: BorderSide(color: Colors.black.withOpacity(0.06)),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dia > 0 ? '$dia' : '—',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

bool _isDataImageUrl(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  return v.startsWith('data:image/');
}

Uint8List? _bytesFromDataImageUrl(String? value) {
  try {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    if (!_isDataImageUrl(raw)) return null;

    final commaIndex = raw.indexOf(',');
    if (commaIndex < 0) return null;

    final b64 = raw.substring(commaIndex + 1);
    return base64Decode(b64);
  } catch (_) {
    return null;
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