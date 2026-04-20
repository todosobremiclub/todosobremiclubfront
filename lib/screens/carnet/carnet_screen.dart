import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';

import '../../core/services/storage_service.dart';
import '../../core/utils/date_utils.dart';

class CarnetScreen extends StatelessWidget {
  final AppSession session;
  const CarnetScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final socio = session.socioObj;
    final club = session.clubObj;
    final scheme = Theme.of(context).colorScheme;

    final ultimoPagoRaw =
        (socio.ultimoPago == null || socio.ultimoPago!.isEmpty)
            ? '—'
            : socio.ultimoPago!;
    final ultimoPago = DateUtilsApp.isoToMesAnio(ultimoPagoRaw);

    // Datos para el QR
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
          final maxCardWidth = 420.0;
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
                  padding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ====================================================
                        // HEADER CLUB
                        // ====================================================
                        Row(
                          children: [
                            _ClubLogo(
                              logoUrl: club.logoUrl,
                              borderColor: scheme.secondary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                club.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: scheme.onPrimary.withOpacity(0.3),
                          thickness: 1,
                        ),
                        const SizedBox(height: 12),

                        // ====================================================
                        // FOTO + NOMBRE + NÚMERO
                        // ====================================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _SocioAvatar(
                              fotoUrl: socio.fotoUrl,
                              borderColor: scheme.secondary,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    socio.nombreCompleto,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: scheme.onPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'DNI: ${socio.dni}',
                                    style: TextStyle(
                                      color:
                                          scheme.onPrimary.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Socio Nº ${socio.numero}',
                                    style: TextStyle(
                                      color:
                                          scheme.onPrimary.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ====================================================
                        // DATOS DEL SOCIO
                        // ====================================================
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

                        // ====================================================
                        // ÚLTIMO PAGO
                        // ====================================================
                        Row(
                          children: [
                            Text(
                              'Último pago',
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: socio.alDia
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              ultimoPago,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),

                        // ====================================================
                        // QR CODE (MÁS GRANDE E INTEGRADO)
                        // ====================================================
                        Center(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              // tomamos el ancho disponible dentro del carnet
                              final maxSide = c.maxWidth * 0.7;
                              final qrSize =
                                  maxSide.clamp(140.0, 260.0); // grande pero seguro

                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18),
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
  const _ClubLogo({required this.logoUrl, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final hasLogo = (logoUrl ?? '').trim().isNotEmpty;
    if (hasLogo) {
      // logo del club desde backend
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

    // fallback: logo TSMC local
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

class _SocioAvatar extends StatelessWidget {
  final String? fotoUrl;
  final Color borderColor;
  const _SocioAvatar({required this.fotoUrl, required this.borderColor});

  @override
  Widget build(BuildContext context) {
    final hasFoto = (fotoUrl ?? '').trim().isNotEmpty;
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor.withOpacity(0.7),
          width: 3,
        ),
      ),
      child: ClipOval(
        child: hasFoto
            ? Image.network(
                fotoUrl!,
                fit: BoxFit.cover,
              )
            : const Icon(Icons.person, size: 50, color: Colors.white70),
      ),
    );
  }
}