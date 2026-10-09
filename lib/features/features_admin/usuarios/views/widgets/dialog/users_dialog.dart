import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/usuarios/controllers/usuarios_controller.dart';
import 'package:quimisol_movil/features/features_admin/usuarios/data/almacen_row.dart';
import 'package:quimisol_movil/features/features_admin/usuarios/views/widgets/role_combo.dart';

class UsersDialog {
  static Future<void> open(
    BuildContext context, {
    required UsuariosController controller,
    required String uid,
    required String name,
    required String email,
    required String photoRaw,
    required String role,
    required String almacenId,
  }) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Palette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return _UsersDetailsSheet(
          controller: controller,
          uid: uid,
          name: name,
          email: email,
          photoRaw: photoRaw,
          role: role,
          almacenId: almacenId,
        );
      },
    );
  }
}

class _UsersDetailsSheet extends StatefulWidget {
  const _UsersDetailsSheet({
    required this.controller,
    required this.uid,
    required this.name,
    required this.email,
    required this.photoRaw,
    required this.role,
    required this.almacenId,
  });

  final UsuariosController controller;
  final String uid;
  final String name;
  final String email;
  final String photoRaw;
  final String role;
  final String almacenId;

  @override
  State<_UsersDetailsSheet> createState() => _UsersDetailsSheetState();
}

class _UsersDetailsSheetState extends State<_UsersDetailsSheet> {
  late String _currentRole;
  late String _currentAlmacenId;
  final TextEditingController _nitCtrl = TextEditingController();

  bool _loadingUser = true;
  bool _savingNit = false;

