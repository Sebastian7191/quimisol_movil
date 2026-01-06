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

  Future<void> _moveToCart(WishItem item) async {
    await _cart.addFromWishlist(item);
    // ❌ no navegación automática
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
                          color: ink.withOpacity(0.55),
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
                            onMoveToCart:
                                it.stock <= 0 ? null : () => _moveToCart(it),
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

  final WishItem item;
  final Color primary;
  final Color cardBg;
  final Color ink;
  final VoidCallback onRemove;
  final VoidCallback? onMoveToCart;

  @override
  Widget build(BuildContext context) {
    final soldOut = item.stock <= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ink.withOpacity(0.06)),
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
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: InkWell(
                  onTap: onRemove,
                  child: Icon(Icons.delete_outline_rounded,
                      color: ink.withOpacity(0.70)),
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bs. ${item.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: soldOut ? ink.withOpacity(0.35) : primary,
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
              onPressed: onMoveToCart,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    soldOut ? ink.withOpacity(0.10) : primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                soldOut ? 'Agotado' : 'Mover al carrito',
                style: TextStyle(
                  color: soldOut ? ink.withOpacity(0.75) : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
