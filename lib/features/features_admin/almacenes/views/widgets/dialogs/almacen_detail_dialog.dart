import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class AlmacenDetailDialog extends StatefulWidget {
  const AlmacenDetailDialog({
    super.key,
    required this.almacenId,
    required this.nombre,
    required this.departamento,
    this.ubicacion = '',
  });

  final String almacenId;
  final String nombre;
  final String departamento;
  final String ubicacion;

  @override
  State<AlmacenDetailDialog> createState() => _AlmacenDetailDialogState();
}

class _AlmacenDetailDialogState extends State<AlmacenDetailDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      animationDuration: const Duration(milliseconds: 180),
    );
    _tabController.addListener(() {
      if (mounted && _tabIndex != _tabController.index) {
        setState(() => _tabIndex = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 480,
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            children: [
              _DialogHeader(
                nombre: widget.nombre,
                departamento: widget.departamento,
                ubicacion: widget.ubicacion,
                onClose: () => Navigator.pop(context),
              ),
              ColoredBox(
                color: Palette.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Palette.primary,
                  unselectedLabelColor: Palette.ink.withValues(alpha: 0.45),
                  indicatorColor: Palette.primary,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                  ),
                  tabs: const [
                    Tab(icon: Icon(Icons.people_rounded, size: 20), text: 'Repartidores'),
                    Tab(icon: Icon(Icons.inventory_2_rounded, size: 20), text: 'Productos'),
                  ],
                ),
              ),
              // Stack: ambos tabs siempre montados → streams no se reinician
              Expanded(
                child: ColoredBox(
                  color: Palette.card,
                  child: Stack(
                    children: [
                      _TabPane(
                        visible: _tabIndex == 0,
                        child: _EmpleadosTab(almacenId: widget.almacenId),
                      ),
                      _TabPane(
                        visible: _tabIndex == 1,
                        child: _ProductosTab(almacenId: widget.almacenId),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mantiene el widget montado, solo cambia su opacidad.
/// Cero recargas — el stream de Firestore permanece activo.
class _TabPane extends StatelessWidget {
  const _TabPane({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

// ─────────────────────── Header ───────────────────────

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.nombre,
    required this.departamento,
    required this.onClose,
    this.ubicacion = '',
  });

  final String nombre;
  final String departamento;
  final String ubicacion;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 8, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.gradientStart, Palette.secondary],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Palette.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.white.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.warehouse_rounded, color: Palette.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.isEmpty ? 'Almacén' : nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 21,
                    color: Palette.white,
                  ),
                ),
                if (departamento.isNotEmpty)
                  Text(
                    departamento,
                    style: TextStyle(
                      fontSize: 16,
                      color: Palette.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (ubicacion.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 13, color: Palette.white.withValues(alpha: 0.75)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          ubicacion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            color: Palette.white.withValues(alpha: 0.78),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: Palette.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Tab Empleados ───────────────────────

class _EmpleadosTab extends StatelessWidget {
  const _EmpleadosTab({required this.almacenId});
  final String almacenId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .where('almacenId', isEqualTo: almacenId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyTab(
            icon: Icons.people_outline_rounded,
            text: 'Sin repartidores asignados',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final nombre = (d['name'] ?? '').toString();
            final role = (d['role'] ?? '').toString();
            final photo = (d['photo'] ?? '').toString();
            return _EmpleadoTile(
              nombre: nombre.isEmpty ? 'Sin nombre' : nombre,
              role: role,
              photoUrl: photo,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────── Tab Productos ───────────────────────

class _ProductosTab extends StatelessWidget {
  const _ProductosTab({required this.almacenId});
  final String almacenId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('productos')
          .where('almacenId', isEqualTo: almacenId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyTab(
            icon: Icons.inventory_2_outlined,
            text: 'Sin productos en este almacén',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final d = docs[i].data();
            final nombre = (d['nombre'] ?? '').toString();
            final stockRaw = d['stock'];
            final stock = (stockRaw is num) ? stockRaw.toInt() : 0;
            final tipo = (d['tipoItem'] ?? '').toString();
            return _ProductoTile(
              nombre: nombre.isEmpty ? 'Sin nombre' : nombre,
              stock: stock,
              tipo: tipo,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────── Tiles ───────────────────────

class _EmpleadoTile extends StatelessWidget {
  const _EmpleadoTile({
    required this.nombre,
    required this.role,
    required this.photoUrl,
  });

  final String nombre;
  final String role;
  final String photoUrl;

  Color _roleColor() {
    return switch (role.toLowerCase()) {
      'admin' => Palette.statsDanger,
      'repartidor' => Palette.primary,
      'vendedor' => Palette.statsWarning,
      _ => Palette.statsNeutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _roleColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.white,
        border: Border.all(color: Palette.button.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            backgroundColor: Palette.primary.withValues(alpha: 0.12),
            child: photoUrl.isEmpty
                ? Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Palette.primary),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, color: Palette.ink),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              role.isEmpty ? 'usuario' : role,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductoTile extends StatelessWidget {
  const _ProductoTile({
    required this.nombre,
    required this.stock,
    required this.tipo,
  });

  final String nombre;
  final int stock;
  final String tipo;

  @override
  Widget build(BuildContext context) {
    final stockColor = stock <= 0
        ? Palette.statsDanger
        : stock <= 5
            ? Palette.statsWarning
            : Palette.statsSuccess;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.white,
        border: Border.all(color: Palette.button.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Palette.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              size: 20,
              color: Palette.primary.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Palette.ink,
                    fontSize: 18,
                  ),
                ),
                if (tipo.isNotEmpty)
                  Text(
                    tipo,
                    style: TextStyle(
                      fontSize: 15,
                      color: Palette.ink.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: stockColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: stockColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              'Stock: $stock',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: stockColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── Empty state ───────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: Palette.ink.withValues(alpha: 0.15)),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.4),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
