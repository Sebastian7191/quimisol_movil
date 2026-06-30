import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'es_BO');

final Map<String, String> _clienteNombreCache = {};

Future<String> _resolveClienteNombre(String uid) async {
  if (uid.isEmpty) return '';
  final cached = _clienteNombreCache[uid];
  if (cached != null) return cached;
  try {
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(uid).get();
    final nombre = (doc.data()?['nombre'] ?? '').toString();
    _clienteNombreCache[uid] = nombre;
    return nombre;
  } catch (_) {
    return '';
  }
}

final Map<String, Map<String, dynamic>> _pedidoInfoCache = {};

Future<Map<String, dynamic>> _resolvePedidoInfo(String pedidoId) async {
  if (pedidoId.isEmpty) return {};
  final cached = _pedidoInfoCache[pedidoId];
  if (cached != null) return cached;
  try {
    final doc = await FirebaseFirestore.instance.collection('pedidos').doc(pedidoId).get();
    final data = doc.data() ?? {};
    _pedidoInfoCache[pedidoId] = data;
    return data;
  } catch (_) {
    return {};
  }
}

class ResenasDashboardSection extends StatelessWidget {
  final double width;
  const ResenasDashboardSection({super.key, required this.width});

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get _productosStream =>
      FirebaseFirestore.instance
          .collectionGroup('reviews')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots()
          .map((s) => s.docs);

  // Reviews de productos guardadas dentro de cada pedido:
  // /pedidos/{pedidoId}/reviewsProductos/{productId}
  // Se ordena en cliente para no depender de un índice de collectionGroup.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> get _pedidosStream =>
      FirebaseFirestore.instance
          .collectionGroup('reviewsProductos')
          .snapshots()
          .map((s) {
            final docs = s.docs.toList();
            docs.sort((a, b) {
              final rawA = a.data()['createdAt'];
              final rawB = b.data()['createdAt'];
              DateTime dA = DateTime.fromMillisecondsSinceEpoch(0);
              DateTime dB = DateTime.fromMillisecondsSinceEpoch(0);
              if (rawA is Timestamp) dA = rawA.toDate();
              if (rawB is Timestamp) dB = rawB.toDate();
              return dB.compareTo(dA);
            });
            return docs.take(6).toList();
          });

  @override
  Widget build(BuildContext context) {
    final stacked = width < 980;

    final productosSection = _ResenasListSection(
      title: 'Reseñas de Productos',
      subtitle: 'Últimas 6',
      stream: _productosStream,
      itemBuilder: (doc) {
        final d = doc.data();
        final nombre = (d['productName'] ?? d['nombre'] ?? 'Producto').toString();
        final comentario = (d['comentario'] ?? d['comment'] ?? '').toString();
        final rating = (d['rating'] ?? 0).toDouble();
        final clienteUid = (d['clienteUid'] ?? '').toString();
        DateTime? fecha;
        final raw = d['createdAt'];
        if (raw is Timestamp) fecha = raw.toDate();
        return _ResenaItem(
          icon: Icons.inventory_2_outlined,
          title: nombre,
          clienteUid: clienteUid,
          comentario: comentario,
          rating: rating,
          fecha: fecha,
          extras: const {},
        );
      },
      emptyText: 'Aún no hay reseñas de productos.',
    );

    final pedidosSection = _ResenasListSection(
      title: 'Reseñas de Pedidos',
      subtitle: 'Últimas 6',
      stream: _pedidosStream,
      itemBuilder: (doc) {
        final d = doc.data();
        final productName = (d['productName'] ?? 'Producto').toString();
        final comentario = (d['comentario'] ?? '').toString();
        final rating = (d['rating'] ?? 0).toDouble();
        final clienteUid = (d['clienteUid'] ?? '').toString();
        final pedidoId = (d['pedidoId'] ?? '').toString();
        DateTime? fecha;
        final raw = d['createdAt'];
        if (raw is Timestamp) fecha = raw.toDate();

        return FutureBuilder<Map<String, dynamic>>(
          future: _resolvePedidoInfo(pedidoId),
          builder: (context, snap) {
            final pedido = snap.data ?? {};
            final codigo = (pedido['codigo'] ?? '').toString();
            final displayId = codigo.isNotEmpty
                ? codigo
                : (pedidoId.isEmpty
                    ? 'Pedido'
                    : pedidoId.substring(0, pedidoId.length < 8 ? pedidoId.length : 8));
            final direccion = (pedido['direccion'] ?? '').toString();
            final repartidor = (pedido['repartidorNombre'] ?? '').toString();
            final total = (pedido['total'] ?? 0).toDouble();

            return _ResenaItem(
              icon: Icons.local_shipping_rounded,
              title: '#$displayId · $productName',
              clienteUid: clienteUid,
              comentario: comentario,
              rating: rating,
              fecha: fecha,
              extras: {
                'Producto': productName,
                if (direccion.isNotEmpty) 'Dirección': direccion,
                if (repartidor.isNotEmpty) 'Repartidor': repartidor,
                if (total > 0) 'Total': 'Bs ${total.toStringAsFixed(2)}',
              },
            );
          },
        );
      },
      emptyText: 'Aún no hay reseñas de pedidos.',
    );

    if (stacked) {
      return Column(
        children: [
          productosSection,
          const SizedBox(height: 12),
          pedidosSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: productosSection),
        const SizedBox(width: 12),
        Expanded(child: pedidosSection),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Sección contenedora
// ─────────────────────────────────────────────
class _ResenasListSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> stream;
  final Widget Function(QueryDocumentSnapshot<Map<String, dynamic>>) itemBuilder;
  final String emptyText;

  const _ResenasListSection({
    required this.title,
    required this.subtitle,
    required this.stream,
    required this.itemBuilder,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 15.5, fontWeight: FontWeight.w900, color: Palette.ink)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Palette.ink.withValues(alpha: 0.72))),
          const SizedBox(height: 12),
          StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final docs = snap.data ?? [];
              if (docs.isEmpty) return _empty(emptyText);
              return Column(
                children: docs
                    .map((doc) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: itemBuilder(doc),
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: Text(text,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Palette.ink.withValues(alpha: 0.78))),
    );
  }
}

// ─────────────────────────────────────────────
//  Item expandible
// ─────────────────────────────────────────────
class _ResenaItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String clienteUid;
  final String comentario;
  final double rating;
  final DateTime? fecha;
  final Map<String, String> extras;

