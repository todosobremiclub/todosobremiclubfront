import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/config/api_config.dart';
import '../../core/services/session_service.dart';
import '../../core/services/storage_service.dart';

class ControlAccesoScreen extends StatefulWidget {
  const ControlAccesoScreen({super.key});

  @override
  State<ControlAccesoScreen> createState() => _ControlAccesoScreenState();
}

class _ControlAccesoScreenState extends State<ControlAccesoScreen> {
  final MobileScannerController _controller = MobileScannerController();

  bool _escaneando = true;
  bool _verificando = false;
  Map<String, dynamic>? _socioData;
  bool? _habilitado;
  String _mensaje = '';
  String _ultimoFmt = '—';

  static const List<String> _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  String _fmtYM(String? ym) {
    if (ym == null) return '—';
    final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(ym.trim());
    if (match == null) return '—';
    final y = int.tryParse(match.group(1)!);
    final mo = int.tryParse(match.group(2)!);
    if (y == null || mo == null || mo < 1 || mo > 12) return '—';
    return '${_meses[mo - 1]} $y';
  }

  void _mostrarRechazo(String mensaje) {
    setState(() {
      _escaneando = false;
      _verificando = false;
      _socioData = null;
      _habilitado = false;
      _mensaje = mensaje;
      _ultimoFmt = '—';
    });
  }

  /// 🔒 El QR ya no se "interpreta" en el celular: se manda al servidor, que valida la firma, que
  /// el carnet sea de ESTE club y calcula el estado de la cuota con datos reales.
  /// - QR nuevo: un token firmado (texto).
  /// - QR viejo (JSON con socioId, de socios que no actualizaron la app): se manda solo el socioId.
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_escaneando || _verificando) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final raw = barcodes.first.rawValue?.trim();
    if (raw == null || raw.isEmpty || raw.length > 2000) return;

    Map<String, dynamic> cuerpo;
    if (raw.startsWith('{')) {
      try {
        final obj = jsonDecode(raw);
        if (obj is! Map || obj['socioId'] == null) {
          _mostrarRechazo('El código escaneado no es un carnet válido.');
          return;
        }
        cuerpo = {'legacy': {'socioId': obj['socioId'].toString()}};
      } catch (_) {
        _mostrarRechazo('El código escaneado no es un carnet válido.');
        return;
      }
    } else {
      cuerpo = {'qr': raw};
    }

    setState(() {
      _escaneando = false;
      _verificando = true;
    });

    try {
      final admin = await StorageService.loadAdminSession();
      if (admin == null) {
        _mostrarRechazo('Sesión vencida. Volvé a iniciar sesión.');
        return;
      }

      final res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/club/${admin.clubId}/acceso/verificar'),
            headers: {
              'Authorization': 'Bearer ${admin.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(cuerpo),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 401) {
        await SessionService.forceAdminLogout();
        return;
      }

      final data = jsonDecode(res.body);
      if (res.statusCode != 200 || data is! Map || data['ok'] != true) {
        _mostrarRechazo(
          (data is Map ? data['error']?.toString() : null) ?? 'No se pudo validar el carnet.',
        );
        return;
      }

      if (!mounted) return;
      final socio = data['socio'] is Map ? Map<String, dynamic>.from(data['socio'] as Map) : null;
      setState(() {
        _verificando = false;
        _socioData = socio;
        _habilitado = data['habilitado'] == true;
        _mensaje = data['motivo']?.toString() ?? '';
        _ultimoFmt = _fmtYM(socio?['ultimo_pago']?.toString());
      });
    } catch (_) {
      if (!mounted) return;
      _mostrarRechazo('No se pudo validar el carnet (revisá la conexión) e intentá de nuevo.');
    }
  }

  void _escanearOtro() {
    setState(() {
      _escaneando = true;
      _verificando = false;
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