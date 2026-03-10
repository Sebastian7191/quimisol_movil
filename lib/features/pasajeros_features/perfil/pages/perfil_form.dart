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
      final email = _emailCtrl.text.trim();
      final finalPhotoUrl = await _uploadPhotoIfNeeded();

      await _fire.collection('usuarios').doc(_uid).set({
        'name': name,
        'nombre': name,
        'telefono': phone,
        'phone': phone,
        'email': email,
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
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        height: 98,
                                        width: 98,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Palette.card,
                                          border: Border.all(
                                            color: Palette.button.withOpacity(0.18),
                                            width: 2,
                                          ),
                                          image: _buildPhotoProvider() == null
                                              ? null
                                              : DecorationImage(
                                                  image: _buildPhotoProvider()!,
                                                  fit: BoxFit.cover,
                                                ),
                                        ),
                                        child: _buildPhotoProvider() == null
                                            ? Icon(
                                                Icons.person_rounded,
                                                color: ink.withOpacity(0.35),
                                                size: 46,
                                              )
                                            : null,
                                      ),
                                      if (_uploadingPhoto)
                                        Container(
                                          height: 98,
                                          width: 98,
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.25),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                    ],
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
                                    icon: const Icon(Icons.photo_library_outlined),
                                    label: const Text(
                                      'Seleccionar imagen',
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
                                  const SizedBox(height: 16),
                                  _LabelText(label: 'Nombre completo'),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _nameCtrl,
                                    hint: 'Ingresa tu nombre',
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
                                  _LabelText(label: 'Teléfono'),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _phoneCtrl,
                                    hint: 'Ingresa tu teléfono',
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 16),
                                  _LabelText(label: 'Correo'),
                                  const SizedBox(height: 8),
                                  _InputField(
                                    controller: _emailCtrl,
                                    hint: 'Ingresa tu correo',
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.done,
                                    validator: (v) {
                                      final value = (v ?? '').trim();
                                      if (value.isEmpty) {
                                        return 'Ingresa tu correo';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Correo no válido';
                                      }
                                      return null;
                                    },
                                  ),
                                  if (_isMayorista) ...[
                                    const SizedBox(height: 16),
                                    _LabelText(label: 'NIT'),
                                    const SizedBox(height: 8),
                                    _ReadOnlyField(
                                      value: _nit.isEmpty ? 'No registrado' : _nit,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: (_saving || _uploadingPhoto) ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Palette.button,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
  });

  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      style: const TextStyle(
        color: Palette.ink,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Palette.ink.withOpacity(0.35),
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: Palette.fieldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.value});
  final String value;

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
      child: Text(
        value,
        style: const TextStyle(
          color: Palette.ink,
          fontWeight: FontWeight.w800,
          fontSize: 14.5,
        ),
      ),
    );
  }
}