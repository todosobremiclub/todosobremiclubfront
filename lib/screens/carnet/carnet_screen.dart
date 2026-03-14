import 'package:flutter/material.dart';
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

    final ultimoPagoRaw = (socio.ultimoPago == null || socio.ultimoPago!.isEmpty)
        ? '—'
        : socio.ultimoPago!;

    // 🔥 Convertimos a "Mes Año"
    final ultimoPago = DateUtilsApp.isoToMesAnio(ultimoPagoRaw);

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 420,
                    ),
                    child: Container(
                      height: 210,
                      decoration: BoxDecoration(
                        color: scheme.primary,              // 🎨 Fondo del carnet
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          // ========= Columna izquierda =========
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _SocioAvatar(
                                fotoUrl: socio.fotoUrl,
                                borderColor: scheme.secondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Socio Nº ${socio.numero}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(width: 12),

                          // ========= Columna derecha =========
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ---- Logo + nombre del club ----
                                Row(
                                  children: [
                                    _ClubLogo(
                                      logoUrl: club.logoUrl,
                                      borderColor: scheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        club.nombre,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: scheme.secondary,         // texto del club
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                Divider(
                                  color: scheme.secondary.withOpacity(0.4),
                                ),

                                // ---- Nombre socio ----
                                Text(
                                  socio.nombreCompleto,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: scheme.secondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                // ---- Datos ----
                                _datoRow(context, 'Actividad', socio.actividad),
                                _datoRow(context, 'Categoría', socio.categoria),
                                _datoRow(
                                    context,
                                    'Año Nac.',
                                    DateUtilsApp.yearFromIso(socio.fechaNacimiento)),
                                _datoRow(
                                    context,
                                    'Ingreso',
                                    DateUtilsApp.isoToDMY(socio.fechaIngreso)),

                                const Spacer(),

                                // ---- Último pago ----
                                Row(
                                  children: [
                                    Text(
                                      'Último pago',
                                      style: TextStyle(
                                        color: scheme.secondary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.circle,
                                      size: 10,
                                      color: socio.alDia
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      ultimoPago,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: scheme.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
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
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      padding: const EdgeInsets.all(4),
      child: hasLogo
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.shield, color: Colors.black54, size: 18),
              ),
            )
          : const Icon(Icons.shield, color: Colors.black54, size: 18),
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
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor.withOpacity(0.7),
          width: 2.5,
        ),
      ),
      child: ClipOval(
        child: hasFoto
            ? Image.network(
                fotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.person, size: 40, color: Colors.white70),
              )
            : const Icon(Icons.person, size: 40, color: Colors.white70),
      ),
    );
  }
}
