import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_modular/flutter_modular.dart';

import '../../../core/theme/palette.dart';
import '../../../shared/widgets/gradient_background.dart';
import '../../../shared/widgets/rounded_card.dart';
import '../../../shared/buttons/app_button.dart';

import '../../pasajeros_features/ubicaciones/pages/agregado_ubicacion.dart';

class PerfilCompletarPage extends StatefulWidget {
  const PerfilCompletarPage({super.key});

  @override
  State<PerfilCompletarPage> createState() => _PerfilCompletarPageState();
}

class _PerfilCompletarPageState extends State<PerfilCompletarPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isLoading = false;

  Uint8List? _photoBytes;
  String? _initialPhotoUrl;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  CollectionReference<Map<String, dynamic>> get _ubicRef =>
      _db.collection('usuarios').doc(_uid).collection('ubicaciones');

  @override
  void initState() {
    super.initState();

    final args = Modular.args.data as Map?;
    _nameCtrl.text = (args?['name'] as String?) ?? '';
    _initialPhotoUrl = args?['photoUrl'] as String?;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────
  //  FOTO
  // ──────────────────────────────────────────────
  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() => _photoBytes = bytes);
    } catch (_) {}
  }

  // ──────────────────────────────────────────────
  //  GUARDAR PERFIL (requiere ≥1 ubicación)
  // ──────────────────────────────────────────────
  Future<void> _saveProfile(int ubicCount) async {
    if (!_formKey.currentState!.validate()) return;

    if (ubicCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes agregar al menos una ubicación'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      String? photoUrl = _initialPhotoUrl;

      if (_photoBytes != null) {
        final ref = _storage
            .ref()
            .child('users')
            .child(user.uid)
            .child('profile.jpg');

        await ref.putData(_photoBytes!);
        photoUrl = await ref.getDownloadURL();
        await user.updatePhotoURL(photoUrl);
      }

      await _db.collection('usuarios').doc(user.uid).set({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        if (photoUrl != null) 'photo': photoUrl,
        'profile_completed': true,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Modular.to.navigate('/home-pasajero');
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar perfil')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────
  //  UI helpers
  // ──────────────────────────────────────────────
  InputDecoration _pill(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Palette.fieldBg,
        prefixIcon: Icon(icon, color: Palette.primary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    media.size.height -
                    media.padding.top -
                    media.padding.bottom,
              ),
              child: Center(
                child: RoundedCard(
                  child: Form(
                    key: _formKey,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _ubicRef.snapshots(),
                      builder: (context, snap) {
                        final ubicDocs = snap.data?.docs ?? [];
                        final ubicCount = ubicDocs.length;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Completa tu perfil',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Palette.primary,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // FOTO
                            GestureDetector(
                              onTap: _pickPhoto,
                              child: CircleAvatar(
                                radius: 45,
                                backgroundColor: Palette.fieldBg,
                                backgroundImage: _photoBytes != null
                                    ? MemoryImage(_photoBytes!)
                                    : (_initialPhotoUrl != null
                                        ? NetworkImage(_initialPhotoUrl!)
                                        : null) as ImageProvider?,
                                child: (_photoBytes == null &&
                                        _initialPhotoUrl == null)
                                    ? const Icon(Icons.camera_alt,
                                        color: Palette.primary)
                                    : null,
                              ),
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _nameCtrl,
                              decoration:
                                  _pill('Nombre completo', Icons.person),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Ingresa tu nombre'
                                      : null,
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration:
                                  _pill('Número de celular', Icons.phone),
                              validator: (v) =>
                                  v == null || v.trim().length < 7
                                      ? 'Número inválido'
                                      : null,
                            ),

                            const SizedBox(height: 22),

                            // ───────── UBICACIONES ─────────
                            _UbicacionesMiniSection(
                              ubicaciones: ubicDocs,
                              onAdd: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AgregadoUbicacionPage(),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 22),

                            AppButton(
                              label: 'GUARDAR PERFIL',
                              isLoading: _isLoading,
                              onPressed: () => _saveProfile(ubicCount),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- MINI UBICACIONES ---------------- */

class _UbicacionesMiniSection extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> ubicaciones;
  final VoidCallback onAdd;

  const _UbicacionesMiniSection({
    required this.ubicaciones,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Ubicaciones',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: ink,
                  fontSize: 16,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Agregar'),
            ),
          ],
        ),
        if (ubicaciones.isEmpty)
          Text(
            'Debes agregar al menos una ubicación',
            style: TextStyle(
              color: ink.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
            ),
          )
        else
          ...ubicaciones.map((d) {
            final data = d.data();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ink.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['nombre'] ?? 'Ubicación').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (data['direccion'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.65),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
