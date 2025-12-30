// lib/features/home/detalle_producto.dart
//
// ✅ Layout como tu captura:
// - Rosa arriba
// - Blanco abajo
// - Rosa “tapa” un poco al blanco (superposición suave)
// - Imagen un poquito MÁS GRANDE y un poco MÁS ABAJO
// - La imagen NO se sale del área rosa

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/home_page_clientes.dart';

class DetalleProductoPage extends StatefulWidget {
  const DetalleProductoPage({super.key, required this.product});

  final ProductModel product;

  @override
  State<DetalleProductoPage> createState() => _DetalleProductoPageState();
}

class _DetalleProductoPageState extends State<DetalleProductoPage> {
  int qty = 1;
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    final kPinkA = Palette.button;
    final kPinkB = Palette.gradientEnd;

    // ✅ Rosa un poco más “abajo” para tapar un poquito la parte blanca
    const double pinkHeight = 490;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: Stack(
        children: [
          // 1) Panel blanco abajo (debajo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(34),
                  topRight: Radius.circular(34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 26,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título + precio
                  Row(
                    children: [
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
                      Text(
                        'Bs. ${p.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Palette.button,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Producto',
                      style: TextStyle(
                        color: Palette.ink.withOpacity(0.45),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

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
                      children: [
                        Expanded(
                          child: _TabChip(
                            active: tab == 0,
                            text: 'Details',
                            onTap: () => setState(() => tab = 0),
                          ),
                        ),
                        Expanded(
                          child: _TabChip(
                            active: tab == 1,
                            text: 'Reviews',
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

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: Palette.ink.withOpacity(0.55),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                        children: [
                          TextSpan(
                            text: tab == 0
                                ? 'Un producto ideal para tu compra. Calidad garantizada y entrega rápida. Perfecto para el uso diario y compatible con diferentes necesidades. '
                                : '⭐ ${p.rating.toStringAsFixed(1)} de valoración promedio. Los usuarios destacan la calidad, el empaque y el tiempo de entrega. ',
                          ),
                          TextSpan(
                            text: 'See more.',
                            style: TextStyle(
                              color: Palette.button,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Stepper + Add to cart
                  Row(
                    children: [
                      _QtyStepper(
                        qty: qty,
                        onMinus: () {
                          if (qty > 1) setState(() => qty--);
                        },
                        onPlus: () => setState(() => qty++),
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
                            onPressed: () {},
                            child: const Text(
                              'Add to Cart',
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
                ],
              ),
            ),
          ),

          // 2) Fondo rosa arriba (encima)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: pinkHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [kPinkA, kPinkB],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(46),
                  bottomRight: Radius.circular(46),
                ),
              ),
            ),
          ),

          // 3) Contenido encima
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: Row(
                    children: [
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

                // ✅ Imagen: un poco MÁS ABAJO y un poco MÁS GRANDE
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: Hero(
                    tag: 'product_${p.name}_${p.imageUrl}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: SizedBox(
                        height: 295,
                        width: 315,
                        child: Image.network(
                          p.imageUrl,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),

                // ✅ Ajuste fino para que el layout quede como tu captura
                const SizedBox(height: 165),

                const Spacer(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- UI COMPONENTS ---------------- */

class _TopCircleButton extends StatelessWidget {
  const _TopCircleButton({required this.icon, required this.onTap});

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
    required this.active,
    required this.text,
    required this.onTap,
  });

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
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

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
        children: [
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
  const _QtyBtn({required this.icon, required this.onTap});

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
