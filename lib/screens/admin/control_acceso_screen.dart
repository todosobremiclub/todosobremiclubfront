import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ControlAccesoScreen extends StatefulWidget {
  const ControlAccesoScreen({super.key});

  @override
  State<ControlAccesoScreen> createState() => _ControlAccesoScreenState();
}

class _ControlAccesoScreenState extends State<ControlAccesoScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _escaneando = true;
  Map<String, dynamic>? _socioData;
  bool? _habilitado;
  String _mensaje = '';
  String _ultimoFmt = '—';

  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  int? _ymToIndex(String? ym) {
    if (ym == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(ym.trim());
    if (match == null) return null;
    final y = int.tryParse(match.group(1)!);
    final mo = int.tryParse(match.group(2)!);
    if (y == null || mo == null || mo < 1 || mo > 12) return null;
    return (y * 12) + (mo - 1);
  }

  String _fmtYM(String? ym) {
    final idx = _ymToIndex(ym);
    if (idx == null) return '—';
    final y = idx ~/ 12;
    final m = idx % 12;
    return '${_meses[m]} $y';
  }

  int _nowIndex() {
    final now = DateTime.now();
    return now.year * 12 + (now.month - 1);
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_escaneando) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      setState(() {
        _escaneando = false;
        _socioData = null;
        _habilitado = false;
        _mensaje = 'El código escaneado no es un carnet válido.';
        _ultimoFmt = '—';
      });
      return;
    }

    final ultimoPago = data['ultimoPago']?.toString();
    final last = _ymToIndex(ultimoPago);
    final now = _nowIndex();

    bool ok;
    String mensaje;

    if (last == null) {
      ok = false;
      mensaje = 'No hay último pago válido en el QR.';
    } else if (last >= (now - 1) && last <= (now + 1)) {
      ok = true;
      mensaje = 'Cuota al día (mes actual / anterior / siguiente).';
    } else {
      ok = false;
      mensaje = 'Cuota vencida (último pago anterior al mes anterior).';
    }

    setState(() {
      _escaneando = false;
      _socioData = data;
      _habilitado = ok;
      _mensaje = mensaje;
      _ultimoFmt = _fmtYM(ultimoPago);
    });
  }

  void _escanearOtro() {
    setState(() {
      _escaneando = true;
      _socioData = null;
      _habilitado = null;
      _mensaje = '';
      _ultimoFmt = '—';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control de acceso')),
      body: _escaneando ? _buildScanner() : _buildResultado(),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Apuntá la cámara al código QR del carnet',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultado() {
    final ok = _habilitado == true;
    final color = ok ? Colors.green : Colors.red;
    final pill = ok ? 'HABILITADO ✅' : 'RECHAZADO ❌';

    final nombre = _socioData?['nombre'] ?? '';
    final apellido = _socioData?['apellido'] ?? '';
    final numero = _socioData?['numero']?.toString() ?? '—';
    final actividad = _socioData?['actividad'] ?? '—';
    final categoria = _socioData?['categoria'] ?? '—';

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color, width: 2),
            ),
            child: Column(
              children: [
                Text(
                  pill,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(_mensaje, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_socioData != null) ...[
            Text(
              '$apellido, $nombre',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Socio N° $numero'),
            const SizedBox(height: 8),
            Text('Actividad: $actividad'),
            Text('Categoría: $categoria'),
            const SizedBox(height: 8),
            Text('Último pago: $_ultimoFmt'),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _escanearOtro,
              child: const Text('Escanear siguiente'),
            ),
          ),
        ],
      ),
    );
  }
}