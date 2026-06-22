import 'package:flutter/material.dart';
import '../../models/club.dart';

class AppTheme {
  static ThemeData fromClub(Club club) {
    // Convertimos HEX del backend a Color
    final primary =
        _parseHexColor(club.colorPrimary) ?? const Color(0xFF2563EB);
    final secondary =
        _parseHexColor(club.colorSecondary) ?? const Color(0xFF1E40AF);
    final accent =
        _parseHexColor(club.colorAccent) ?? const Color(0xFFFACC15);

    // Esquema de colores base
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: accent,            // Texto sobre primario (AppBar, BottomNav)
      secondary: secondary,
      onSecondary: accent,
      background: secondary,        // Fondo general
      onBackground: Colors.black87,   
      surface: Colors.white,
      onSurface: Colors.black87,      // Texto sobre superficies por defecto
      error: Colors.red,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,

      // 🔥 Fondo de toda la app
      scaffoldBackgroundColor: secondary,

      // ===== AppBar: fondo primario + texto/acento =====
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: accent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: accent,
        ),
        iconTheme: IconThemeData(
          color: accent,
        ),
      ),

      // ===== Botones =====
      elevatedButtonTheme: ElevatedButtonThemeData(
  style: ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: accent,
  ),
),

      // ===== BottomNavigationBar =====
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: primary,
        selectedItemColor: accent,
        unselectedItemColor: accent.withOpacity(0.6),
      ),

      // ===== Texto global basado en la paleta del club =====
      textTheme: TextTheme(
  bodyLarge: TextStyle(color: primary),
  bodyMedium: TextStyle(color: primary),
  bodySmall: TextStyle(color: secondary),
  titleLarge: TextStyle(
    color: primary,
    fontWeight: FontWeight.bold,
  ),
  titleMedium: TextStyle(
    color: primary,
    fontWeight: FontWeight.w600,
  ),
  titleSmall: TextStyle(color: primary),
  labelLarge: TextStyle(
    color: accent,
    fontWeight: FontWeight.w600,
  ),
),



      // Íconos globales con color secundario
      iconTheme: IconThemeData(color: secondary),
    );
  }

  // Convierte "#RRGGBB" o "#AARRGGBB" a Color
  static Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var h = hex.trim();
    if (h.isEmpty) return null;

    if (h.startsWith('#')) h = h.substring(1);
    if (h.length == 6) h = 'FF$h'; // agrega alpha si falta

    if (h.length != 8) return null;

    final value = int.tryParse(h, radix: 16);
    if (value == null) return null;

    return Color(value);
  }
}