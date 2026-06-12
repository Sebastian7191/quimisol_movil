import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class PerfilFormPage extends StatefulWidget {
  const PerfilFormPage({super.key});

  @override
  State<PerfilFormPage> createState() => _PerfilFormPageState();
}

class _PerfilFormPageState extends State<PerfilFormPage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;

  String _photoUrl = '';
  String _role = 'cliente';
  String _nit = '';

  File? _selectedImageFile;

  String get _uid => _auth.currentUser?.uid ?? '';
  bool get _isMayorista => _role.toLowerCase().trim() == 'cliente_mayorista';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _loadUser() async {
    try {
      if (_uid.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final doc = await _fire.collection('usuarios').doc(_uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      _nameCtrl.text = _s(data['name'] ?? data['nombre'] ?? 'Usuario');
      _phoneCtrl.text = _s(data['telefono'] ?? data['phone']);
      _emailCtrl.text = _s(data['email'] ?? _auth.currentUser?.email ?? '');
      _photoUrl = _s(data['photo']);
      _role = _s(data['role'].toString().isEmpty ? 'cliente' : data['role']);
      _nit = _s(data['nit'] ?? data['NIT']);

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando perfil: $e')),
      );
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) return;

      setState(() {
        _selectedImageFile = File(picked.path);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la imagen: $e')),
      );
    }
  }

  Future<String> _uploadPhotoIfNeeded() async {
    if (_selectedImageFile == null) return _photoUrl;

    setState(() => _uploadingPhoto = true);

    try {
      final fileName = 'perfil_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('usuarios/$_uid/$fileName');

      await ref.putFile(_selectedImageFile!);

      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_uid.isEmpty) return;

    setState(() => _saving = true);

    try {
      final name = _nameCtrl.text.trim();
      final phone = _phoneCtrl.text.trim();
      final finalPhotoUrl = await _uploadPhotoIfNeeded();

      // ✅ El correo NO se actualiza aquí: es de solo lectura en el perfil.
      await _fire.collection('usuarios').doc(_uid).set({
        'name': name,
        'nombre': name,
        'telefono': phone,
        'phone': phone,
        'photo': finalPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _photoUrl = finalPhotoUrl;
      _selectedImageFile = null;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  ImageProvider? _buildPhotoProvider() {
    if (_selectedImageFile != null) {
      return FileImage(_selectedImageFile!);
    }
    if (_photoUrl.trim().isNotEmpty) {
      return NetworkImage(_photoUrl);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        _TopBackButton(
                          onTap: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Información personal',
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Palette.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: ink.withOpacity(0.06)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  GestureDetector(
                                    onTap: (_saving || _uploadingPhoto)
                                        ? null
                                        : _pickPhoto,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          height: 104,
                                          width: 104,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Palette.card,
                                            border: Border.all(
                                              color: Palette.primary.withOpacity(
                                                0.22,
                                              ),
                                              width: 2.2,
                                            ),
                                            image: _buildPhotoProvider() == null
                                                ? null
                                                : DecorationImage(
                                                    image:
                                                        _buildPhotoProvider()!,
                                                    fit: BoxFit.cover,
                                                  ),
                                          ),
                                          child: _buildPhotoProvider() == null
                                              ? Icon(
                                                  Icons.person_rounded,
                                                  color: ink.withOpacity(0.35),
                                                  size: 48,
                                                )
                                              : null,
                                        ),
                                        if (_uploadingPhoto)
                                          Container(
                                            height: 104,
                                            width: 104,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.25,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          right: -2,
                                          bottom: -2,
                                          child: Container(
                                            height: 34,
                                            width: 34,
                                            decoration: BoxDecoration(
                                              color: Palette.primary,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.14),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.camera_alt_rounded,
                                              color: Colors.white,
                                              size: 17,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _nameCtrl.text.trim().isEmpty
                                        ? 'Usuario'
                                        : _nameCtrl.text.trim(),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Palette.button.withOpacity(0.10),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Palette.button.withOpacity(0.22),
                                      ),
                                    ),
                                    child: Text(
                                      _prettyRole(_role),
                                      style: const TextStyle(
                                        color: Palette.primary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Toca la foto para cambiarla',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: ink.withOpacity(0.55),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.8,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: (_saving || _uploadingPhoto)
                                        ? null
                                        : _pickPhoto,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Palette.primary,
                                      side: BorderSide(
                                        color: Palette.primary.withOpacity(0.25),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                    icon: const Icon(Icons.photo_camera_outlined),
                                    label: const Text(
                                      'Cambiar foto',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Palette.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: ink.withOpacity(0.06)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 20,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Datos principales',
                                    style: TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Puedes actualizar tu información personal.',
                                    style: TextStyle(
                                      color: ink.withOpacity(0.55),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const _LabelText(label: 'Nombre completo'),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _nameCtrl,
                                    hint: 'Ej. Juan Pérez',
                                    prefixIcon: Icons.person_outline_rounded,
                                    textInputAction: TextInputAction.next,
                                    validator: (v) {
                                      if ((v ?? '').trim().isEmpty) {
                                        return 'Ingresa tu nombre';
                                      }
                                      return null;
                                    },
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  const SizedBox(height: 16),
                                  const _LabelText(label: 'Teléfono'),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _phoneCtrl,
                                    hint: 'Ej. 71234567',
                                    prefixIcon: Icons.phone_outlined,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 16),
                                  const _LabelText(label: 'Correo'),
                                  const SizedBox(height: 8),
                                  // ✅ El correo se muestra pero no se puede
                                  // editar (lo gestiona la cuenta, no el perfil).
                                  _ReadOnlyField(
                                    value: _emailCtrl.text.isEmpty
                                        ? 'No registrado'
                                        : _emailCtrl.text,
                                    prefixIcon: Icons.mail_outline_rounded,
                                  ),
                                  if (_isMayorista) ...[
                                    const SizedBox(height: 16),
                                    const _LabelText(label: 'NIT'),
                                    const SizedBox(height: 8),
                                    _ReadOnlyField(
                                      value:
                                          _nit.isEmpty ? 'No registrado' : _nit,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_saving || _uploadingPhoto)
                                    ? null
                                    : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Palette.button,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                icon: _saving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _saving ? 'Guardando...' : 'Guardar cambios',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  String _prettyRole(String r) {
    final v = r.toLowerCase().trim();
    if (v == 'admin') return 'Admin';
    if (v == 'repartidor') return 'Repartidor';
    if (v == 'cliente_mayorista') return 'Cliente mayorista';
    return 'Cliente';
  }
}

class _TopBackButton extends StatelessWidget {
  const _TopBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.ink.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Palette.ink.withOpacity(0.72),
          size: 18,
        ),
      ),
    );
  }
}

class _LabelText extends StatelessWidget {
  const _LabelText({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Palette.ink.withOpacity(0.78),
        fontWeight: FontWeight.w800,
        fontSize: 13.5,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.prefixIcon,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final IconData? prefixIcon;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      readOnly: readOnly,
      style: const TextStyle(
        color: Palette.ink,
        fontWeight: FontWeight.w700,
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Palette.ink.withOpacity(0.35),
          fontWeight: FontWeight.w700,
        ),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(
                prefixIcon,
                color: Palette.primary.withOpacity(0.72),
                size: 20,
              ),
        filled: true,
        fillColor: Palette.fieldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Palette.ink.withOpacity(0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Palette.primary,
            width: 1.4,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Palette.ink.withOpacity(0.05),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value, this.prefixIcon});
  final String value;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Palette.ink.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, size: 20, color: Palette.ink.withOpacity(0.45)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Palette.ink.withOpacity(0.7),
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
          Icon(Icons.lock_outline_rounded,
              size: 16, color: Palette.ink.withOpacity(0.3)),
        ],
      ),
    );
  }
}