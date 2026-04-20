import 'package:flutter/material.dart';
import '../../core/services/storage_service.dart';
import '../../services/noticias_service.dart';
import 'noticia_detalle_screen.dart';

class NoticiasScreen extends StatefulWidget {
  final AppSession session;
  const NoticiasScreen({super.key, required this.session});

  @override
  State<NoticiasScreen> createState() => _NoticiasScreenState();
}

class _NoticiasScreenState extends State<NoticiasScreen> {
  final _service = NoticiasService();
  late Future<List<Map<String, dynamic>>> _future;

  int _pageIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _future = _service.getNoticias(
      token: widget.session.token,
      clubId: widget.session.clubObj.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,   // pantalla limpia
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ===== TÍTULO "Noticias" =====
            const Text(
              "Noticias",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snap.error}",
                        style: const TextStyle(color: Colors.black),
                      ),
                    );
                  }

                  final noticias = snap.data ?? [];
                  if (noticias.isEmpty) {
                    return const Center(
                      child: Text(
                        "Sin noticias.",
                        style: TextStyle(color: Colors.black),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: noticias.length,
                            onPageChanged: (i) {
                              setState(() => _pageIndex = i);
                            },
                            itemBuilder: (_, i) {
                              final n = noticias[i];
                              final titulo = (n['titulo'] ?? "").toString();
                              final texto = (n['texto'] ?? "").toString();
                              final fecha = (n['fecha'] ?? "").toString();
                              final img = (n['imagen_url'] ?? "").toString();

                              // formateo fecha
                              String fechaLinda = "";
                              if (fecha.isNotEmpty) {
                                final d = DateTime.tryParse(fecha);
                                if (d != null) {
                                  fechaLinda = "${d.day}/${d.month}/${d.year}";
                                }
                              }

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => NoticiaDetalleScreen(
                                        noticia: n,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(32),
                                    border: Border.all(
                                      color: Colors.black12,
                                      width: 1,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 32,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (fechaLinda.isNotEmpty)
                                        Text(
                                          fechaLinda,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontFamily: 'Georgia',
                                            color: Colors.black54,
                                          ),
                                        ),

                                      const SizedBox(height: 12),

                                      _Typewriter(
                                        text: titulo,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Georgia',
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            noticias.length,
                            (i) => Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _pageIndex
                                    ? Colors.black
                                    : Colors.black.withOpacity(0.3),
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

class _Typewriter extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _Typewriter({
    required this.text,
    required this.style,
  });

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<int> _count;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _count = StepTween(
      begin: 0,
      end: widget.text.length,
    ).animate(_c);
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _count,
      builder: (_, __) => Text(
        widget.text.substring(0, _count.value),
        style: widget.style,
        textAlign: TextAlign.center,
      ),
    );
  }
}
