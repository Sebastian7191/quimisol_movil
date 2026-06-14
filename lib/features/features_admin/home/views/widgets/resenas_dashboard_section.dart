import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/dialogs/delete_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'es_BO');

class ResenasDashboardSection extends StatelessWidget {
  final double width;
  const ResenasDashboardSection({super.key, required this.width});

  @override
  Widget build(BuildContext context) {
    final stacked = width < 980;

    final productosCard = _ResenaStatCard(
      title: 'Reseñas de Productos',
      subtitle: 'Comentarios de clientes',
      icon: Icons.star_rounded,
      accent: const Color(0xFFFFB300),
      countStream: FirebaseFirestore.instance
          .collectionGroup('reviews')
          .snapshots(),
      onTap: () => _showProductosDialog(context),
    );

    final pedidosCard = _ResenaStatCard(
      title: 'Reseñas de Pedidos',
      subtitle: 'Valoraciones de entrega',
      icon: Icons.rate_review_rounded,
      accent: Palette.primary,
      countStream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('reviewEntrega', isNotEqualTo: null)
          .snapshots(),
      onTap: () => _showPedidosDialog(context),
    );

    if (stacked) {
      return Column(children: [
        productosCard,
        const SizedBox(height: 12),
        pedidosCard,
      ]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: productosCard),
        const SizedBox(width: 12),
        Expanded(child: pedidosCard),
      ],
    );
  }

  void _showProductosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ResenaListDialog(
        title: 'Reseñas de Productos',
        accent: const Color(0xFFFFB300),
        icon: Icons.star_rounded,
        stream: FirebaseFirestore.instance
            .collectionGroup('reviews')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        itemBuilder: (ctx, doc) {
          final d = doc.data();
          final nombre = (d['productName'] ?? d['nombre'] ?? 'Producto').toString();
          final comentario = (d['comentario'] ?? d['comment'] ?? '').toString();
          final rating = (d['rating'] ?? 0).toDouble();
          final reviewer = '';
          final email = '';
          final uid = (d['clienteUid'] ?? '').toString();
          DateTime? fecha;
          final raw = d['createdAt'];
          if (raw is Timestamp) fecha = raw.toDate();

          return _ResenaListItem(
            icon: Icons.inventory_2_outlined,
            title: nombre,
            comentario: comentario,
            rating: rating,
            reviewer: reviewer,
            email: email,
            uid: uid,
            fecha: fecha,
            extra: const {},
            onDelete: () async {
              final ok = await showDialog<bool>(
                context: ctx,
                useRootNavigator: true,
                barrierDismissible: false,
                builder: (_) => ConfirmDeleteDialog(
                  title: 'Eliminar reseña',
                  message: '¿Seguro que quieres eliminar esta reseña de "$nombre"?',
                ),
              );
              if (ok != true || !ctx.mounted) return;
              await doc.reference.delete();
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reseña eliminada')),
                );
              }
            },
          );
        },
      ),
    );
  }

  void _showPedidosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ResenaListDialog(
        title: 'Reseñas de Pedidos',
        accent: Palette.primary,
        icon: Icons.rate_review_rounded,
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .where('reviewEntrega', isNotEqualTo: null)
            .limit(50)
            .snapshots(),
        itemBuilder: (ctx, doc) {
          final d = doc.data();
          final review = (d['reviewEntrega'] as Map<String, dynamic>?) ?? {};
          final codigo = (d['codigo'] ?? '').toString();
          final displayId = codigo.isNotEmpty ? '#$codigo' : doc.id.substring(0, 8);
          final comentario = (review['comentario'] ?? '').toString();
          final rating = (review['rating'] ?? 0).toDouble();
          final reviewer = '';
          final email = '';
          // El UID del cliente está en el documento del pedido bajo 'uid'
          // o como fallback en reviewEntrega.clienteUid
          final uid = (d['uid'] ?? review['clienteUid'] ?? '').toString();
          DateTime? fecha;
          final raw = review['createdAt'] ?? d['createdAt'];
          if (raw is Timestamp) fecha = raw.toDate();
          final direccion = (d['direccion'] ?? '').toString();
          final repartidor = (d['repartidorNombre'] ?? '').toString();
          final total = (d['total'] ?? 0).toDouble();

          return _ResenaListItem(
            icon: Icons.local_shipping_rounded,
            title: 'Pedido $displayId',
            comentario: comentario,
            rating: rating,
            reviewer: reviewer,
            email: email,
            uid: uid,
            fecha: fecha,
            extra: {
              if (direccion.isNotEmpty) 'Dirección': direccion,
              if (repartidor.isNotEmpty) 'Repartidor': repartidor,
              if (total > 0) 'Total': 'Bs ${total.toStringAsFixed(2)}',
            },
            onDelete: () async {
              final ok = await showDialog<bool>(
                context: ctx,
                useRootNavigator: true,
                barrierDismissible: false,
                builder: (_) => ConfirmDeleteDialog(
                  title: 'Eliminar reseña',
                  message: '¿Seguro que quieres eliminar la reseña del pedido "$displayId"?',
                ),
              );
              if (ok != true || !ctx.mounted) return;
              await doc.reference.update({'reviewEntrega': FieldValue.delete()});
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Reseña eliminada')),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TARJETA STAT (colapsada, solo muestra conteo)
// ─────────────────────────────────────────────
class _ResenaStatCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Stream<QuerySnapshot<Map<String, dynamic>>> countStream;
  final VoidCallback onTap;

  const _ResenaStatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.countStream,
    required this.onTap,
  });

  @override
  State<_ResenaStatCard> createState() => _ResenaStatCardState();
}

class _ResenaStatCardState extends State<_ResenaStatCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.countStream,
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _hovered ? widget.accent.withValues(alpha: 0.06) : Palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _hovered
                      ? widget.accent.withValues(alpha: 0.5)
                      : Palette.primary.withValues(alpha: 0.18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _hovered
                        ? widget.accent.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: _hovered ? 18 : 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: widget.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: widget.accent.withValues(alpha: 0.28)),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Palette.ink,
                            )),
                        const SizedBox(height: 4),
                        Text(widget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              color: Palette.ink.withValues(alpha: 0.75),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      snap.connectionState == ConnectionState.waiting
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: widget.accent,
                              ),
                            )
                          : Text(count.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: Palette.ink,
                              )),
                      Text(
                        'Ver detalle',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: widget.accent.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  DIALOG CON LISTA DE RESEÑAS
// ─────────────────────────────────────────────
class _ResenaListDialog extends StatelessWidget {
  final String title;
  final Color accent;
  final IconData icon;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Widget Function(BuildContext, QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder;

  const _ResenaListDialog({
    required this.title,
    required this.accent,
    required this.icon,
    required this.stream,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final dialogWidth = (w * 0.72).clamp(360.0, 780.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent, accent.withValues(alpha: 0.7)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        )),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Lista
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: stream,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text('Sin reseñas aún',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w600)),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (c, i) => itemBuilder(c, docs[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ÍTEM EXPANDIBLE CON DETALLE
// ─────────────────────────────────────────────
class _ResenaListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String comentario;
  final double rating;
  final String reviewer;
  final String email;
  final String uid;
  final DateTime? fecha;
  final Map<String, String> extra;
  final VoidCallback onDelete;

  const _ResenaListItem({
    required this.icon,
    required this.title,
    required this.comentario,
    required this.rating,
    required this.reviewer,
    this.email = '',
    this.uid = '',
    required this.fecha,
    required this.extra,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Quita el divisor superior/inferior del ExpansionTile
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Palette.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: Palette.primary),
        ),
        title: Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        subtitle: Row(
          children: [
            _Stars(rating: rating),
            if (comentario.isNotEmpty) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  comentario,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: Palette.ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onDelete,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.delete_outline_rounded,
                    size: 17, color: Colors.red.withValues(alpha: 0.65)),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.expand_more_rounded, size: 20),
          ],
        ),
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Estrellas grandes
                Row(
                  children: [
                    _Stars(rating: rating, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                  ],
                ),
                if (comentario.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DetailRow(
                    icon: Icons.comment_outlined,
                    label: 'Comentario',
                    value: comentario,
                  ),
                ],
                const SizedBox(height: 6),
                _UserRow(
                  reviewer: reviewer,
                  email: email,
                  uid: uid,
                ),
                ...extra.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _DetailRow(
                        icon: _iconForKey(e.key),
                        label: e.key,
                        value: e.value,
                      ),
                    )),
                if (fecha != null) ...[
                  const SizedBox(height: 6),
                  _DetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha',
                    value: _dateFmt.format(fecha!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForKey(String key) {
    if (key == 'Dirección') return Icons.location_on_outlined;
    if (key == 'Repartidor') return Icons.delivery_dining_rounded;
    if (key == 'Total') return Icons.payments_outlined;
    return Icons.info_outline_rounded;
  }
}

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────

/// Muestra el nombre/email del usuario que publicó la reseña.
/// Si `reviewer` está vacío pero hay `uid`, busca en Firestore.
class _UserRow extends StatelessWidget {
  final String reviewer;
  final String email;
  final String uid;
  const _UserRow({required this.reviewer, required this.email, required this.uid});

  @override
  Widget build(BuildContext context) {
    // Si ya tenemos el nombre directo, mostrarlo
    if (reviewer.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(icon: Icons.person_outline_rounded, label: 'Usuario', value: reviewer),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 6),
            _DetailRow(icon: Icons.email_outlined, label: 'Email', value: email),
          ],
        ],
      );
    }

    // Sin nombre pero con uid: buscamos en Firestore
    if (uid.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('usuarios').doc(uid).get(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Usuario',
              value: 'Cargando...',
            );
          }
          final data = snap.data?.data();
          final nombre = (data?['nombre'] ?? data?['name'] ?? data?['displayName'] ?? '').toString();
          final correo = (data?['email'] ?? email).toString();
          if (nombre.isEmpty && correo.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (nombre.isNotEmpty)
              _DetailRow(
                icon: Icons.person_outline_rounded,
                label: 'Usuario',
                value: nombre,
              ),
              if (correo.isNotEmpty) ...[
                const SizedBox(height: 6),
                _DetailRow(icon: Icons.email_outlined, label: 'Email', value: correo),
              ],
            ],
          );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Palette.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        SizedBox(
          width: 80,
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Palette.ink.withValues(alpha: 0.55),
              )),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  final double rating;
  final double size;
  const _Stars({required this.rating, this.size = 13});

  @override
  Widget build(BuildContext context) {
    final full = rating.floor().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < full ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: const Color(0xFFFFB300),
        ),
      ),
    );
  }
}
