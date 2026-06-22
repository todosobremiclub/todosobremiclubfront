import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/config/api_config.dart';
import '../../core/services/storage_service.dart';
import '../../core/utils/date_utils.dart';

class CarnetScreen extends StatefulWidget {
  final AppSession session;

  const CarnetScreen({super.key, required this.session});

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends State<CarnetScreen> {
  Uint8List? _fotoPreviewBytes;
  bool _subiendoFoto = false;

  Future<void> _tomarFotoYEnviar() async {
    if (_subiendoFoto) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 60,
      maxWidth: 720,
      maxHeight: 720,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    setState(() {
      _fotoPreviewBytes = bytes;
      _subiendoFoto = true;
    });

    try {
      final token = widget.session.token;
      final socio = widget.session.socioObj;

      final res = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/app/socios/photo-request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'socio_id': socio.id,
          'foto_base64': base64Encode(bytes),
          'filename': file.name,
          'mimetype': 'image/jpeg',
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode != 200 || data['ok'] != true) {
        _showMsg('Error enviando foto');
        return;
      }

      _showMsg('Solicitud enviada ✅');
    } catch (_) {
      _showMsg('Error enviando foto');
    } finally {
      if (!mounted) return;
      setState(() {
        _subiendoFoto = false;
      });
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final socio = widget.session.socioObj;
    final club = widget.session.clubObj;
    final scheme = Theme.of(context).colorScheme;

    final ultimoPagoRaw =
        (socio.ultimoPago == null || socio.ultimoPago!.isEmpty)
            ? '—'
            : socio.ultimoPago!;
    final ultimoPago = DateUtilsApp.isoToMesAnio(ultimoPagoRaw);

final alDia = socio.alDia == true;

    final qrData = jsonEncode({
      'clubId': club.id,
      'clubNombre': club.nombre,
      'socioId': socio.id,
      'numero': socio.numero,
      'dni': socio.dni,
      'nombre': socio.nombre,
      'apellido': socio.apellido,
      'actividad': socio.actividad,
      'categoria': socio.categoria,
      'fechaIngreso': socio.fechaIngreso,
      'alDia': socio.alDia,
      'ultimoPago': socio.ultimoPago,
    });

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxCardWidth = 360.0;
          final horizontalPadding = 16.0 * 2;
          final availableWidth =
              (constraints.maxWidth - horizontalPadding)
                  .clamp(280.0, maxCardWidth);
          final cardWidth = availableWidth;

          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      final offsetY = (1 - value) * 18;
                      final scale = 0.985 + (value * 0.015);

                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, offsetY),
                          child: Transform.scale(
                            scale: scale,
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: cardWidth,
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo arriba a la izquierda, sin líneas de encabezado
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: _ClubLogo(
                                  logoUrl: club.logoUrl,
                                  borderColor: scheme.secondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Foto + nombre + número
                          Center(
                            child: Column(
                              children: [
                                _SocioAvatar(
                                  fotoUrl: socio.fotoUrl,
                                  borderColor: scheme.secondary,
                                  fotoPreviewBytes: _fotoPreviewBytes,
                                  cargando: _subiendoFoto,
                                  onTapCamera: _tomarFotoYEnviar,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  socio.nombreCompleto,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'DNI: ${socio.dni} • Socio Nº ${socio.numero}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: scheme.onPrimary.withOpacity(0.9),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          _datoRow(context, 'Actividad', socio.actividad),
                          _datoRow(context, 'Categoría', socio.categoria),
                          _datoRow(
                            context,
                            'Año Nac.',
                            DateUtilsApp.yearFromIso(socio.fechaNacimiento),
                          ),
                          _datoRow(
                            context,
                            'Ingreso',
                            DateUtilsApp.isoToDMY(socio.fechaIngreso),
                          ),

                          const SizedBox(height: 10),

                          

                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: alDia
    ? Colors.greenAccent.withOpacity(0.15)
    : Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
  alDia ? Icons.check_circle : Icons.cancel,
  color: alDia ? Colors.greenAccent : Colors.redAccent,
  size: 20,
),

                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Último pago',
                                        style: TextStyle(
                                          color: scheme.onPrimary.withOpacity(0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        ultimoPago,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: socio.alDia
                                      ? Colors.greenAccent
                                      : Colors.redAccent,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          Center(
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final maxSide = c.maxWidth * 0.58;
                                final qrSize = maxSide.clamp(96.0, 140.0);

                                return Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: SizedBox(
                                    width: qrSize,
                                    height: qrSize,
                                    child: QrImageView(
                                      data: qrData,
                                      backgroundColor: Colors.white,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _datoRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: scheme.onPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubLogo extends StatelessWidget {
  final String? logoUrl;
  final Color borderColor;

  const _ClubLogo({
    required this.logoUrl,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = (logoUrl ?? '').trim().isNotEmpty;

    if (hasLogo) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor.withOpacity(0.5)),
        ),
        padding: const EdgeInsets.all(4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            logoUrl!,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/img/logo-tsmc.png',
          fit: BoxFit.contain,
        ),
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

class _SocioAvatar extends StatelessWidget {
  final String? fotoUrl;
  final Color borderColor;
  final Uint8List? fotoPreviewBytes;
  final bool cargando;
  final VoidCallback onTapCamera;

  const _SocioAvatar({
    required this.fotoUrl,
    required this.borderColor,
    required this.fotoPreviewBytes,
    required this.cargando,
    required this.onTapCamera,
  });

  @override
  Widget build(BuildContext context) {
    final rawFoto = (fotoUrl ?? '').trim();
    final hasFoto = rawFoto.isNotEmpty;
    final dataFotoBytes = _bytesFromDataImageUrl(rawFoto);

    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor.withOpacity(0.7),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: fotoPreviewBytes != null
                  ? Image.memory(
                      fotoPreviewBytes!,
                      fit: BoxFit.cover,
                    )
                  : dataFotoBytes != null
                      ? Image.memory(
                          dataFotoBytes,
                          fit: BoxFit.cover,
                        )
                      : hasFoto
                          ? Image.network(
                              rawFoto,
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              Icons.person,
                              size: 44,
                              color: Colors.white70,
                            ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: InkWell(
              onTap: cargando ? null : onTapCamera,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.5,
                  ),
                ),
                child: cargando
                    ? Padding(
                        padding: const EdgeInsets.all(5),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.photo_camera,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}