  const _ResenaItem({
    required this.icon,
    required this.title,
    required this.clienteUid,
    required this.comentario,
    required this.rating,
    required this.fecha,
    required this.extras,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolveClienteNombre(clienteUid),
      builder: (context, snap) {
        final clienteNombre = snap.data ?? '';
        return _ResenaItemBody(
          icon: icon,
          title: title,
          clienteNombre: clienteNombre,
          comentario: comentario,
          rating: rating,
          fecha: fecha,
          extras: extras,
        );
      },
    );
  }
}

class _ResenaItemBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String clienteNombre;
  final String comentario;
  final double rating;
  final DateTime? fecha;
  final Map<String, String> extras;

  const _ResenaItemBody({
    required this.icon,
    required this.title,
    required this.clienteNombre,
    required this.comentario,
    required this.rating,
    required this.fecha,
    required this.extras,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            childrenPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: Palette.primary.withValues(alpha: 0.9), size: 22),
            ),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w900, color: Palette.ink),
            ),
            subtitle: (clienteNombre.isNotEmpty || comentario.isNotEmpty)
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (clienteNombre.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded,
                                size: 13, color: Palette.primary.withValues(alpha: 0.75)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                clienteNombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Palette.primary.withValues(alpha: 0.85)),
                              ),
                            ),
                          ],
                        ),
                      if (comentario.isNotEmpty)
                        Text(
                          comentario,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Palette.ink.withValues(alpha: 0.65)),
                        ),
                    ],
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StarPill(rating: rating),
                const SizedBox(width: 6),
                Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: Palette.ink.withValues(alpha: 0.45)),
              ],
            ),
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Palette.primary.withValues(alpha: 0.10)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Stars(rating: rating, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: Color(0xFFFFB300)),
                        ),
                      ],
                    ),
                    if (clienteNombre.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Row(icon: Icons.person_outline_rounded, label: 'Cliente', value: clienteNombre),
                    ],
                    if (comentario.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _Row(icon: Icons.comment_outlined, label: 'Comentario', value: comentario),
                    ],
                    ...extras.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: _Row(icon: _iconForKey(e.key), label: e.key, value: e.value),
                        )),
                    if (fecha != null) ...[
                      const SizedBox(height: 6),
                      _Row(
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
        ),
      ),
    );
  }

  IconData _iconForKey(String key) {
    if (key == 'Dirección') return Icons.location_on_outlined;
    if (key == 'Repartidor') return Icons.delivery_dining_rounded;
    if (key == 'Total') return Icons.payments_outlined;
    if (key == 'Producto') return Icons.inventory_2_outlined;
    return Icons.info_outline_rounded;
  }
}

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────
class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row({required this.icon, required this.label, required this.value});

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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink.withValues(alpha: 0.55))),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _StarPill extends StatelessWidget {
  final double rating;
  const _StarPill({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB300).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB300)),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFFFB300)),
          ),
        ],
      ),
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
