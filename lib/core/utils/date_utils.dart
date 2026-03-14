class DateUtilsApp {
  /// Convierte "YYYY-MM-DD..." a "DD/MM/YYYY"
  static String isoToDMY(String? iso) {
    if (iso == null) return '—';
    final s = iso.trim();
    if (s.length < 10) return s.isEmpty ? '—' : s;
    final y = s.substring(0, 4);
    final m = s.substring(5, 7);
    final d = s.substring(8, 10);
    return '$d/$m/$y';
  }

  /// Devuelve el año de "YYYY-MM-DD"
  static String yearFromIso(String? iso) {
    if (iso == null) return '—';
    final s = iso.trim();
    if (s.length >= 4) return s.substring(0, 4);
    return s.isEmpty ? '—' : s;
  }

  /// 🔥 Convierte "YYYY-MM" o "YYYY-MM-DD" → "Mes Año"
  /// Ejemplo: "2026-02" → "Febrero 2026"
  static String isoToMesAnio(String? iso) {
    if (iso == null || iso.trim().isEmpty) return '—';

    try {
      final meses = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];

      String s = iso.trim();

      // Si viene tipo "2026-02", le agregamos "-01"
      if (s.length == 7) {
        s = '$s-01';
      }

      final dt = DateTime.parse(s);

      return '${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return iso; // Fallback seguro
    }
  }
}
