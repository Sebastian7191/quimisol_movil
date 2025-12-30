// lib/features/wishlist/wishlist_page.dart
//
// ✅ Wishlist estilo mock (cards, chips, botón “Mover al carrito”)
// ✅ Fondo BLANCO (como pediste)
// ✅ Color principal: Palette.button (rosa)

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  int _filter = 0; // 0 Todo, 1 Ofertas, 2 Recientes, 3 Precio

  final List<_WishItem> _items = [
    _WishItem(
      name: 'Sony WH-1000XM4 Noise Canceling',
      price: 248.00,
      rating: 4.8,
      reviewsText: '(2.4k)',
      imageUrl:
          'https://images.unsplash.com/photo-1518441902117-f0a96b4d29f5?auto=format&fit=crop&w=900&q=60',
      isOffer: true,
    ),
    _WishItem(
      name: 'Nike Air Zoom Pegasus 38',
      price: 120.00,
      rating: 4.9,
      reviewsText: '(856)',
      imageUrl:
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=60',
      isOffer: false,
    ),
    _WishItem(
      name: 'Apple Watch Series 7 GPS',
      price: 399.00,
      rating: 4.7,
      reviewsText: '(1.2k)',
      imageUrl:
          'https://images.unsplash.com/photo-1516574187841-cb9cc2ca948b?auto=format&fit=crop&w=900&q=60',
      isOffer: false,
    ),
    _WishItem(
      name: 'Mochila Herschel Supply Co.',
      price: 65.00,
      rating: 4.5,
      reviewsText: '(320)',
      imageUrl:
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=60',
      isOffer: false,
      soldOut: true,
    ),
  ];

  List<_WishItem> get _filtered {
    final list = List<_WishItem>.from(_items);

    if (_filter == 1) return list.where((e) => e.isOffer && !e.soldOut).toList();
    if (_filter == 2) return list.take(3).toList(); // demo
    if (_filter == 3) {
      list.sort((a, b) => a.price.compareTo(b.price));
      return list;
    }

    return list;
  }

  void _removeAt(int index) {
    setState(() {
      final item = _filtered[index];
      _items.removeWhere((e) => e.name == item.name && e.imageUrl == item.imageUrl);
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button; // rosa
    final ink = Palette.ink;

    // ✅ Fondo blanco
    final bg = Palette.fieldBg;

    // Cards claras (pero con el mismo feeling del mock)
    final cardBg = Palette.white;
    final chipBg = ink.withOpacity(0.06);

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
                    onTap: () {},
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
                      child: Icon(Icons.shopping_cart_outlined,
                          color: ink.withOpacity(0.75), size: 20),
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
                    '${_items.length} artículos guardados',
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
                    text: 'Ofertas',
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
              child: ListView.builder(
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
                      onMoveToCart: it.soldOut ? null : () {},
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
    required this.onMoveToCart,
  });

  final _WishItem item;
  final Color primary;
  final Color cardBg;
  final Color ink;
  final VoidCallback onRemove;
  final VoidCallback? onMoveToCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ink.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Imagen + delete + tag agotado
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    item.imageUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // delete
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ink.withOpacity(0.08)),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        color: ink.withOpacity(0.70), size: 18),
                  ),
                ),
              ),

              // Agotado
              if (item.soldOut)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ink.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Agotado',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11.5,
                      ),
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
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
                const SizedBox(width: 4),
                Text(
                  '${item.rating.toStringAsFixed(1)} ${item.reviewsText}',
                  style: TextStyle(
                    color: ink.withOpacity(0.55),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '\$${item.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: item.soldOut ? ink.withOpacity(0.35) : primary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 44,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: item.soldOut ? ink.withOpacity(0.10) : primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onMoveToCart,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.soldOut
                        ? Icons.notifications_none_rounded
                        : Icons.shopping_cart_outlined,
                    color: item.soldOut ? ink.withOpacity(0.70) : Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    item.soldOut ? 'Avisarme' : 'Mover al carrito',
                    style: TextStyle(
                      color: item.soldOut ? ink.withOpacity(0.75) : Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Model ---------------- */

class _WishItem {
  final String name;
  final double price;
  final double rating;
  final String reviewsText;
  final String imageUrl;
  final bool isOffer;
  final bool soldOut;

  const _WishItem({
    required this.name,
    required this.price,
    required this.rating,
    required this.reviewsText,
    required this.imageUrl,
    required this.isOffer,
    this.soldOut = false,
  });
}
