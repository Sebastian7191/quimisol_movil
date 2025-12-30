// lib/features/cart/carrito_page.dart
//
// ✅ Carrito EXACTO al mock (layout + spacing + cards + resumen + cupón + botón)
// ✅ Usa tu Palette (rosa principal: Palette.button)
// ✅ Total a pagar = Subtotal - Descuento + Envío

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final TextEditingController _couponCtrl = TextEditingController();

  final List<_CartItem> _items = [
    _CartItem(
      name: 'Nike Air Zoom',
      subtitle: 'Talla: 42 • Color: Negro',
      price: 120.00,
      qty: 1,
      imageUrl:
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=400&q=60',
    ),
    _CartItem(
      name: 'Sony WH-1000XM5',
      subtitle: 'Color: Plata',
      price: 350.00,
      qty: 1,
      imageUrl:
          'https://images.unsplash.com/photo-1546435770-a3e426bf472b?auto=format&fit=crop&w=400&q=60',
    ),
    _CartItem(
      name: 'MacBook Air M2',
      subtitle: '256GB SSD • 8GB RAM',
      price: 999.00,
      qty: 1,
      imageUrl:
          'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?auto=format&fit=crop&w=400&q=60',
    ),
  ];

  double get _subtotal {
    double sum = 0;
    for (final it in _items) {
      sum += it.price * it.qty;
    }
    return sum;
  }

  // ✅ Descuento 8% (antes era tax)
  double get _discount => _subtotal * 0.08;

  // Mock: envío gratis
  double get _shipping => 0;

  // ✅ Total = Subtotal - Descuento + Envío
  double get _total {
    final t = _subtotal - _discount + _shipping;
    return t < 0 ? 0 : t;
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    super.dispose();
  }

  void _clearCart() {
    setState(() => _items.clear());
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  void _incQty(int index) {
    setState(() => _items[index] =
        _items[index].copyWith(qty: _items[index].qty + 1));
  }

  void _decQty(int index) {
    final current = _items[index].qty;
    if (current <= 1) return;
    setState(() =>
        _items[index] = _items[index].copyWith(qty: current - 1));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button; // rosa principal
    final ink = Palette.ink;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: ink),
                  ),
                  Expanded(
                    child: Text(
                      'Tu Carrito',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _items.isEmpty ? null : _clearCart,
                    child: Text(
                      'Vaciar',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Lista + resumen (scroll)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  children: [
                    // Items
                    ...List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CartCard(
                          item: item,
                          primary: primary,
                          onRemove: () => _removeItem(i),
                          onMinus: () => _decQty(i),
                          onPlus: () => _incQty(i),
                        ),
                      );
                    }),

                    // Si está vacío
                    if (_items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 52, color: ink.withOpacity(0.35)),
                            const SizedBox(height: 10),
                            Text(
                              'Tu carrito está vacío',
                              style: TextStyle(
                                color: ink.withOpacity(0.65),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Resumen
                    if (_items.isNotEmpty) ...[
                      _SummaryRow(
                        left: 'Subtotal',
                        right: '\$${_subtotal.toStringAsFixed(2)}',
                        rightColor: ink,
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        left: 'Envío',
                        right: 'Gratis',
                        rightColor: primary,
                      ),
                      const SizedBox(height: 10),

                      // ✅ Descuento se muestra y se resta en el total
                      _SummaryRow(
                        left: 'Descuento (8%)',
                        right: '- \$${_discount.toStringAsFixed(2)}',
                        rightColor: ink,
                      ),

                      const SizedBox(height: 16),

                      // Cupón
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: Palette.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: ink.withOpacity(0.06),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  Icon(Icons.local_offer_outlined,
                                      color: ink.withOpacity(0.45), size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _couponCtrl,
                                      decoration: InputDecoration(
                                        hintText: 'Código de descuento',
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(
                                          color: ink.withOpacity(0.35),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: TextStyle(
                                        color: ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            width: 110,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary.withOpacity(0.18),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () {},
                              child: Text(
                                'Aplicar',
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Total a pagar
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total a pagar',
                          style: TextStyle(
                            color: ink.withOpacity(0.55),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '\$${_total.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Botón inferior (Pagar Ahora)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: SizedBox(
                height: 58,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _items.isEmpty ? null : () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Pagar Ahora',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Widgets ---------------- */

class _CartCard extends StatelessWidget {
  const _CartCard({
    required this.item,
    required this.primary,
    required this.onRemove,
    required this.onMinus,
    required this.onPlus,
  });

  final _CartItem item;
  final Color primary;
  final VoidCallback onRemove;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: ink.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          // Imagen
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: ink.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: onRemove,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(Icons.delete_outline_rounded,
                            size: 20, color: ink.withOpacity(0.45)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink.withOpacity(0.45),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    _QtyPill(
                      qty: item.qty,
                      primary: primary,
                      onMinus: onMinus,
                      onPlus: onPlus,
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
}

class _QtyPill extends StatelessWidget {
  const _QtyPill({
    required this.qty,
    required this.primary,
    required this.onMinus,
    required this.onPlus,
  });

  final int qty;
  final Color primary;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyIconBtn(
            icon: Icons.remove_rounded,
            onTap: onMinus,
            color: primary,
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _QtyIconBtn(
            icon: Icons.add_rounded,
            onTap: onPlus,
            color: primary,
          ),
        ],
      ),
    );
  }
}

class _QtyIconBtn extends StatelessWidget {
  const _QtyIconBtn({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.left,
    required this.right,
    required this.rightColor,
  });

  final String left;
  final String right;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Row(
      children: [
        Text(
          left,
          style: TextStyle(
            color: ink.withOpacity(0.55),
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          right,
          style: TextStyle(
            color: rightColor,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

/* ---------------- Model ---------------- */

class _CartItem {
  final String name;
  final String subtitle;
  final double price;
  final int qty;
  final String imageUrl;

  const _CartItem({
    required this.name,
    required this.subtitle,
    required this.price,
    required this.qty,
    required this.imageUrl,
  });

  _CartItem copyWith({
    String? name,
    String? subtitle,
    double? price,
    int? qty,
    String? imageUrl,
  }) {
    return _CartItem(
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
