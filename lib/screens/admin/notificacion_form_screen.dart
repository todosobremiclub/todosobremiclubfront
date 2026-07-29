import 'package:flutter/material.dart';

import '../../services/admin_api_service.dart';

class NotificacionFormScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const NotificacionFormScreen({
    super.key,
    required this.token,
    required this.clubId,
  });

  @override
  State<NotificacionFormScreen> createState() => _NotificacionFormScreenState();
}

class _NotificacionFormScreenState extends State<NotificacionFormScreen> {
  final _tituloController = TextEditingController();
  final _cuerpoController = TextEditingController();

  bool _enviando = false;

  Future<void> _enviar() async {
    final titulo = _tituloController.text.trim();
    final cuerpo = _cuerpoController.text.trim();

    if (titulo.isEmpty || cuerpo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completá título y mensaje')),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      await AdminApiService.enviarNotificacion(
        token: widget.token,
        clubId: widget.clubId,
        titulo: titulo,
        cuerpo: cuerpo,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Notificación enviada')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _cuerpoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enviar notificación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _tituloController,
              decoration: const InputDecoration(
                labelText: 'Título',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cuerpoController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _enviando ? null : _enviar,
              child: _enviando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar y enviar'),
            ),
          ],
        ),
      ),
    );
  }
}