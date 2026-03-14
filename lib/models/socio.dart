class Socio {
  final String id;
  final int numero;
  final String dni;
  final String nombre;
  final String apellido;

  final String actividad;
  final String categoria;

  final String? fotoUrl;
  final String? fechaNacimiento; // "YYYY-MM-DD" o Date serializado
  final String? fechaIngreso;    // "YYYY-MM-DD"

  final String? ultimoPago;      // "YYYY-MM"
  final bool alDia;

  Socio({
    required this.id,
    required this.numero,
    required this.dni,
    required this.nombre,
    required this.apellido,
    required this.actividad,
    required this.categoria,
    this.fotoUrl,
    this.fechaNacimiento,
    this.fechaIngreso,
    this.ultimoPago,
    required this.alDia,
  });

  factory Socio.fromJson(Map<String, dynamic> json) {
    return Socio(
      id: (json['id'] ?? '').toString(),
      numero: int.tryParse((json['numero'] ?? 0).toString()) ?? 0,
      dni: (json['dni'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      apellido: (json['apellido'] ?? '').toString(),
      actividad: (json['actividad'] ?? '').toString(),
      categoria: (json['categoria'] ?? '').toString(),
      fotoUrl: (json['foto_url'] ?? json['fotoUrl'])?.toString(),
      fechaNacimiento: (json['fecha_nacimiento'] ?? json['nacimiento'])?.toString(),
      fechaIngreso: (json['fecha_ingreso'] ?? json['ingreso'])?.toString(),
      ultimoPago: (json['ultimo_pago'] ?? json['ultimoPago'])?.toString(),
      alDia: (json['al_dia'] ?? json['alDia'] ?? false) == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'numero': numero,
      'dni': dni,
      'nombre': nombre,
      'apellido': apellido,
      'actividad': actividad,
      'categoria': categoria,
      'foto_url': fotoUrl,
      'fecha_nacimiento': fechaNacimiento,
      'fecha_ingreso': fechaIngreso,
      'ultimo_pago': ultimoPago,
      'al_dia': alDia,
    };
  }

  String get nombreCompleto => '$nombre $apellido'.trim();

  String get anioNacimiento {
    final s = (fechaNacimiento ?? '').toString();
    if (s.length >= 4) return s.substring(0, 4);
    return '—';
  }
}