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

  // ✅ NUEVO: indica si el club tiene contratado el add-on de WhatsApp.
  // Se usa para mostrar/ocultar los selectores de canal (app/WhatsApp/ambos)
  // en notificaciones y bienvenidas, igual que en el panel web
  // (window.currentClub?.whatsapp_habilitado === true).
  final bool whatsappHabilitado;

  Club({
    required this.id,
    required this.nombre,
    this.logoUrl,
    this.colorPrimary,
    this.colorSecondary,
    this.colorAccent,
    this.instagramUrl,
    required this.transferenciaHabilitada,
    this.whatsappHabilitado = false,
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

      // ✅ NUEVO
      whatsappHabilitado:
          json['whatsapp_habilitado'] == true,
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
      'whatsapp_habilitado': whatsappHabilitado,
    };
  }
}