  String _phone = '';
  String _createdAt = '—';
  String _updatedAt = '—';

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    _currentAlmacenId = widget.almacenId;
    _loadUser();
  }

  @override
  void dispose() {
    _nitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.uid)
          .get();

      final data = snap.data() ?? {};

      if (!mounted) return;
      setState(() {
        _phone = (data['phone'] ?? '').toString().trim();
        _createdAt = _fmtTs(data['created_at']);
        _updatedAt = _fmtTs(data['updated_at']);
        _currentRole = (data['role'] ?? widget.role)
            .toString()
            .trim()
            .toLowerCase();
        _currentAlmacenId = (data['almacenId'] ?? widget.almacenId)
            .toString()
            .trim();
        _nitCtrl.text = (data['nit'] ?? '').toString().trim();
        _loadingUser = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingUser = false);
    }
  }

  String _fmtTs(dynamic v) {
    if (v is Timestamp) {
      final d = v.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
    }
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  Future<void> _saveNit() async {
    if (_savingNit) return;

    final nit = _nitCtrl.text.trim();
    if (nit.length < 15 || nit.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('El NIT debe tener entre 15 y 20 números.'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _savingNit = true);

    try {
      await widget.controller.setNit(uid: widget.uid, nit: nit);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('NIT guardado correctamente'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      await _loadUser();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar el NIT: $e')));
    } finally {
      if (mounted) {
        setState(() => _savingNit = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _AvatarResolved(uid: widget.uid, photoRaw: widget.photoRaw),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.email.isEmpty ? '—' : widget.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ink.withValues(alpha: .60),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: ink.withValues(alpha: .70),
                    ),
                    splashRadius: 22,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  RoleComboFancy(
                    controller: widget.controller,
                    uid: widget.uid,
                    currentRole: _currentRole,
                    onChanged: (role) async {
                      setState(() {
                        _currentRole = role;
                        if (role != 'repartidor') {
                          _currentAlmacenId = '';
                        }
                        if (role != 'cliente_mayorista') {
                          _nitCtrl.clear();
                        }
                      });

                      await _loadUser();
                    },
                  ),
                  if (_currentRole == 'repartidor')
                    _AlmacenComboFancy(
                      controller: widget.controller,
                      uid: widget.uid,
                      currentAlmacenId: _currentAlmacenId,
                      onChanged: (almacenId) {
                        setState(() => _currentAlmacenId = almacenId);
                      },
                    ),
                ],
              ),

              if (_currentRole == 'cliente_mayorista') ...[
                const SizedBox(height: 14),
                _NitEditorCard(
                  controller: _nitCtrl,
                  saving: _savingNit,
                  onSave: _saveNit,
                ),
              ],

              const SizedBox(height: 14),

              _DetailTile(
                icon: Icons.phone_rounded,
                label: 'Teléfono',
                value: _phone.isEmpty ? '—' : _phone,
                trailing: _loadingUser
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Palette.primary.withValues(alpha: .75),
                        ),
                      )
                    : null,
              ),

              const SizedBox(height: 10),

              _DetailTile(
                icon: Icons.event_available_rounded,
                label: 'Creado',
                value: _createdAt,
              ),

              const SizedBox(height: 10),

              _DetailTile(
                icon: Icons.update_rounded,
                label: 'Actualizado',
                value: _updatedAt,
              ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _NitEditorCard extends StatelessWidget {
  const _NitEditorCard({
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: .18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_rounded, color: Colors.deepPurple),
              const SizedBox(width: 8),
              Text(
                'NIT mayorista',
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(20),
            ],
            decoration: InputDecoration(
              hintText: 'Ingresa el NIT (solo números)',
              filled: true,
              fillColor: Palette.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ink.withValues(alpha: .10)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: ink.withValues(alpha: .10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Colors.deepPurple,
                  width: 1.4,
                ),
              ),
            ),
            style: TextStyle(color: ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: saving ? null : onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                saving ? 'Guardando...' : 'Guardar NIT',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ink.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: ink.withValues(alpha: .70)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: ink.withValues(alpha: .55),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: ink, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );
  }
}

class _AvatarResolved extends StatefulWidget {
  const _AvatarResolved({required this.uid, required this.photoRaw});
  final String uid;
  final String photoRaw;

  @override
  State<_AvatarResolved> createState() => _AvatarResolvedState();
}

class _AvatarResolvedState extends State<_AvatarResolved> {
  String? _resolved;
  bool _loading = true;

  static final Map<String, String> _cache = {};

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _AvatarResolved oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoRaw != widget.photoRaw || oldWidget.uid != widget.uid) {
      _resolve();
    }
  }

  bool _isHttp(String s) => s.startsWith('http://') || s.startsWith('https://');

  Future<void> _resolve() async {
    final raw = widget.photoRaw.trim();

    final cached = _cache[widget.uid];
    if (cached != null && cached.isNotEmpty) {
      setState(() {
        _resolved = cached;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _resolved = null;
    });

    try {
      if (raw.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      if (_isHttp(raw)) {
        _cache[widget.uid] = raw;
        setState(() {
          _resolved = raw;
          _loading = false;
        });
        return;
      }

      if (raw.startsWith('gs://')) {
        final url = await FirebaseStorage.instance
            .refFromURL(raw)
            .getDownloadURL();
        _cache[widget.uid] = url;
        setState(() {
          _resolved = url;
          _loading = false;
        });
        return;
      }

      final url = await FirebaseStorage.instance.ref(raw).getDownloadURL();
      _cache[widget.uid] = url;
      setState(() {
        _resolved = url;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Palette.button.withValues(alpha: .20),
                Colors.transparent,
              ],
            ),
          ),
        ),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Palette.white,
            border: Border.all(
              color: Palette.button.withValues(alpha: .35),
              width: 1.2,
            ),
          ),
          child: ClipOval(
            child: _loading
                ? Center(
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Palette.primary.withValues(alpha: .75),
                      ),
                    ),
                  )
                : (_resolved != null)
                ? Image.network(
                    _resolved!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) =>
                        _RetryAvatar(onRetry: _resolve),
                  )
                : _RetryAvatar(onRetry: _resolve),
          ),
        ),
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(customBorder: const CircleBorder(), onTap: _resolve),
          ),
        ),
      ],
    );
  }
}

class _RetryAvatar extends StatelessWidget {
  const _RetryAvatar({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Container(
      color: ink.withValues(alpha: .06),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: Palette.primary.withValues(alpha: .75),
        ),
      ),
    );
  }
}

class _AlmacenComboFancy extends StatefulWidget {
  const _AlmacenComboFancy({
    required this.controller,
    required this.uid,
    required this.currentAlmacenId,
    this.onChanged,
  });

  final UsuariosController controller;
  final String uid;
  final String currentAlmacenId;
  final ValueChanged<String>? onChanged;

