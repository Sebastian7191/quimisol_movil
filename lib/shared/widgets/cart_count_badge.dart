import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';
import 'package:quimisol_movil/shared/widgets/cart_fly_animation.dart';

/// Pone sobre [child] (el ícono del carrito) una burbuja roja con la cantidad
/// de productos distintos del carrito. Se oculta si está vacío.
///
/// Escucha [CartStore.I], así que se actualiza solo al agregar o quitar.
/// Además es el destino de la animación de [CartFly]: rebota cuando un
/// producto "llega" al carrito.
class CartCountBadge extends StatefulWidget {
  const CartCountBadge({super.key, required this.child});

  final Widget child;

  @override
  State<CartCountBadge> createState() => _CartCountBadgeState();
}

class _CartCountBadgeState extends State<CartCountBadge>
    with SingleTickerProviderStateMixin {
  final GlobalKey _destinoKey = GlobalKey();

  late final AnimationController _rebote = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void initState() {
    super.initState();
    CartFly.registrarDestino(_destinoKey);
    CartFly.llegada.addListener(_onLlegada);
  }

  @override
  void dispose() {
    CartFly.quitarDestino(_destinoKey);
    CartFly.llegada.removeListener(_onLlegada);
    _rebote.dispose();
    super.dispose();
  }

  void _onLlegada() {
    if (mounted) _rebote.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([CartStore.I, _rebote]),
      builder: (_, child) {
        final count = CartStore.I.items.length;

        // Rebote amortiguado: crece, se pasa un poco hacia abajo y vuelve.
        final t = _rebote.value;
        final escala = 1 + 0.32 * math.sin(math.pi * 2.2 * t) * (1 - t);

        return Transform.scale(
          scale: escala,
          child: Stack(
            key: _destinoKey,
            clipBehavior: Clip.none,
            children: [
              child!,
              if (count > 0)
                Positioned(
                  top: -5,
                  right: -5,
                  child: IgnorePointer(
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        count > 99 ? '99+' : '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
