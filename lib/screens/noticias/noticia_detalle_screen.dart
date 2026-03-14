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

    return Scaffold(
      appBar: AppBar(
        title: Text(titulo.isEmpty ? 'Noticia' : titulo),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen grande arriba (si hay URL)
            if (imagenUrl.isNotEmpty)
              Image.network(
                imagenUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 200,
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 48,
                    ),
                  ),
                ),
              ),

            // Contenido: título + texto
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titulo.isNotEmpty) ...[
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}