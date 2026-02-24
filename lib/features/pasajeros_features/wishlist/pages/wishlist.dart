// wishlist_page.dart

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';

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

  // ✅ mantiene tu lógica (addFromWishlist) pero respeta descuento
  Future<void> _moveToCart(WishItem item, double priceToUse) async {
    final fixed = WishItem(
      id: item.id,
      name: item.name,
      price: priceToUse, // ✅ precio final (con descuento)
      rating: item.rating,
      stock: item.stock,
      imageUrl: item.imageUrl,
    );

    await _cart.addFromWishlist(fixed);
    // ❌ no navegación automática
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button;
    final ink = Palette.ink;

    final bg = Palette.fieldBg;
    final cardBg = Palette.white;
    final chipBg = ink.withValues(alpha: 0.06);

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
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: ink),
                  ),
                  const Spacer(),
                  Text(
                    'Lista de Deseos',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
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
                        border: Border.all(color: ink.withValues(alpha: 0.06)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.shopping_cart_outlined,
                        color: ink.withValues(alpha: 0.75),
                        size: 20,
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
                      color: ink.withValues(alpha: 0.55),
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
                    text: 'Disponibles',
                    active: _filter == 1,
                    primary: primary,
                    chipBg: chipBg,
                    onTap: () => setState(() => _filter = 1),
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
                        'No tienes productos en tu lista de deseos.',
                        style: TextStyle(
                          color: ink.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) {
                        final it = _filtered[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _WishCard(
                            item: it,
                            primary: primary,
                            cardBg: cardBg,
                            ink: ink,
                            onRemove: () => _removeAt(i),
                            onMoveToCart: it.stock <= 0
                                ? null
                                : (priceToUse) => _moveToCart(it, priceToUse),
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
          border: Border.all(color: active ? primary : ink.withValues(alpha: 0.06)),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : ink.withValues(alpha: 0.70),
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
    required this.onMoveToCart,
  });

  final WishItem item;
  final Color primary;
  final Color cardBg;
  final Color ink;
  final VoidCallback onRemove;

  // ✅ manda el precio final al mover al carrito (para aplicar descuento)
  final Future<void> Function(double priceToUse)? onMoveToCart;

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

            final String pctTxt =
                (pct % 1 == 0) ? pct.toStringAsFixed(0) : pct.toStringAsFixed(1);

            badge = '-$pctTxt%';
          } else {
            finalPrice = math.max(0.0, base - valor);

            final String vTxt =
                (valor % 1 == 0) ? valor.toStringAsFixed(0) : valor.toStringAsFixed(2);

            badge = '-Bs $vTxt';
          }
        }

        final double priceToShow = hasDescuento ? finalPrice : base;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ink.withValues(alpha: 0.06)),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: ink.withValues(alpha: 0.06),
                          child: Icon(
                            Icons.image_outlined,
                            color: ink.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ✅ Badge descuento
                  if (hasDescuento)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
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
                    top: 8,
                    right: 8,
                    child: InkWell(
                      onTap: onRemove,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: ink.withValues(alpha: 0.70),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              // ✅ Precio con descuento + tachado
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Bs. ${priceToShow.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: soldOut
                          ? ink.withValues(alpha: 0.35)
                          : (hasDescuento ? Colors.red : primary),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (hasDescuento)
                    Text(
                      'Bs. ${base.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: ink.withValues(alpha: 0.45),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 44,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (soldOut || onMoveToCart == null)
                      ? null
                      : () => onMoveToCart!(priceToShow),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: soldOut ? ink.withValues(alpha: 0.10) : primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    soldOut ? 'Agotado' : 'Mover al carrito',
                    style: TextStyle(
                      color: soldOut ? ink.withValues(alpha: 0.75) : Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
