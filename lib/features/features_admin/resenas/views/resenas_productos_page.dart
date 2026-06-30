import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/dialogs/delete_dialog.dart';

class ResenasProductosPage extends StatefulWidget {
  const ResenasProductosPage({super.key});

  @override
  State<ResenasProductosPage> createState() => _ResenasProductosPageState();
}

class _ResenasProductosPageState extends State<ResenasProductosPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _search = _searchCtrl.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() =>
      FirebaseFirestore.instance
          .collectionGroup('reviews')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots();

  Future<void> _delete(DocumentReference ref, String productName) async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => ConfirmDeleteDialog(
        title: 'Eliminar reseña',
        message: '¿Seguro que quieres eliminar esta reseña de "$productName"?',
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
                            border: Border.all(color: Palette.white.withValues(alpha: 0.35)),
                          ),
                          child: const Icon(Icons.star_rounded, color: Palette.white, size: 28),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reseñas de Productos',
                                style: TextStyle(
                                  fontSize: isNarrow ? 17 : 21,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Comentarios y valoraciones de los clientes',
                                style: TextStyle(
                                  fontSize: isNarrow ? 13 : 14,
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
                          Icon(Icons.search_rounded, color: Palette.ink.withValues(alpha: 0.45)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                hintText: 'Buscar por producto o comentario…',
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: Palette.ink.withValues(alpha: 0.35),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: const TextStyle(color: Palette.ink, fontWeight: FontWeight.w800),
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
                                      child: Icon(Icons.close_rounded,
                                          color: Palette.ink.withValues(alpha: 0.55)),
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
                            final nombre = (data['productName'] ?? data['nombre'] ?? '').toString().toLowerCase();
                            final comentario = (data['comentario'] ?? data['comment'] ?? '').toString().toLowerCase();
                            return nombre.contains(_search) || comentario.contains(_search);
                          }).toList();

                    if (filtered.isEmpty) {
                      return _EmptyBox(
                        title: _search.isEmpty ? 'Sin reseñas aún' : 'Sin resultados',
                        subtitle: _search.isEmpty
                            ? 'Cuando los clientes califiquen productos aparecerán aquí.'
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
                            final productName = (data['productName'] ?? data['nombre'] ?? 'Producto').toString();
                            final comentario = (data['comentario'] ?? data['comment'] ?? '').toString();
                            final rating = (data['rating'] ?? 0).toDouble();
                            final imageUrl = (data['imageUrl'] ?? '').toString();
                            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

                            return _ResenaCard(
                              productName: productName,
                              comentario: comentario,
                              rating: rating,
                              imageUrl: imageUrl,
                              fecha: createdAt,
                              onDelete: () => _delete(doc.reference, productName),
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

class _ResenaCard extends StatelessWidget {
  const _ResenaCard({
    required this.productName,
    required this.comentario,
    required this.rating,
    required this.imageUrl,
    required this.fecha,
    required this.onDelete,
  });

  final String productName;
  final String comentario;
  final double rating;
  final String imageUrl;
  final DateTime? fecha;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen del producto
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _ProductPlaceholder())
                  : const _ProductPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Palette.ink,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StarRow(rating: rating),
                  ],
                ),
                if (comentario.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    comentario,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Palette.ink.withValues(alpha: 0.70),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                          fontSize: 13,
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
                        child: Icon(Icons.delete_outline_rounded,
                            size: 20, color: Colors.red.withValues(alpha: 0.7)),
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

class _ProductPlaceholder extends StatelessWidget {
  const _ProductPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.fieldBg,
      child: Center(
        child: Icon(Icons.inventory_2_outlined,
            size: 22, color: Palette.ink.withValues(alpha: 0.3)),
      ),
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
          Icon(Icons.star_border_rounded,
              size: 64, color: Palette.ink.withValues(alpha: 0.18)),
          const SizedBox(height: 14),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                  fontSize: 17)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.55),
                  fontSize: 14.5)),
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
