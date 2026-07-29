import 'package:flutter/material.dart';
import '../../core/services/push_service.dart';

class PushDebugScreen extends StatefulWidget {
  final String clubId;

  const PushDebugScreen({super.key, required this.clubId});

  @override
  State<PushDebugScreen> createState() => _PushDebugScreenState();
}

class _PushDebugScreenState extends State<PushDebugScreen> {
  String _resultado = 'Presioná "Ejecutar diagnóstico" para empezar.';
  bool _cargando = false;

  Future<void> _ejecutar() async {
    setState(() {
      _cargando = true;
      _resultado = 'Ejecutando...';
    });

    try {
      final resultado = await PushService.runDiagnostics(widget.clubId);
      setState(() => _resultado = resultado);
    } catch (e) {
      setState(() => _resultado = 'ERROR GENERAL: $e');
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnóstico Push (temporal)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Club ID: ${widget.clubId}'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _cargando ? null : _ejecutar,
              child: Text(_cargando ? 'Ejecutando...' : 'Ejecutar diagnóstico'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _resultado,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}