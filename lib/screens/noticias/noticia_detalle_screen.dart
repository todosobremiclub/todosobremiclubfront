import 'package:flutter/material.dart';

class NoticiaDetalleScreen extends StatelessWidget {
  final Map<String, dynamic> noticia;

  const NoticiaDetalleScreen({
    super.key,
    required this.noticia,
  });

  @override
  Widget build(BuildContext context) {
    final String titulo = (noticia['titulo'] ?? '') as String;
    final String texto = (noticia['texto'] ?? '') as String;
    final String imagenUrl = (noticia['imagen_url'] ?? '') as String;
    final String fecha = (noticia['fecha'] ?? '').toString();

    String fechaLinda = '';
    if (fecha.isNotEmpty) {
      final d = DateTime.tryParse(fecha);
      if (d != null) {
        const meses = [
          'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
          'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
        ];
        fechaLinda = '${d.day} de ${meses[d.month - 1]} de ${d.year}';
      } else {
        fechaLinda = fecha;
      }
    }

    final hasImagen = imagenUrl.isNotEmpty;
    final topSafe = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            stretch: true,
            backgroundColor: Colors.black,
            expandedHeight: hasImagen ? 280 : 120,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _BotonFlotante(
                icono: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: hasImagen
                  ? Container(
                      color: Colors.black,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Positioned(
                            top: topSafe + 28,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Image.network(
                              imagenUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    size: 56,
                                    color: Colors.black38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Degradé para que el título se lea sobre la foto
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.0),
                                  Colors.black.withOpacity(0.15),
                                  Colors.black.withOpacity(0.75),
                                ],
                                stops: const [0.4, 0.7, 1.0],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 18,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (fechaLinda.isNotEmpty)
                                  Text(
                                    fechaLinda.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 11,
                                      letterSpacing: 0.8,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  titulo.isEmpty ? 'Noticia' : titulo,
                                  style: const TextStyle(
                                    fontFamily: 'Georgia',
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(color: Colors.black87),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Si no hay imagen, el título y la fecha van acá arriba
                  if (!hasImagen) ...[
                    if (fechaLinda.isNotEmpty)
                      Text(
                        fechaLinda.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black45,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 6),
                    if (titulo.isNotEmpty)
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          height: 1.2,
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],

                  Container(
                    height: 3,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    texto.isEmpty ? 'Sin contenido.' : texto,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.65,
                      color: Colors.black87,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonFlotante extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;

  const _BotonFlotante({required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icono, color: Colors.white, size: 20),
      ),
    );
  }
}