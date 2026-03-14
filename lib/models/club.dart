class Club {
  final String id;
  final String nombre;
  final String? logoUrl;

  final String? colorPrimary;   // "#2563eb"
  final String? colorSecondary; // "#1e40af"
  final String? colorAccent;    // "#facc15"


  // 👉 Nuevo campo para Instagram
  final String? instagramUrl;

  Club({
    required this.id,
    required this.nombre,
    this.logoUrl,
    this.colorPrimary,
    this.colorSecondary,
    this.colorAccent,
    this.instagramUrl,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: (json['id'] ?? '').toString(),

      // tu backend devuelve "nombre"
      // si algún día devuelve "name", también lo soportamos
      nombre: (json['nombre'] ?? json['name'] ?? '').toString(),

      logoUrl: (json['logo_url'] ?? json['logoUrl'])?.toString(),
      colorPrimary: (json['color_primary'] ?? json['colorPrimary'])?.toString(),
      colorSecondary:
          (json['color_secondary'] ?? json['colorSecondary'])?.toString(),
      colorAccent: (json['color_accent'] ?? json['colorAccent'])?.toString(),

      // 👇 Ajustá 'instagram_url' si tu backend devuelve otra clave
      instagramUrl: (json['instagram_url'] ?? json['instagramUrl'] ?? '')
          .toString(),
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
    };
  }
}