  @override
  State<_AlmacenComboFancy> createState() => _AlmacenComboFancyState();
}

class _AlmacenComboFancyState extends State<_AlmacenComboFancy> {
  bool _saving = false;
  bool _saved = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _almacenesStream() =>
      widget.controller.almacenesStream();

  Future<void> _setAlmacen(String almacenId) async {
    if (_saving) return;

    setState(() {
      _saving = true;
      _saved = false;
    });

    try {
      await widget.controller.setAlmacen(uid: widget.uid, almacenId: almacenId);

      widget.onChanged?.call(almacenId);

      if (!mounted) return;
      setState(() => _saved = true);

      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) setState(() => _saved = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo asignar almacén: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPicker({
    required List<AlmacenRow> almacenes,
    required String? selectedId,
  }) async {
    final ink = Palette.ink;

    final Map<String, List<AlmacenRow>> grouped = {};
    for (final a in almacenes) {
      final dep = (a.departamento.trim().isEmpty)
          ? 'Sin departamento'
          : a.departamento.trim();
      grouped.putIfAbsent(dep, () => []).add(a);
    }

    final deps = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final k in deps) {
      grouped[k]!.sort(
        (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
      );
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: ink.withValues(alpha: .08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .14),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: Palette.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Palette.primary.withValues(alpha: .14),
                        ),
                      ),
                      child: Icon(
                        Icons.warehouse_rounded,
                        color: Palette.primary.withValues(alpha: .9),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Seleccionar almacén',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: ink.withValues(alpha: .65),
                      ),
                      splashRadius: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: deps.length,
                    itemBuilder: (_, di) {
                      final dep = deps[di];
                      final list = grouped[dep] ?? const [];

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                10,
                                12,
                                10,
                              ),
                              decoration: BoxDecoration(
                                color: Palette.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Palette.primary.withValues(alpha: .10),
                                ),
                              ),
                              child: Text(
                                dep,
                                style: TextStyle(
                                  color: ink.withValues(alpha: .9),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...list.map((a) {
                              final sel = a.id == selectedId;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: sel
                                      ? Palette.button.withValues(alpha: .32)
                                      : Palette.fieldBg,
                                  borderRadius: BorderRadius.circular(16),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => Navigator.pop(context, a.id),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        12,
                                        12,
                                        12,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            sel
                                                ? Icons.check_circle_rounded
                                                : Icons.store_rounded,
                                            color: sel
                                                ? Palette.primary
                                                : ink.withValues(alpha: .55),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              a.nombre,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: ink,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          if (sel)
                                            Icon(
                                              Icons.verified_rounded,
                                              color: Palette.primary.withValues(
                                                alpha: .9,
                                              ),
                                              size: 18,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked != null && picked.isNotEmpty) {
      await _setAlmacen(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _almacenesStream(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];

        final almacenes = docs.map((d) {
          final data = d.data();
          return AlmacenRow(
            id: d.id,
            nombre: (data['nombre'] ?? '—').toString(),
            departamento: (data['departamento'] ?? '').toString(),
          );
        }).toList();

        if (almacenes.isEmpty) {
          return Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Palette.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ink.withValues(alpha: .08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warehouse_rounded,
                  size: 18,
                  color: ink.withValues(alpha: .55),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sin almacenes',
                  style: TextStyle(
                    color: ink.withValues(alpha: .65),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          );
        }

        final selected = almacenes
            .where((a) => a.id == widget.currentAlmacenId)
            .toList();
        final selectedName = selected.isNotEmpty
            ? selected.first.nombre
            : 'Elegir almacén';
        final selectedId = selected.isNotEmpty ? selected.first.id : null;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Palette.primary.withValues(alpha: .18)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _saving
                ? null
                : () =>
                      _openPicker(almacenes: almacenes, selectedId: selectedId),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(scale: anim, child: child),
                  ),
                  child: _saving
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Palette.primary,
                          ),
                        )
                      : _saved
                      ? const Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey('saved'),
                          color: Palette.primary,
                          size: 18,
                        )
                      : const Icon(
                          Icons.warehouse_rounded,
                          key: ValueKey('idle'),
                          color: Palette.primary,
                          size: 18,
                        ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    selectedName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: ink.withValues(alpha: .60),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
