// wishlist_page.dart

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/widgets/depto_conflicto_dialog.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/detalle_producto.dart';
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/home_page_clientes.dart';
import 'package:quimisol_movil/shared/widgets/cart_count_badge.dart';

import 'wishlist_store.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  int _filter = 0; // 0 Todo, 1 Disponibles, 2 Recientes, 3 Precio

  final WishlistStore _store = WishlistStore.I;
  final CartStore _cart = CartStore.I;

  @override
  void initState() {
    super.initState();

    // Por si entras directo a wishlist
    _store.bind();
    _cart.bind();

    _store.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  List<WishItem> get _items => _store.items;

  List<WishItem> get _filtered {
    final list = List<WishItem>.from(_items);

    if (_filter == 1) return list.where((e) => e.stock > 0).toList();
    if (_filter == 2) return list.take(20).toList(); // recientes
    if (_filter == 3) {
      list.sort((a, b) => a.price.compareTo(b.price));
      return list;
    }

    return list;
  }

  void _removeAt(int index) {
    final item = _filtered[index];
    _store.remove(item.id);
  }

  // ✅ agrega al carrito respetando el descuento, sin sacarlo de favoritos
  Future<void> _addToCart(WishItem item, double priceToUse) async {
    final fixed = WishItem(
      id: item.id,
      name: item.name,
      price: priceToUse, // ✅ precio final (con descuento)
      rating: item.rating,
      stock: item.stock,
      imageUrl: item.imageUrl,
    );

    final res = await _cart.addFromWishlist(fixed);

    // Mismo criterio que en el detalle: un pedido sale de un solo
    // departamento, asi que preguntamos antes de vaciar el carrito.
    if (!res.agregado) {
      if (!mounted) return;

      final aceptado = await confirmarCambioDeDepartamento(
        context,
        res.conflicto!,
      );
      if (!aceptado) return;

      await _cart.addFromWishlist(fixed, vaciarCarrito: true);
    }

    if (!mounted) return;

    // El producto sigue en favoritos, así que sin este aviso no se nota
    // que pasó algo al tocar el botón.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Agregado al carrito 🛒')));
    // ❌ no navegación automática
  }

  /// Abre el detalle con los datos actuales del producto (stock, precio),
  /// no con la copia guardada en favoritos.
  Future<void> _openDetalle(WishItem item) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('productos')
          .doc(item.id)
          .get();

      if (!mounted) return;

      if (!snap.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este producto ya no está disponible')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetalleProductoPage(product: ProductModel.fromFirestore(snap)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el producto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button;
    final ink = Palette.ink;

    final bg = Palette.fieldBg;
    final cardBg = Palette.white;
    final chipBg = ink.withOpacity(0.06);

    final total = _items.length;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const SizedBox(width: 38), // 👈 sin flecha
                  const Spacer(),
                  Text(
                    'Lista de Favoritos',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                    ),
                  ),
                  const Spacer(),
                  CartCountBadge(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CarritoPage(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: Palette.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: ink.withOpacity(0.06)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.shopping_cart_outlined,
                          color: ink.withOpacity(0.75),
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Subtítulo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Text(
                    '$total artículos guardados',
                    style: TextStyle(
                      color: ink.withOpacity(0.55),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            // Chips filtro
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChipX(
                    text: 'Todo',
                    active: _filter == 0,
                    primary: primary,
                    chipBg: chipBg,
                    onTap: () => setState(() => _filter = 0),
                    ink: ink,
                  ),
                  const SizedBox(width: 10),
                  _FilterChipX(
                    text: 'Recientes',
                    active: _filter == 2,
                    primary: primary,
                    chipBg: chipBg,
                    onTap: () => setState(() => _filter = 2),
                    ink: ink,
                  ),
                  const SizedBox(width: 10),
                  _FilterChipX(
                    text: 'Precio',
                    active: _filter == 3,
                    primary: primary,
                    chipBg: chipBg,
                    onTap: () => setState(() => _filter = 3),
                    ink: ink,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Lista
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No tienes productos en tu lista de favoritos.',
                        style: TextStyle(
                          color: ink.withOpacity(0.55),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  // Filas de 2 como en la home: cada fila mide lo que su
                  // card más alta, y las dos quedan del mismo alto.
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                      itemCount: (_filtered.length + 1) ~/ 2,
                      itemBuilder: (_, row) {
                        Widget card(int i) {
                          final it = _filtered[i];
                          return _WishCard(
                            item: it,
                            primary: primary,
                            cardBg: cardBg,
                            ink: ink,
                            onRemove: () => _removeAt(i),
                            onTap: () => _openDetalle(it),
                            onAddToCart: it.stock <= 0
                                ? null
                                : (priceToUse) => _addToCart(it, priceToUse),
                          );
                        }

                        final i = row * 2;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: card(i)),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: i + 1 < _filtered.length
                                      ? card(i + 1)
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
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

/* ---------------- UI ---------------- */

/// Foto completa a todo el ancho de la card: el alto sigue la proporción de
/// cada imagen (una botella alta da una imagen alta), así no se recorta ni
/// quedan franjas. Mientras carga, o si falla, ocupa un cuadrado.
class _ImagenCompleta extends StatelessWidget {
  const _ImagenCompleta({required this.url, required this.ink});

  final String url;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    Widget cuadro({bool error = false}) => AspectRatio(
      aspectRatio: 1,
      child: Container(
        color: ink.withValues(alpha: 0.06),
        alignment: Alignment.center,
        child: error
            ? Icon(Icons.image_outlined, color: ink.withValues(alpha: 0.35))
            : null,
      ),
    );

    if (url.trim().isEmpty) return cuadro(error: true);

    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.fitWidth,
      frameBuilder: (_, child, frame, wasSyncLoaded) =>
          (frame == null && !wasSyncLoaded) ? cuadro() : child,
      errorBuilder: (_, __, ___) => cuadro(error: true),
    );
  }
}

class _FilterChipX extends StatelessWidget {
  const _FilterChipX({
    required this.text,
    required this.active,
    required this.primary,
    required this.chipBg,
    required this.onTap,
    required this.ink,
  });

  final String text;
  final bool active;
  final Color primary;
  final Color chipBg;
  final VoidCallback onTap;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? primary : chipBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? primary : ink.withOpacity(0.06)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : ink.withOpacity(0.70),
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.item,
    required this.primary,
    required this.cardBg,
    required this.ink,
    required this.onRemove,
    required this.onTap,
    required this.onAddToCart,
  });

  final WishItem item;
  final Color primary;
  final Color cardBg;
  final Color ink;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  final Future<void> Function(double priceToUse)? onAddToCart;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _descuentoStream(String id) {
    return FirebaseFirestore.instance
        .collection('productos')
        .doc(id)
        .collection('descuentos')
        .doc('activo')
        .snapshots();
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final soldOut = item.stock <= 0;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _descuentoStream(item.id),
      builder: (context, snap) {
        final Map<String, dynamic>? d = snap.data?.data();

        final bool activo = (d?['activo'] == true);
        final String tipo = (d?['tipo'] ?? 'PORCENTAJE').toString().trim();
        final double valor = _toDouble(d?['valor']);

        final bool hasDescuento = activo && valor > 0;

        final double base = item.price;
        double finalPrice = base;
        String badge = '';

        if (hasDescuento) {
          if (tipo == 'PORCENTAJE') {
            final double pct = valor.clamp(0.0, 100.0);
            finalPrice = base * (1 - (pct / 100.0));
            finalPrice = math.max(0.0, finalPrice);

            final String pctTxt = (pct % 1 == 0)
                ? pct.toStringAsFixed(0)
                : pct.toStringAsFixed(1);

            badge = '-$pctTxt%';
          } else {
            finalPrice = math.max(0.0, base - valor);

            final String vTxt = (valor % 1 == 0)
                ? valor.toStringAsFixed(0)
                : valor.toStringAsFixed(2);

            badge = '-Bs $vTxt';
          }
        }

        final double priceToShow = hasDescuento ? finalPrice : base;

        return Material(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          // Recorta la imagen con las esquinas superiores de la card.
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ink.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen de borde a borde en la parte superior.
                  Stack(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _ImagenCompleta(url: item.imageUrl, ink: ink),
                      ),

                      if (hasDescuento)
                        Positioned(
                          left: 6,
                          top: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.14),
                                  blurRadius: 12,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                      Positioned(
                        top: 6,
                        right: 6,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onRemove,
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.45),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Wrap(
                            spacing: 8,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              Text(
                                'Bs. ${priceToShow.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: soldOut
                                      ? ink.withOpacity(0.35)
                                      : (hasDescuento ? Colors.red : primary),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              if (hasDescuento)
                                Text(
                                  'Bs. ${base.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: ink.withOpacity(0.45),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          // Empuja el botón al fondo: alineado entre las dos cards.
                          const Spacer(),

                          SizedBox(
                            height: 40,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: (soldOut || onAddToCart == null)
                                  ? null
                                  : () => onAddToCart!(priceToShow),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: soldOut
                                    ? ink.withOpacity(0.10)
                                    : primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  soldOut ? 'Agotado' : 'Agregar al carrito',
                                  style: TextStyle(
                                    color: soldOut
                                        ? ink.withOpacity(0.75)
                                        : Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
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
      },
    );
  }
}
