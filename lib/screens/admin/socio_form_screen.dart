import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/admin_api_service.dart';

class SocioFormScreen extends StatefulWidget {
  final String token;
  final String clubId;

  const SocioFormScreen({
    super.key,
    required this.token,
    required this.clubId,
  });

  @override
  State<SocioFormScreen> createState() => _SocioFormScreenState();
}

class _SocioFormScreenState extends State<SocioFormScreen> {
  final _dniController = TextEditingController();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();
  final _emailController = TextEditingController();
  final _tutorController = TextEditingController();

  DateTime? _fechaNacimiento;
  String? _categoria;
  String? _actividad;
  bool _esMenor = false;
  File? _foto;

  List<String> _categorias = [];
  List<String> _actividades = [];

  bool _cargandoListas = true;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargarListas();
  }

  Future<void> _cargarListas() async {
    try {
      final categorias = await AdminApiService.getCategorias(
        token: widget.token,
        clubId: widget.clubId,
      );
      final actividades = await AdminApiService.getActividades(
        token: widget.token,
        clubId: widget.clubId,
      );
      if (!mounted) return;
      setState(() {
        _categorias = categorias;
        _actividades = actividades;
        _cargandoListas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoListas = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando categorías/actividades: $e')),
      );
    }
  }

  Future<void> _elegirFechaNacimiento() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (elegida != null) {
      setState(() => _fechaNacimiento = elegida);
    }
  }

  Future<void> _elegirFoto() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Sacar foto'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (origen == null) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: origen, imageQuality: 80);
    if (file != null) {
      setState(() => _foto = File(file.path));
    }
  }

  Future<void> _guardar() async {
    final dni = _dniController.text.trim();
    final nombre = _nombreController.text.trim();
    final apellido = _apellidoController.text.trim();

    if (dni.isEmpty ||
        nombre.isEmpty ||
        apellido.isEmpty ||
        _fechaNacimiento == null ||
        _categoria == null ||
        _actividad == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completá DNI, Nombre, Apellido, Fecha de nacimiento, Actividad y Categoría'),
        ),
      );
      return;
    }

    if (_esMenor && _tutorController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Si es menor, completá el nombre del tutor')),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final fnac = _fechaNacimiento!;
      final fechaStr =
          '${fnac.year.toString().padLeft(4, '0')}-${fnac.month.toString().padLeft(2, '0')}-${fnac.day.toString().padLeft(2, '0')}';

      final data = await AdminApiService.post(
        token: widget.token,
        path: '/club/${widget.clubId}/socios',
        body: {
          'dni': dni,
          'nombre': nombre,
          'apellido': apellido,
          'fecha_nacimiento': fechaStr,
          'fecha_ingreso': _hoyIso(),
          'categoria': _categoria,
          'actividad': _actividad,
          if (_telefonoController.text.trim().isNotEmpty) 'telefono': _telefonoController.text.trim(),
          if (_direccionController.text.trim().isNotEmpty) 'direccion': _direccionController.text.trim(),
          if (_emailController.text.trim().isNotEmpty) 'email': _emailController.text.trim(),
          'es_menor': _esMenor,
          if (_esMenor) 'tutor_nombre': _tutorController.text.trim(),
        },
      );

      // Si eligió foto, la subimos en un segundo paso con el id ya creado
      if (_foto != null) {
        final socioCreado = data['socio'] as Map<String, dynamic>?;
        final socioId = socioCreado?['id']?.toString();
        if (socioId != null) {
          final bytes = await _foto!.readAsBytes();
          final base64 = base64Encode(bytes);
          final ext = _foto!.path.split('.').last.toLowerCase();
          final mimetype = (ext == 'png') ? 'image/png' : 'image/jpeg';

          await AdminApiService.subirFotoSocio(
            token: widget.token,
            clubId: widget.clubId,
            socioId: socioId,
            fotoBase64: base64,
            mimetype: mimetype,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Socio creado')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _hoyIso() {
    final hoy = DateTime.now();
    return '${hoy.year.toString().padLeft(4, '0')}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _dniController.dispose();
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _emailController.dispose();
    _tutorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoListas) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cargar nuevo socio')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cargar nuevo socio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: GestureDetector(
                onTap: _elegirFoto,
                child: CircleAvatar(
                  radius: 44,
                  backgroundImage: _foto != null ? FileImage(_foto!) : null,
                  child: _foto == null ? const Icon(Icons.camera_alt, size: 32) : null,
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _elegirFoto,
                child: Text(_foto == null ? 'Agregar foto (opcional)' : 'Cambiar foto'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _dniController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'DNI', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nombreController,
              decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apellidoController,
              decoration: const InputDecoration(labelText: 'Apellido', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Fecha de nacimiento'),
              subtitle: Text(
                _fechaNacimiento == null
                    ? 'Sin elegir'
                    : '${_fechaNacimiento!.day.toString().padLeft(2, '0')}/${_fechaNacimiento!.month.toString().padLeft(2, '0')}/${_fechaNacimiento!.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _elegirFechaNacimiento,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _actividad,
              decoration: const InputDecoration(labelText: 'Actividad', border: OutlineInputBorder()),
              items: _actividades
                  .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                  .toList(),
              onChanged: (v) => setState(() => _actividad = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoria,
              decoration: const InputDecoration(labelText: 'Categoría', border: OutlineInputBorder()),
              items: _categorias
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _categoria = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _direccionController,
              decoration: const InputDecoration(labelText: 'Dirección (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('¿Es menor de edad?'),
              value: _esMenor,
              onChanged: (v) => setState(() => _esMenor = v),
            ),
            if (_esMenor) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _tutorController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del padre/madre/tutor',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar socio'),
            ),
          ],
        ),
      ),
    );
  }
}