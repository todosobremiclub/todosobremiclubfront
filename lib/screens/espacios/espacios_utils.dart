// lib/screens/espacios/espacios_utils.dart
//
// Helpers compartidos por las pantallas de Espacios y Clases (fechas en
// español sin depender de intl, y limpieza de mensajes de error).
import 'package:flutter/material.dart';

const _diasLargo = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
const _diasCorto = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
const _mesesCorto = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// "2026-10-26" -> DateTime local (sin zona horaria). null si es inválida.
DateTime? parseFecha(String? iso) {
  if (iso == null || iso.length < 10) return null;
  final p = iso.substring(0, 10).split('-');
  if (p.length != 3) return null;
  final y = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  final d = int.tryParse(p[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String fechaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// DateTime.weekday: 1=lunes..7=domingo. El backend usa 0=domingo..6=sábado.
String diaLargo(int diaSemana) => _diasLargo[diaSemana % 7];

/// "Lun 26/10"
String fechaCorta(String? iso) {
  final d = parseFecha(iso);
  if (d == null) return iso ?? '';
  return '${_diasCorto[d.weekday % 7]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

/// "Lunes 26 de oct"
String fechaLarga(String? iso) {
  final d = parseFecha(iso);
  if (d == null) return iso ?? '';
  return '${_diasLargo[d.weekday % 7]} ${d.day} de ${_mesesCorto[d.month - 1]}';
}

/// "26/10/2026"
String fechaDMY(String? iso) {
  final d = parseFecha(iso);
  if (d == null) return iso ?? '';
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// "Exception: algo" -> "algo"
String mensajeError(Object e) => e.toString().replaceFirst('Exception: ', '');

/// "#ff8800" -> Color. null si es inválido.
Color? colorDesdeHex(String? hex) {
  if (hex == null) return null;
  var h = hex.replaceAll('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

/// Estado de una reserva -> etiqueta y color.
({String label, Color color}) estadoReserva(String estado) {
  switch (estado) {
    case 'pendiente':
      return (label: 'Pendiente de confirmación', color: Colors.orange);
    case 'aceptada':
      return (label: 'Confirmada', color: Colors.green);
    case 'rechazada':
      return (label: 'Rechazada', color: Colors.red);
    case 'cancelada':
      return (label: 'Cancelada', color: Colors.grey);
    case 'vencida':
      return (label: 'Vencida (no se confirmó a tiempo)', color: Colors.grey);
    default:
      return (label: estado, color: Colors.grey);
  }
}

class EstadoVacio extends StatelessWidget {
  final IconData icon;
  final String texto;
  const EstadoVacio({super.key, required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.black26),
            const SizedBox(height: 12),
            Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}

class EstadoError extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const EstadoError({super.key, required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
