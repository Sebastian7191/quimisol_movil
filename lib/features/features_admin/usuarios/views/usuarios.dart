import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../controllers/usuarios_controller.dart';
import '../data/almacen_row.dart';

import 'widgets/role_combo.dart';
import 'widgets/users_states.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});

  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage>
    with TickerProviderStateMixin {
  final controller = UsuariosController();

  late final AnimationController _bgCtrl;

  @override
  void initState() {
    super.initState();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Rebuild UI when search text changes
    controller.searchCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    controller.dispose();
    super.dispose();
  }

  // streams y filtros en controller
  Stream<QuerySnapshot<Map<String, dynamic>>> _usersStream() =>
      controller.usersStream();
  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Scaffold(
      backgroundColor: Palette.fieldBg,

      // ✅ SIN SafeArea: no agrega espacio arriba/izquierda
      body: Column(
        children: [
          _AnimatedHeader(
            bgCtrl: _bgCtrl,
            searchCtrl: controller.searchCtrl,
            roleFilter: controller.roleFilter,
            onRoleFilter: (v) => setState(() => controller.roleFilter = v),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersStream(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snap.error}',
                      style: TextStyle(color: ink),
                    ),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const LoadingFancy();
                }

                final docs = snap.data?.docs ?? [];
                final users = controller.buildUsers(
                  docs,
                  controller.searchCtrl.text.trim(),
                  controller.roleFilter,
                );

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        children: [
                          Text(
                            'Resultados',
                            style: TextStyle(
                              color: ink.withValues(alpha: .55),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (c, a) => FadeTransition(
                              opacity: a,
                              child: ScaleTransition(scale: a, child: c),
                            ),
                            child: Container(
                              key: ValueKey(users.length),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Palette.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: ink.withValues(alpha: .06),
                                ),
                              ),
                              child: Text(
                                '${users.length}',
                                style: TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          const _HintPill(
                            text: 'Edita rol y almacén (repartidor)',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: users.isEmpty
                          ? EmptyState(
                              query: controller.searchCtrl.text.trim(),
                              role: controller.roleFilter,
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount: users.length,
                              itemBuilder: (_, i) {
                                final u = users[i];

                                final delay = math.min(380, i * 22);

                                return _StaggerIn(
                                  delayMs: delay,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _UserCardFancy(
                                      controller: controller,
                                      uid: u.uid,
                                      name: u.name,
                                      email: u.email,
                                      photoRaw: u.photo,
                                      role: u.role,
                                      almacenId: u.almacenId,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- HEADER ANIMADO ---------------- */
class _AnimatedHeader extends StatelessWidget {
  const _AnimatedHeader({
    required this.bgCtrl,
    required this.searchCtrl,
    required this.roleFilter,
    required this.onRoleFilter,
  });

  final AnimationController bgCtrl;
  final TextEditingController searchCtrl;
  final String roleFilter;
  final ValueChanged<String> onRoleFilter;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return AnimatedBuilder(
      animation: bgCtrl,
      builder: (_, __) {
        final t = bgCtrl.value;

        final leftPurple = Color.lerp(
          Palette.primary.withValues(alpha: 0.95),
          Palette.secondary.withValues(alpha: 0.90),
          0.10 + 0.25 * t)!;

        final mid = Color.lerp(
          Palette.primary.withValues(alpha: 0.95),
          Palette.secondary.withValues(alpha: 0.90),
          0.45 + 0.20 * t)!;

        final rightPink = Color.lerp(
          Palette.primary.withValues(alpha: 0.95),
          Palette.secondary.withValues(alpha: 0.90),
          0.80 - 0.20 * t)!;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [leftPurple, mid, rightPink],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(26),
              bottomRight: Radius.circular(26),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                        ),
                      ),
                      child: const Icon(
                        Icons.people_alt_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Usuarios',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Administra roles rápidamente',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _RoleFilterMini(value: roleFilter, onChanged: onRoleFilter),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Palette.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: ink.withValues(alpha: .06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .08),
                        blurRadius: 20,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: ink.withValues(alpha: .45),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre, email o rol…',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: ink.withValues(alpha: .35),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: searchCtrl,
                        builder: (_, v, __) {
                          final has = v.text.trim().isNotEmpty;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            transitionBuilder: (c, a) =>
                                FadeTransition(opacity: a, child: c),
                            child: !has
                                ? const SizedBox(
                                    width: 10,
                                    key: ValueKey('empty'),
                                  )
                                : InkWell(
                                    key: const ValueKey('clear'),
                                    onTap: () => searchCtrl.clear(),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: ink.withValues(alpha: .55),
                                      ),
                                    ),
                                  ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RoleFilterMini extends StatelessWidget {
  const _RoleFilterMini({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: Palette.white,
          borderRadius: BorderRadius.circular(14),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
          onChanged: (v) => onChanged(v ?? 'Todos'),
          selectedItemBuilder: (_) => const [
            Center(child: Text('Todos')),
            Center(child: Text('Admin')),
            Center(child: Text('Cliente')),
            Center(child: Text('Repartidor')),
          ],
          items: [
            DropdownMenuItem(
              value: 'Todos',
              child: Text(
                'Todos',
                style: TextStyle(color: ink, fontWeight: FontWeight.w900),
              ),
            ),
            DropdownMenuItem(
              value: 'admin',
              child: Text(
                'Admin',
                style: TextStyle(color: ink, fontWeight: FontWeight.w900),
              ),
            ),
            DropdownMenuItem(
              value: 'cliente',
              child: Text(
                'Cliente',
                style: TextStyle(color: ink, fontWeight: FontWeight.w900),
              ),
            ),
            DropdownMenuItem(
              value: 'repartidor',
              child: Text(
                'Repartidor',
                style: TextStyle(color: ink, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- LISTA / CARDS ---------------- */

class _UserCardFancy extends StatelessWidget {
  const _UserCardFancy({
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

  // ✅ NUEVO
  final String almacenId;

  Color _roleColor(String r) {
    switch (r) {
      case 'admin':
        return Palette.primary;
      case 'repartidor':
        return Palette.statsSuccess;
      case 'cliente':
      default:
        return Palette.button;
    }
  }

  IconData _roleIcon(String r) {
    switch (r) {
      case 'admin':
        return Icons.verified_rounded;
      case 'repartidor':
        return Icons.local_shipping_rounded;
      case 'cliente':
      default:
        return Icons.person_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final roleColor = _roleColor(role);

    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ink.withValues(alpha: .06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        children: [
          _AvatarResolved(uid: uid, photoRaw: photoRaw),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email.isEmpty ? '—' : email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink.withValues(alpha: .55),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: roleColor.withValues(alpha: .22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_roleIcon(role), size: 14, color: roleColor),
                      const SizedBox(width: 6),
                      Text(
                        role,
                        style: TextStyle(
                          color: Palette.ink.withValues(alpha: .75),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ✅ DERECHA: combo rol + (si repartidor) combo almacén
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RoleComboFancy(controller: controller, uid: uid, currentRole: role),

              if (role == 'repartidor') ...[
                const SizedBox(width: 10),
                _AlmacenComboFancy(
                  controller: controller,
                  uid: uid,
                  currentAlmacenId: almacenId,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------- ALMACEN PICKER (AGRUPADO POR DEPARTAMENTO) ---------------- */

class _AlmacenComboFancy extends StatefulWidget {
  const _AlmacenComboFancy({
    required this.controller,
    required this.uid,
    required this.currentAlmacenId,
  });

  final UsuariosController controller;
  final String uid;
  final String currentAlmacenId;

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

    final uid = widget.uid;

    try {
      await widget.controller.setAlmacen(uid: uid, almacenId: almacenId);

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

    // ✅ Agrupar por departamento
    final Map<String, List<AlmacenRow>> grouped = {};
    for (final a in almacenes) {
      final dep = (a.departamento.trim().isEmpty)
          ? 'Sin departamento'
          : a.departamento.trim();
      grouped.putIfAbsent(dep, () => []).add(a);
    }

    final deps = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    // ✅ Orden interno por nombre
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
                // header
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

                // lista
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
                            // título departamento
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

                            // items del departamento
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

        // ✅ id, nombre, departamento
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

        // ✅ nombre seleccionado
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
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('saved'),
                          color: Palette.primary,
                          size: 18,
                        )
                      : Icon(
                          Icons.warehouse_rounded,
                          key: const ValueKey('idle'),
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

/* ---------------- AVATAR RESOLVER ---------------- */

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

/* ---------------- STAGGER ANIMATION ---------------- */

class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_c);

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: .06)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: ink.withValues(alpha: .55),
          fontWeight: FontWeight.w800,
          fontSize: 11.5,
        ),
      ),
    );
  }
}