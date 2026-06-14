import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/dialogs/delete_dialog.dart';

class ResenasPedidosPage extends StatefulWidget {
  const ResenasPedidosPage({super.key});

  @override
  State<ResenasPedidosPage> createState() => _ResenasPedidosPageState();
}

class _ResenasPedidosPageState extends State<ResenasPedidosPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _search = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() =>
      FirebaseFirestore.instance
          .collectionGroup('reviewEntrega')
          .orderBy('createdAt', descending: true)
          .snapshots();

  Future<void> _delete(DocumentReference ref, String pedidoId) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => ConfirmDeleteDialog(
        title: 'Eliminar reseña',
        message: '¿Seguro que quieres eliminar la reseña del pedido "$pedidoId"?',
      ),
    );
    if (ok != true) return;
    try {
      await ref.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reseña eliminada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final isNarrow = c.maxWidth < 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── HEADER ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Palette.primary.withValues(alpha: 0.95),
                      Palette.secondary.withValues(alpha: 0.90),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Palette.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Palette.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Icon(
                            Icons.rate_review_rounded,
                            color: Palette.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reseñas de Pedidos',
                                style: TextStyle(
                                  fontSize: isNarrow ? 16 : 20,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Valoraciones de entrega de los clientes',
                                style: TextStyle(
                                  fontSize: isNarrow ? 11 : 12.5,
                                  color: Palette.white.withValues(alpha: 0.92),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Buscador
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Palette.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
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
                            color: Palette.ink.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Buscar por pedido o comentario…',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Palette.ink.withValues(alpha: 0.35),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: const TextStyle(
                                color: Palette.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchCtrl,
                            builder: (_, v, __) => v.text.isNotEmpty
                                ? InkWell(
                                    onTap: _searchCtrl.clear,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: Palette.ink.withValues(alpha: 0.55),
                                      ),
                                    ),
                                  )
                                : const SizedBox(width: 10),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── LISTA ──────────────────────────────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _stream(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return _ErrorBox(message: 'Error: ${snap.error}');
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snap.data?.docs ?? [];
                    final filtered = _search.isEmpty
                        ? docs
                        : docs.where((d) {
                            final data = d.data();
                            final pedidoId = d.reference.parent.parent?.id ?? '';
                            final codigo = (data['codigo'] ?? '').toString().toLowerCase();
                            final comentario = (data['comentario'] ?? data['comment'] ?? '').toString().toLowerCase();
                            return pedidoId.toLowerCase().contains(_search) ||
                                codigo.contains(_search) ||
                                comentario.contains(_search);
                          }).toList();

                    if (filtered.isEmpty) {
                      return _EmptyBox(
                        title: _search.isEmpty ? 'Sin reseñas aún' : 'Sin resultados',
                        subtitle: _search.isEmpty
                            ? 'Cuando los clientes califiquen sus entregas aparecerán aquí.'
                            : 'Prueba con otro término de búsqueda.',
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: Palette.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Palette.button.withValues(alpha: 0.35)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(14),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Palette.ink.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (_, i) {
                            final doc = filtered[i];
                            final data = doc.data();
                            final pedidoId = doc.reference.parent.parent?.id ?? '—';
                            final codigo = (data['codigo'] ?? '').toString();
                            final displayId = codigo.isNotEmpty ? codigo : pedidoId;
                            final comentario = (data['comentario'] ?? data['comment'] ?? '').toString();
                            final rating = (data['rating'] ?? 0).toDouble();
                            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                            final clienteNombre = (data['clienteNombre'] ?? data['nombre'] ?? '').toString();

                            return _ResenaEntregaCard(
                              pedidoCodigo: displayId,
                              clienteNombre: clienteNombre,
                              comentario: comentario,
                              rating: rating,
                              fecha: createdAt,
                              onDelete: () => _delete(doc.reference, displayId),
                            );
                          },
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
    );
  }
}

class _ResenaEntregaCard extends StatelessWidget {
  const _ResenaEntregaCard({
    required this.pedidoCodigo,
    required this.clienteNombre,
    required this.comentario,
    required this.rating,
    required this.fecha,
    required this.onDelete,
  });

  final String pedidoCodigo;
  final String clienteNombre;
  final String comentario;
  final double rating;
  final DateTime? fecha;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono de entrega
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Palette.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Palette.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pedido #$pedidoCodigo',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Palette.ink,
                              fontSize: 14,
                            ),
                          ),
                          if (clienteNombre.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              clienteNombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Palette.ink.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StarRow(rating: rating),
                  ],
                ),
                if (comentario.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Palette.fieldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Palette.ink.withValues(alpha: 0.07)),
                    ),
                    child: Text(
                      comentario,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Palette.ink.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (fecha != null) ...[
                      Icon(Icons.schedule_rounded,
                          size: 13, color: Palette.ink.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(fecha!),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Palette.ink.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: Colors.red.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    final full = rating.floor().clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return Icon(
          i < full ? Icons.star_rounded : Icons.star_border_rounded,
          size: 16,
          color: const Color(0xFFFFB300),
        );
      }),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.rate_review_outlined,
              size: 64, color: Palette.ink.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: Palette.ink, fontSize: 16)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.ink.withValues(alpha: 0.55), fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.red.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Palette.ink.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
