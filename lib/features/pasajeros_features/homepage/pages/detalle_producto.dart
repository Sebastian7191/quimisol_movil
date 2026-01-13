// lib/features/home/detalle_producto.dart

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/home_page_clientes.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';

class DetalleProductoPage extends StatefulWidget {
  const DetalleProductoPage({Key? key, required this.product})
    : super(key: key);

  final ProductModel product;

  @override
  State<DetalleProductoPage> createState() => _DetalleProductoPageState();
}

class _DetalleProductoPageState extends State<DetalleProductoPage> {
  int qty = 1;
  int tab = 0;
  bool _adding = false;

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

  Future<void> _addToCartAndGo({required double priceToUse}) async {
    if (_adding) return;

    final p = widget.product;

    setState(() => _adding = true);

    try {
      await CartStore.I.addProductWithQty(
        productId: p.id,
        name: p.name,
        price: priceToUse,
        imageUrl: p.imageUrl,
        qty: qty,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CarritoPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo agregar al carrito: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    final Color kPinkA = Palette.button;
    final Color kPinkB = Palette.gradientEnd;

    final media = MediaQuery.of(context);
    final double screenH = media.size.height;
    final double bottomInset = media.padding.bottom;

    // ✅ Header adaptable para pantallas chicas
    final double pinkHeight = (screenH * 0.52).clamp(360.0, 490.0);

    // ✅ Reserva real del bottomSheet + safe area
    final double bodyBottomPad = _SlidingCartBar.kMinHeight + bottomInset;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _descuentoStream(p.id),
      builder: (context, snap) {
        final Map<String, dynamic>? d = snap.data?.data();

        final bool activo = (d?['activo'] == true);
        final String tipo = (d?['tipo'] ?? 'PORCENTAJE').toString().trim();
        final double valor = _toDouble(d?['valor']);

        final bool hasDescuento = activo && valor > 0;

        final double base = p.price;
        double finalPrice = base;
        String badge = '';
        String line = '';

        if (hasDescuento) {
          if (tipo == 'PORCENTAJE') {
            final double pct = valor.clamp(0.0, 100.0);
            finalPrice = base * (1 - (pct / 100.0));
            finalPrice = math.max(0.0, finalPrice);

            final String pctTxt = (pct % 1 == 0)
                ? pct.toStringAsFixed(0)
                : pct.toStringAsFixed(1);

            badge = '-$pctTxt%';
            line = 'DESCUENTO $badge';
          } else {
            finalPrice = math.max(0.0, base - valor);

            final String vTxt = (valor % 1 == 0)
                ? valor.toStringAsFixed(0)
                : valor.toStringAsFixed(2);

            badge = '-Bs $vTxt';
            line = 'DESCUENTO $badge';
          }
        }

        final double ahorro = hasDescuento
            ? math.max(0.0, base - finalPrice)
            : 0.0;

        return Scaffold(
          backgroundColor: Palette.fieldBg,

          bottomSheet: _SlidingCartBar(
            qty: qty,
            onMinus: () => setState(() {
              if (qty > 1) qty--;
            }),
            onPlus: () => setState(() => qty++),
            adding: _adding,
            hasDescuento: hasDescuento,
            basePrice: base,
            finalPrice: finalPrice,
            badge: badge,
            line: line,
            stock: p.stock,
            onAdd: () =>
                _addToCartAndGo(priceToUse: hasDescuento ? finalPrice : base),
          ),

          // ✅ AQUÍ: el contenido (panel blanco) es scrolleable, NO draggable
          body: Padding(
            padding: EdgeInsets.only(bottom: bodyBottomPad),
            child: Column(
              children: <Widget>[
                // Header rosado
                SizedBox(
                  height: pinkHeight,
                  width: double.infinity,
                  child: Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: <Color>[kPinkA, kPinkB],
                            ),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(46),
                              bottomRight: Radius.circular(46),
                            ),
                          ),
                        ),
                      ),

                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                          child: Row(
                            children: <Widget>[
                              _TopCircleButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              _TopCircleButton(
                                icon: Icons.more_vert_rounded,
                                onTap: () {},
                              ),
                            ],
                          ),
                        ),
                      ),

                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 78),
                          child: Hero(
                            tag: 'product_${p.id}',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34),
                              child: SizedBox(
                                height: 295,
                                width: 315,
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: (p.imageUrl.trim().isEmpty)
                                          ? Container(
                                              color: Colors.white.withOpacity(
                                                0.22,
                                              ),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  color: Colors.white,
                                                  size: 42,
                                                ),
                                              ),
                                            )
                                          : Image.network(
                                              p.imageUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) {
                                                return Container(
                                                  color: Colors.white
                                                      .withOpacity(0.22),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.image_outlined,
                                                      color: Colors.white,
                                                      size: 42,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                    ),

                                    if (hasDescuento)
                                      Positioned(
                                        left: 14,
                                        top: 14,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            boxShadow: <BoxShadow>[
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.16,
                                                ),
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
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Panel blanco (contenido scrolleable)
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Palette.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(34),
                        topRight: Radius.circular(34),
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 22,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),

                    // ✅ ListView = scroll de TODO el contenido
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      children: <Widget>[
                        // Titulo + precio
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.ink,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: <Widget>[
                                Text(
                                  'Bs. ${(hasDescuento ? finalPrice : base).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: hasDescuento
                                        ? Colors.red
                                        : Palette.button,
                                  ),
                                ),
                                if (hasDescuento)
                                  Text(
                                    'Bs. ${base.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: Palette.ink.withOpacity(0.40),
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  Text(
                                    'Producto',
                                    style: TextStyle(
                                      color: Palette.ink.withOpacity(0.45),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 18,
                                    color: Color(0xFFFFB300),
                                  ),
                                  Text(
                                    p.rating <= 0
                                        ? '0.0'
                                        : p.rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Palette.ink.withOpacity(0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (p.stock > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Palette.statsSuccess.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Palette.statsSuccess.withOpacity(
                                      0.25,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Stock: ${p.stock}',
                                  style: TextStyle(
                                    color: Palette.statsSuccess.withOpacity(
                                      0.95,
                                    ),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        if (hasDescuento) ...<Widget>[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.14),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  height: 34,
                                  width: 34,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.local_offer_rounded,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        line,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ahorras Bs. ${ahorro.toStringAsFixed(2)} por unidad',
                                        style: TextStyle(
                                          color: Palette.ink.withOpacity(0.60),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'HOY',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Tabs
                        Container(
                          height: 44,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Palette.fieldBg,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: _TabChip(
                                  active: tab == 0,
                                  text: 'Detalles',
                                  onTap: () => setState(() => tab = 0),
                                ),
                              ),
                              Expanded(
                                child: _TabChip(
                                  active: tab == 1,
                                  text: 'Reseñas',
                                  onTap: () => setState(() => tab = 1),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            tab == 0 ? 'Detalles' : 'Reseñas',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Palette.ink,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: Palette.ink.withOpacity(0.55),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                            children: <InlineSpan>[
                              TextSpan(
                                text: tab == 0
                                    ? (p.description.trim().isNotEmpty
                                          ? '${p.description.trim()} '
                                          : 'Sin descripcion. ')
                                    : '⭐ ${p.rating.toStringAsFixed(1)} de valoracion promedio. '
                                          'Los usuarios destacan la calidad, el empaque y el tiempo de entrega. ',
                              ),
                              TextSpan(
                                text: 'Ver mas',
                                style: TextStyle(
                                  color: Palette.button,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/* ---------------- BOTTOM SHEET DESLIZABLE ---------------- */

class _SlidingCartBar extends StatefulWidget {
  const _SlidingCartBar({
    Key? key,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    required this.adding,
    required this.hasDescuento,
    required this.basePrice,
    required this.finalPrice,
    required this.badge,
    required this.line,
    required this.stock,
    required this.onAdd,
  }) : super(key: key);

  static const double kMinHeight = 96.0; // ✅ evita overflow
  static const double kMaxHeight = 240.0;

  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  final bool adding;
  final bool hasDescuento;
  final double basePrice;
  final double finalPrice;
  final String badge;
  final String line;
  final int stock;

  final VoidCallback onAdd;

  @override
  State<_SlidingCartBar> createState() => _SlidingCartBarState();
}

class _SlidingCartBarState extends State<_SlidingCartBar> {
  double _h = _SlidingCartBar.kMinHeight;

  double _clamp(double v) {
    final num c = v.clamp(
      _SlidingCartBar.kMinHeight,
      _SlidingCartBar.kMaxHeight,
    );
    return c.toDouble();
  }

  bool get _expanded => _h > (_SlidingCartBar.kMinHeight + 20.0);

  void _snap() {
    final double mid =
        (_SlidingCartBar.kMinHeight + _SlidingCartBar.kMaxHeight) / 2.0;
    setState(() {
      _h = (_h >= mid)
          ? _SlidingCartBar.kMaxHeight
          : _SlidingCartBar.kMinHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double totalUnit = widget.hasDescuento
        ? widget.finalPrice
        : widget.basePrice;
    final double total = totalUnit * widget.qty;

    final double ahorro = widget.hasDescuento
        ? (widget.basePrice - widget.finalPrice).clamp(0.0, double.infinity)
        : 0.0;

    return SafeArea(
      top: false,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutCubic,
        height: _h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(26),
            topRight: Radius.circular(26),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 22,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (DragUpdateDetails d) {
            setState(() => _h = _clamp(_h - d.delta.dy));
          },
          onVerticalDragEnd: (_) => _snap(),
          onTap: _snap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              children: <Widget>[
                Container(
                  height: 4,
                  width: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    _QtyStepper(
                      qty: widget.qty,
                      onMinus: widget.onMinus,
                      onPlus: widget.onPlus,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Palette.button,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: widget.adding ? null : widget.onAdd,
                          child: widget.adding
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Anadir al carrito',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_expanded) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Palette.fieldBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Palette.button.withOpacity(0.12),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        _RowLine(
                          left: 'Precio unitario',
                          right: 'Bs. ${totalUnit.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        if (widget.hasDescuento) ...<Widget>[
                          _RowLine(
                            left: 'Precio original',
                            right: 'Bs. ${widget.basePrice.toStringAsFixed(2)}',
                            rightStyle: TextStyle(
                              color: Palette.ink.withOpacity(0.45),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _RowLine(
                            left: widget.line,
                            right: widget.badge,
                            leftStyle: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                            ),
                            rightStyle: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _RowLine(
                            left: 'Ahorras por unidad',
                            right: 'Bs. ${ahorro.toStringAsFixed(2)}',
                          ),
                          const SizedBox(height: 8),
                        ],
                        _RowLine(left: 'Cantidad', right: 'x ${widget.qty}'),
                        const SizedBox(height: 8),
                        _RowLine(
                          left: 'Stock disponible',
                          right: '${widget.stock}',
                        ),
                        const Divider(height: 18),
                        _RowLine(
                          left: 'Total',
                          right: 'Bs. ${total.toStringAsFixed(2)}',
                          leftStyle: TextStyle(
                            color: Palette.ink,
                            fontWeight: FontWeight.w900,
                          ),
                          rightStyle: TextStyle(
                            color: Palette.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowLine extends StatelessWidget {
  const _RowLine({
    Key? key,
    required this.left,
    required this.right,
    this.leftStyle,
    this.rightStyle,
  }) : super(key: key);

  final String left;
  final String right;
  final TextStyle? leftStyle;
  final TextStyle? rightStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            left,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                leftStyle ??
                TextStyle(
                  color: Palette.ink.withOpacity(0.65),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          right,
          style: rightStyle ?? const TextStyle(fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

/* ---------------- UI COMPONENTS ---------------- */

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({Key? key, required this.icon, required this.onTap})
    : super(key: key);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.25),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    Key? key,
    required this.active,
    required this.text,
    required this.onTap,
  }) : super(key: key);

  final bool active;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Palette.button : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: active ? Colors.white : Palette.ink.withOpacity(0.55),
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    Key? key,
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  }) : super(key: key);

  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: <Widget>[
          _QtyBtn(icon: Icons.remove_rounded, onTap: onMinus),
          SizedBox(
            width: 38,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Palette.ink,
                fontSize: 16,
              ),
            ),
          ),
          _QtyBtn(icon: Icons.add_rounded, onTap: onPlus),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({Key? key, required this.icon, required this.onTap})
    : super(key: key);

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Palette.button.withOpacity(0.25),
            width: 1.2,
          ),
        ),
        child: Icon(icon, size: 18, color: Palette.button),
      ),
    );
  }
}
