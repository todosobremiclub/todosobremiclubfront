import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_page_curl/flutter_page_curl.dart';
import '../../core/services/storage_service.dart';
import '../../services/noticias_service.dart';
import 'noticia_detalle_screen.dart';

class NoticiasScreen extends StatefulWidget {
  final AppSession session;
  final ValueChanged<int>? onUnreadCountChanged;

  const NoticiasScreen({
    super.key,
    required this.session,
    this.onUnreadCountChanged,
  });

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  static const String _kNoticiasLeidas = 'app_noticias_leidas';

  final _service = NoticiasService();
  late Future<_NoticiasViewData> _future;
  int _pageIndex = 0;
  Set<String> _leidas = <String>{};

  @override
  void initState() {
    super.initState();
    _future = _loadNoticiasViewData();
  }

  Future<_NoticiasViewData> _loadNoticiasViewData() async {
    final noticias = await _service.getNoticias(
      token: widget.session.token,
      clubId: widget.session.clubObj.id,
    );

    final prefs = await SharedPreferences.getInstance();
    _leidas = prefs.getStringList(_kNoticiasLeidas)?.toSet() ?? <String>{};

    if (noticias.isNotEmpty) {
      final primeraKey = _noticiaKey(noticias.first);
      if (!_leidas.contains(primeraKey)) {
        _leidas = {..._leidas, primeraKey};
        await prefs.setStringList(_kNoticiasLeidas, _leidas.toList());
      }
    }

    final unreadCount =
        noticias.where((n) => !_leidas.contains(_noticiaKey(n))).length;

    widget.onUnreadCountChanged?.call(unreadCount);

    return _NoticiasViewData(
      noticias: noticias,
      unreadCount: unreadCount,
    );
  }

  String _noticiaKey(Map<String, dynamic> noticia) {
    final id = (noticia['id'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;

    final titulo = (noticia['titulo'] ?? '').toString().trim();
    final fecha = (noticia['fecha'] ?? '').toString().trim();
    return '$titulo|$fecha';
  }

  Future<void> _marcarComoLeida(
    Map<String, dynamic> noticia,
    List<Map<String, dynamic>> todasLasNoticias,
  ) async {
    final key = _noticiaKey(noticia);
    if (_leidas.contains(key)) return;

    _leidas = {..._leidas, key};

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kNoticiasLeidas, _leidas.toList());

    final unreadCount = todasLasNoticias
        .where((n) => !_leidas.contains(_noticiaKey(n)))
        .length;

    widget.onUnreadCountChanged?.call(unreadCount);

    if (!mounted) return;
    setState(() {
      _future = Future.value(
        _NoticiasViewData(
          noticias: todasLasNoticias,
          unreadCount: unreadCount,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Text(
              'Noticias',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<_NoticiasViewData>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        'Error: ${snap.error}',
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }

                  final data = snap.data!;
                  final noticias = data.noticias;

                  if (noticias.isEmpty) {
  return const Center(
    child: Text(
      'Sin noticias.',
      style: TextStyle(color: Colors.black),
    ),
  );
}

                  final pages = noticias.map((n) {
                    final titulo = (n['titulo'] ?? '').toString();
                    final texto = (n['texto'] ?? '').toString();
                    final fecha = (n['fecha'] ?? '').toString();
                    final imagenUrl = (n['imagen_url'] ?? '').toString();
                    final nueva = !_leidas.contains(_noticiaKey(n));

                    String fechaLinda = '';
                    if (fecha.isNotEmpty) {
                      final d = DateTime.tryParse(fecha);
                      if (d != null) {
                        fechaLinda =
                            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
                      } else {
                        fechaLinda = fecha;
                      }
                    }

                    return GestureDetector(
                      onTap: () async {
                        if (!mounted) return;
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoticiaDetalleScreen(noticia: n),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.black12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (imagenUrl.isNotEmpty)
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.network(
                                    imagenUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_outlined,
                                          size: 42,
                                          color: Colors.black45,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  height: 180,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: Icon(
                                      Icons.article_outlined,
                                      size: 52,
                                      color: Colors.black38,
                                    ),
                                  ),
                                ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    20,
                                    22,
                                    20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                                                                    if (nueva)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                'Nueva',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        titulo,
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Georgia',
                                          color: Colors.black,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Expanded(
                                        child: Text(
                                          texto.isEmpty
                                              ? 'Toca para ver la noticia completa.'
                                              : texto,
                                          maxLines: 7,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            height: 1.5,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),

Row(
  crossAxisAlignment: CrossAxisAlignment.center, // ✅ misma altura
  children: [
    if (fechaLinda.isNotEmpty)
      Text(
        fechaLinda,
        style: const TextStyle(
          fontSize: 13,             // ✅ mismo tamaño
          color: Colors.black45,    // ✅ mismo color
          fontStyle: FontStyle.italic,
        ),
      ),
    const Spacer(),
    const Text(
      'Tocar para abrir',
      style: TextStyle(
        fontSize: 13,
        color: Colors.black45,
        fontStyle: FontStyle.italic,
      ),
    ),
  ],
),
                                    ], // ✅ cierra Column interno
                                  ), // ✅ cierra Column
                                ), // ✅ cierra Padding
                              ), // ✅ cierra Expanded
                            ], // ✅ cierra children del Column principal del card
                          ),
                        ),
                      ),
                    );
                  }).toList();


                    return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Nuevas sin leer: ${data.unreadCount}',
                            style: const TextStyle(
                              color: Colors.black54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: PageCurlView(
                              children: pages,
                              radius: 0.08,
                              shadowWidth: 0.16,
                              backOpacity: 0.55,
                              edgeZoneWidth: 0.22,
                              animationDuration:
                                  const Duration(milliseconds: 450),
                              animationCurve: Curves.easeOutCubic,
                              onPageChanged: (page) async {
                                if (!mounted) return;
                                setState(() => _pageIndex = page);
                                await _marcarComoLeida(
                                  noticias[page],
                                  noticias,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            noticias.length,
                            (i) => AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: i == _pageIndex ? 20 : 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(99),
                                color: i == _pageIndex
                                    ? Colors.black
                                    : Colors.black.withOpacity(0.25),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _NoticiasViewData {
  final List<Map<String, dynamic>> noticias;
  final int unreadCount;

  const _NoticiasViewData({
    required this.noticias,
    required this.unreadCount,
  });
}
