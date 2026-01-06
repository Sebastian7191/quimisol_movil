// lib/features/home/detalle_producto.dart
//
// ✅ Nuevo layout pedido:
// - El ROSADO (gradiente) siempre por encima
// - Quitamos el panel blanco "positioned" abajo (el que se tapaba)
// - La info va debajo del rosado (panel blanco normal)
// - Add to Cart + stepper fijo pegado abajo (bottomNavigationBar)
// - SOLO descripción / reseñas es scroll (Expanded + SingleChildScrollView)
//
// ✅ BOTÓN FUNCIONA:
// - Agrega al carrito con la cantidad (qty)
// - Luego navega a CarritoPage

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/home_page_clientes.dart';

// ✅ carrito
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';

class DetalleProductoPage extends StatefulWidget {
  const DetalleProductoPage({super.key, required this.product});

  final ProductModel product;

  @override
  State<DetalleProductoPage> createState() => _DetalleProductoPageState();
}

class _DetalleProductoPageState extends State<DetalleProductoPage> {
  int qty = 1;
  int tab = 0;

  bool _adding = false;

  Future<void> _addToCartAndGo() async {
    if (_adding) return;

    final p = widget.product;

    setState(() => _adding = true);

    try {
      // ✅ agrega con cantidad seleccionada
      await CartStore.I.addProductWithQty(
        productId: p.id,
        name: p.name,
        price: p.price,
        imageUrl: p.imageUrl,
        qty: qty,
      );

      if (!mounted) return;

      // ✅ navega al carrito
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

    final kPinkA = Palette.button;
    final kPinkB = Palette.gradientEnd;

    // ✅ Alto del header rosado (igual que antes)
    const double pinkHeight = 490;

    return Scaffold(
      backgroundColor: Palette.fieldBg,

      // ✅ Botón fijo abajo
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: Row(
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
                    onPressed: _adding ? null : _addToCartAndGo,
                    child: _adding
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Añadir al carrito',
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
        ),
      ),

      body: Column(
        children: [
          // ✅ ROSADO ARRIBA (siempre por encima)
          SizedBox(
            height: pinkHeight,
            width: double.infinity,
            child: Stack(
              children: [
                // Fondo rosado
                Positioned.fill(
                  child: Container(
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

                // Top bar
                SafeArea(
                  bottom: false,
                  child: Padding(
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
                ),

                // Imagen (dentro del rosado)
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 78),
                    child: Hero(
                      tag: 'product_${p.id}', // ✅ consistente con la card
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: SizedBox(
                          height: 295,
                          width: 315,
                          child: Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white.withOpacity(0.22),
                              child: const Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  color: Colors.white,
                                  size: 42,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ✅ INFO DEBAJO (panel blanco normal, YA NO se tapa)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(34),
                  topRight: Radius.circular(34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 22,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Column(
                  children: [
                    // ✅ HEADER FIJO: título + precio
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

                    // “Producto” + chip stock
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Producto',
                            style: TextStyle(
                              color: Palette.ink.withOpacity(0.45),
                              fontWeight: FontWeight.w700,
                            ),
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
                                color: Palette.statsSuccess.withOpacity(0.25),
                              ),
                            ),
                            child: Text(
                              'Stock: ${p.stock}',
                              style: TextStyle(
                                color: Palette.statsSuccess.withOpacity(0.95),
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ✅ TABS FIJOS
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

                    // ✅ SOLO ESTA PARTE SCROLLEA
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Align(
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
                                      ? (p.description.trim().isNotEmpty
                                          ? '${p.description.trim()} '
                                          : 'Sin descripción. ')
                                      : '⭐ ${p.rating.toStringAsFixed(1)} de valoración promedio. '
                                          'Los usuarios destacan la calidad, el empaque y el tiempo de entrega. ',
                                ),
                                TextSpan(
                                  text: 'Ver más',
                                  style: TextStyle(
                                    color: Palette.button,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
