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
      onBackground: Colors.white,   // Texto global blanco
      surface: Colors.white,
      onSurface: Colors.white,      // Texto sobre superficies por defecto
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
          foregroundColor: Colors.white,
        ),
      ),

      // ===== BottomNavigationBar =====
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: primary,
        selectedItemColor: accent,
        unselectedItemColor: accent.withOpacity(0.6),
      ),

      // ===== Texto global BLANCO =====
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        labelLarge: TextStyle(color: Colors.white),
      ),

      // Íconos globales blancos
      iconTheme: const IconThemeData(color: Colors.white),
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