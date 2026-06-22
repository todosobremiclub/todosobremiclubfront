import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  bool leida;

  AppNotification({
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    this.leida = false,
  });

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'mensaje': mensaje,
        'fecha': fecha.toIso8601String(),
        'leida': leida,
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      titulo: (json['titulo'] ?? '').toString(),
      mensaje: (json['mensaje'] ?? '').toString(),
      fecha: DateTime.tryParse((json['fecha'] ?? '').toString()) ?? DateTime.now(),
      leida: json['leida'] == true,
    );
  }
}

class NotificationStore extends ChangeNotifier {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  static const String _kNotifications = 'app_notifications';

  final List<AppNotification> _items = [];

  List<AppNotification> get all => List.unmodifiable(_items);

  int get noLeidas => _items.where((n) => !n.leida).length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kNotifications);
    if (raw == null || raw.isEmpty) return;

    final decoded = jsonDecode(raw) as List<dynamic>;
    _items
      ..clear()
      ..addAll(
        decoded.map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))),
      );
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_items.map((e) => e.toJson()).toList());
    await prefs.setString(_kNotifications, raw);
  }

  Future<void> agregar(AppNotification n) async {
    _items.insert(0, n);

    // Conservamos un historial local razonable
    if (_items.length > 50) {
      _items.removeRange(50, _items.length);
    }

    await _save();
    notifyListeners();
  }

  Future<void> marcarLeida(AppNotification n) async {
    n.leida = true;
    await _save();
    notifyListeners();
  }

  Future<void> marcarTodasLeidas() async {
    for (final n in _items) {
      n.leida = true;
    }
    await _save();
    notifyListeners();
  }
}
