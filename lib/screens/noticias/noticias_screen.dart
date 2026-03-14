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
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        // Mientras carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Si hubo error
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onBackground),
            ),
          );
        }

        final noticias = snapshot.data ?? [];

        if (noticias.isEmpty) {
          return Center(
            child: Text(
              'No hay noticias',
              style: TextStyle(color: scheme.onBackground),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: noticias.length,
          itemBuilder: (context, i) {
            final n = noticias[i];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.primary,            // 🔥 Fondo PRIMARIO
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: _buildMiniatura(n, scheme),
                title: Text(
                  (n['titulo'] ?? '') as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onPrimary,       // 🔥 TEXTO ACENTO
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: scheme.onPrimary,         // 🔥 ICONO ACENTO
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          NoticiaDetalleScreen(noticia: n),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Miniatura noticia
  Widget _buildMiniatura(Map<String, dynamic> n, ColorScheme scheme) {
    final imagenUrl = (n['imagen_url'] ?? '') as String;

    if (imagenUrl.isEmpty) {
      return Icon(
        Icons.image,
        size: 40,
        color: scheme.onPrimary,    // 🔥 ícono acento
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imagenUrl,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.image,
          size: 40,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}