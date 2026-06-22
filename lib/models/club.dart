class Club {
  final String id;
  final String nombre;
  final String? logoUrl;

  final String? colorPrimary;   // "#2563eb"
  final String? colorSecondary; // "#1e40af"
  final String? colorAccent;    // "#facc15"

  // ✅ CLAVE PARA TRANSFERENCIAS
  final bool transferenciaHabilitada;

  // 👉 Instagram
  final String? instagramUrl;

  Club({
    required this.id,
    required this.nombre,
    this.logoUrl,
    this.colorPrimary,
    this.colorSecondary,
    this.colorAccent,
    this.instagramUrl,
    required this.transferenciaHabilitada,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: (json['id'] ?? '').toString(),

      nombre: (json['nombre'] ?? json['name'] ?? '').toString(),

      logoUrl: (json['logo_url'] ?? json['logoUrl'])?.toString(),

      colorPrimary:
          (json['color_primary'] ?? json['colorPrimary'])?.toString(),

      colorSecondary:
          (json['color_secondary'] ?? json['colorSecondary'])?.toString(),

      colorAccent:
          (json['color_accent'] ?? json['colorAccent'])?.toString(),

      instagramUrl:
          (json['instagram_url'] ?? json['instagramUrl'])?.toString(),

      // ✅ 🔥 ESTE ES EL FIX IMPORTANTE
      transferenciaHabilitada:
          json['transferencia_habilitada'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'logo_url': logoUrl,
      'color_primary': colorPrimary,
      'color_secondary': colorSecondary,
      'color_accent': colorAccent,
      'instagram_url': instagramUrl,
      'transferencia_habilitada': transferenciaHabilitada,
    };
  }
}