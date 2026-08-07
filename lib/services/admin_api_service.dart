import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

/// Servicio para las acciones de administración dentro de la app
/// (notificaciones, noticias, pagos, socios, asistencia, ingresos, gastos).
/// Usa el mismo backend que la web de gestión (/club/:clubId/...).
class AdminApiService {
  static Future<Map<String, dynamic>> post({
    required String token,
    required String path,
    required Map<String, dynamic> body,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');

    final res = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta inválida del servidor (HTTP ${res.statusCode})');
    }

    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Error en la operación (HTTP ${res.statusCode})');
    }

    return data;
  }

  static Future<Map<String, dynamic>> get({
    required String token,
    required String path,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$path');

    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    Map<String, dynamic> data;
    try {
      data = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Respuesta inválida del servidor (HTTP ${res.statusCode})');
    }

    if (res.statusCode < 200 || res.statusCode >= 300 || data['ok'] != true) {
      throw Exception(data['error'] ?? 'Error en la operación (HTTP ${res.statusCode})');
    }

    return data;
  }

  // ======================================================
  // Datos del club (logo, colores, etc.)
  // GET /club/:clubId
  // ======================================================
  static Future<Map<String, dynamic>> getClub({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId');
    return Map<String, dynamic>.from(data['club'] ?? data);
  }

  // ======================================================
  // Enviar notificación push
  // ======================================================
  static Future<void> enviarNotificacion({
    required String token,
    required String clubId,
    required String titulo,
    required String cuerpo,
    String destinoTipo = 'todos',
    String? destinoValor1,
    String? destinoValor2,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/notificaciones',
      body: {
        'titulo': titulo,
        'cuerpo': cuerpo,
        // El backend espera el destino ANIDADO dentro de "data"
        // (a diferencia de publicarNoticia, que lo manda en el nivel raíz).
        'data': {
          'destino_tipo': destinoTipo,
          if (destinoValor1 != null && destinoValor1.isNotEmpty)
            'destino_valor1': destinoValor1,
          if (destinoValor2 != null && destinoValor2.isNotEmpty)
            'destino_valor2': destinoValor2,
        },
      },
    );
  }

  // ======================================================
  // Años de nacimiento existentes (para destino de noticias)
  // ======================================================
  static Future<List<int>> getAniosNacimiento({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/noticias/anios-nacimiento');
    final anios = (data['anios'] as List?) ?? [];
    return anios.map((a) => int.parse(a.toString())).toList();
  }

  // ======================================================
  // Publicar noticia
  // ======================================================
  static Future<void> publicarNoticia({
    required String token,
    required String clubId,
    required String titulo,
    required String texto,
    required String destinoTipo,
    String? destinoValor1,
    String? destinoValor2,
    String? imagenBase64,
    String? imagenMimetype,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/noticias',
      body: {
        'titulo': titulo,
        'texto': texto,
        'destino_tipo': destinoTipo,
        if (destinoValor1 != null) 'destino_valor1': destinoValor1,
        if (destinoValor2 != null) 'destino_valor2': destinoValor2,
        if (imagenBase64 != null) 'imagen_base64': imagenBase64,
        if (imagenMimetype != null) 'imagen_mimetype': imagenMimetype,
      },
    );
  }

  // ======================================================
  // Buscar socios (pagos, asistencia, buscar socio)
  // ======================================================
  static Future<List<Map<String, dynamic>>> buscarSocios({
    required String token,
    required String clubId,
    required String query,
  }) async {
    final data = await get(
      token: token,
      path: '/club/$clubId/socios?search=${Uri.encodeQueryComponent(query)}&activo=1&limit=15',
    );
    final socios = (data['socios'] as List?) ?? [];
    return socios.map((s) => Map<String, dynamic>.from(s)).toList();
  }

  // ======================================================
  // Registrar pago de cuota
  // ======================================================
  static Future<void> registrarPago({
    required String token,
    required String clubId,
    required String socioId,
    required int anio,
    required int mes,
    required String fechaPago,
    required String cuentaId,
    required List<Map<String, dynamic>> detallePago,
    required double montoTotalTeorico,
    bool esParcial = false,
    double? montoParcial,
  }) async {
    final montoPagado = esParcial ? (montoParcial ?? 0) : montoTotalTeorico;

    await post(
      token: token,
      path: '/club/$clubId/pagos',
      body: {
        'socio_id': socioId,
        'anio': anio,
        'meses': [mes],
        'fecha_pago': fechaPago,
        'cuenta_id': cuentaId,
        'detalle_pago': detallePago,
        'monto_total_teorico': montoTotalTeorico,
        'monto_pagado': montoPagado,
        'pago_completo': !esParcial,
        'es_parcial': esParcial,
        if (esParcial) 'monto_parcial': montoParcial,
      },
    );
  }

  // ======================================================
  // Meses ya pagados de un socio en un año
  // GET /club/:clubId/pagos/:socioId?anio=X
  // ======================================================
/// Devuelve tanto los meses ya 100% pagados (mesesPagados) como el
  /// detalle completo de cada pago (pagos), para poder detectar
  /// conceptos ya cobrados dentro de un pago PARCIAL del mismo mes.
  static Future<Map<String, dynamic>> getPagosSocio({
    required String token,
    required String clubId,
    required String socioId,
    required int anio,
  }) async {
    final data = await get(
      token: token,
      path: '/club/$clubId/pagos/$socioId?anio=$anio',
    );

    final mesesPagados = ((data['mesesPagados'] as List?) ?? [])
        .map((m) => int.parse(m.toString()))
        .toList();

    final pagos = ((data['pagos'] as List?) ?? [])
        .map((p) => Map<String, dynamic>.from(p))
        .toList();

    return {'mesesPagados': mesesPagados, 'pagos': pagos};
  }

  // ======================================================
  // Listas de configuración del club
  // ======================================================
  static Future<List<String>> getActividades({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/actividades');
    final items = (data['actividades'] as List?) ?? [];
    return items.map((a) => a['nombre'].toString()).toList();
  }

  static Future<List<String>> getCategorias({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/categorias');
    final items = (data['categorias'] as List?) ?? [];
    return items.map((c) => c['nombre'].toString()).toList();
  }

  static Future<List<Map<String, dynamic>>> getTiposIngreso({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/tipos-ingreso');
    final items = (data['tipos'] as List?) ?? [];
    return items.map((t) => Map<String, dynamic>.from(t)).toList();
  }

  static Future<List<Map<String, dynamic>>> getTiposGasto({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/tipos-gasto');
    final items = (data['tipos'] as List?) ?? [];
    return items.map((t) => Map<String, dynamic>.from(t)).toList();
  }

  static Future<List<Map<String, dynamic>>> getResponsables({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/responsables');
    final items = (data['responsables'] as List?) ?? [];
    return items.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ======================================================
  // Actividades / adicionales CON precio (para armar conceptos de pago)
  // ======================================================
  static Future<List<Map<String, dynamic>>> getActividadesConPrecio({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/actividades');
    final items = (data['actividades'] as List?) ?? [];
    return items.map((a) => Map<String, dynamic>.from(a)).toList();
  }

  static Future<List<Map<String, dynamic>>> getActividadesAdicionalesConPrecio({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/actividades-adicionales');
    final items = (data['actividades'] as List?) ?? [];
    return items.map((a) => Map<String, dynamic>.from(a)).toList();
  }

  // ======================================================
  // Nombres de actividades adicionales (filtro de asistencia)
  // ======================================================
  static Future<List<String>> getActividadesAdicionalesNombres({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/config/actividades-adicionales');
    final items = (data['actividades'] as List?) ?? [];
    return items.map((a) => a['nombre'].toString()).toList();
  }

  // ======================================================
  // Cargar nuevo socio
  // ======================================================
  static Future<void> cargarSocio({
    required String token,
    required String clubId,
    required String dni,
    required String nombre,
    required String apellido,
    required String fechaNacimiento,
    required String categoria,
    required String actividad,
    String? telefono,
    String? direccion,
    String? email,
    bool esMenor = false,
    String? tutorNombre,
  }) async {
    final hoy = DateTime.now();
    final fechaIngreso =
        '${hoy.year.toString().padLeft(4, '0')}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';

    await post(
      token: token,
      path: '/club/$clubId/socios',
      body: {
        'dni': dni,
        'nombre': nombre,
        'apellido': apellido,
        'fecha_nacimiento': fechaNacimiento,
        'fecha_ingreso': fechaIngreso,
        'categoria': categoria,
        'actividad': actividad,
        if (telefono != null && telefono.isNotEmpty) 'telefono': telefono,
        if (direccion != null && direccion.isNotEmpty) 'direccion': direccion,
        if (email != null && email.isNotEmpty) 'email': email,
        'es_menor': esMenor,
        if (esMenor && tutorNombre != null) 'tutor_nombre': tutorNombre,
      },
    );
  }

  // ======================================================
  // Subir/actualizar foto de un socio ya creado
  // POST /club/:clubId/socios/:id/foto
  // ======================================================
  static Future<void> subirFotoSocio({
    required String token,
    required String clubId,
    required String socioId,
    required String fotoBase64,
    required String mimetype,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/socios/$socioId/foto',
      body: {
        'base64': fotoBase64,
        'mimetype': mimetype,
      },
    );
  }

  // ======================================================
  // Asistencia
  // ======================================================
  static Future<List<Map<String, dynamic>>> buscarConvocados({
    required String token,
    required String clubId,
    required String actividad,
    required String categoria,
    String? actividadAdicional,
    String? anioNacimiento,
  }) async {
    var path = '/club/$clubId/asistencia/socios-filtrados'
        '?actividad=${Uri.encodeQueryComponent(actividad)}'
        '&categoria=${Uri.encodeQueryComponent(categoria)}';

    if (actividadAdicional != null && actividadAdicional.isNotEmpty) {
      path += '&actividadAdicional=${Uri.encodeQueryComponent(actividadAdicional)}';
    }
    if (anioNacimiento != null && anioNacimiento.isNotEmpty) {
      path += '&anioNacimiento=${Uri.encodeQueryComponent(anioNacimiento)}';
    }

    final data = await get(token: token, path: path);
    final socios = (data['socios'] as List?) ?? [];
    return socios.map((s) => Map<String, dynamic>.from(s)).toList();
  }

  static Future<void> guardarAsistencia({
    required String token,
    required String clubId,
    required String tipo,
    required String actividad,
    required String categoria,
    required String fecha,
    required List<Map<String, dynamic>> convocados,
    List<Map<String, dynamic>> invitados = const [],
    String? actividadAdicional,
    String? anioNacimiento,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/asistencia',
      body: {
        'tipo': tipo,
        'actividad': actividad,
        'categoria': categoria,
        'fecha': fecha,
        'convocados': convocados,
        'invitados': invitados,
        if (actividadAdicional != null && actividadAdicional.isNotEmpty)
          'actividadAdicional': actividadAdicional,
        if (anioNacimiento != null && anioNacimiento.isNotEmpty)
          'anioNacimiento': anioNacimiento,
      },
    );
  }

  // ======================================================
  // Registrar ingreso
  // ======================================================
  static Future<void> registrarIngreso({
    required String token,
    required String clubId,
    required String tipoIngresoId,
    required String fecha,
    required double monto,
    String? observacion,
    String? cuentaId,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/ingresos',
      body: {
        'tipo_ingreso_id': tipoIngresoId,
        'fecha': fecha,
        'monto': monto,
        if (observacion != null && observacion.isNotEmpty) 'observacion': observacion,
        if (cuentaId != null && cuentaId.isNotEmpty) 'cuenta_id': cuentaId,
      },
    );
  }

  // ======================================================
  // Registrar gasto
  // ======================================================
  static Future<void> registrarGasto({
    required String token,
    required String clubId,
    required String periodo,
    required String fechaGasto,
    required String tipoGastoId,
    required String responsableId,
    required double monto,
    String? descripcion,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/gastos',
      body: {
        'periodo': periodo,
        'fecha_gasto': fechaGasto,
        'tipo_gasto_id': tipoGastoId,
        'responsable_id': responsableId,
        'monto': monto,
        if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
      },
    );
  }

// ======================================================
  // Agenda (eventos + cumpleaños)
  // GET /club/:clubId/cumples (sin "mes" -> trae todo el año,
  // así cubrimos cualquier semana sin preocuparnos por el límite de mes)
  // ======================================================
  static Future<Map<String, dynamic>> getAgendaEventos({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/cumples');
    final eventos = (data['eventos'] as List?) ?? [];
    return {
      'eventos': eventos.map((e) => Map<String, dynamic>.from(e)).toList(),
    };
  }

  static Future<void> crearEventoAgenda({
    required String token,
    required String clubId,
    required String fecha, // YYYY-MM-DD
    required String horaDesde, // HH:MM
    required String horaHasta, // HH:MM
    required String titulo,
    String? descripcion,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/agenda/actividades',
      body: {
        'fecha': fecha,
        'hora_desde': horaDesde,
        'hora_hasta': horaHasta,
        'titulo': titulo,
        if (descripcion != null && descripcion.isNotEmpty) 'descripcion': descripcion,
      },
    );
  }

  // ======================================================
  // Pendientes: postulaciones de socios (altas / cambio de foto)
  // ======================================================
  static Future<List<Map<String, dynamic>>> getPendientesSocios({
    required String token,
    required String clubId,
  }) async {
    final data = await get(token: token, path: '/club/$clubId/pendientes');
    final items = (data['items'] as List?) ?? [];
    return items.map((p) => Map<String, dynamic>.from(p)).toList();
  }

  static Future<void> aceptarPendiente({
    required String token,
    required String clubId,
    required String id,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/pendientes/$id/aceptar',
      body: const {},
    );
  }

  static Future<void> rechazarPendiente({
    required String token,
    required String clubId,
    required String id,
    String? motivo,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/pendientes/$id/rechazar',
      body: {
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      },
    );
  }

  // ======================================================
  // Pendientes: transferencias de pago
  // ======================================================
  static Future<List<Map<String, dynamic>>> getTransferenciasPendientes({
    required String token,
    required String clubId,
  }) async {
    final data = await get(
      token: token,
      path: '/club/$clubId/payments/transfer/pending?estado=all',
    );
    final items = (data['items'] as List?) ?? [];
    return items.map((t) => Map<String, dynamic>.from(t)).toList();
  }

  static Future<void> confirmarTransferencia({
    required String token,
    required String clubId,
    required String id,
    required String fechaPago,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/payments/transfer/$id/confirm',
      body: {'fecha_pago': fechaPago},
    );
  }

  static Future<void> rechazarTransferencia({
    required String token,
    required String clubId,
    required String id,
    String? motivo,
  }) async {
    await post(
      token: token,
      path: '/club/$clubId/payments/transfer/$id/reject',
      body: {
        if (motivo != null && motivo.isNotEmpty) 'motivo': motivo,
      },
    );
  }
}