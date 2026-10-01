import 'package:flutter/material.dart';

import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';

/// Pone sobre [child] (el ícono del carrito) una burbuja roja con la cantidad
/// de productos distintos del carrito. Se oculta si está vacío.
///
/// Escucha [CartStore.I], así que se actualiza solo al agregar o quitar.
class CartCountBadge extends StatelessWidget {
  const CartCountBadge({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CartStore.I,
      builder: (_, child) {
        final count = CartStore.I.items.length;

        return Stack(
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
        );
      },
      child: child,
    );
  }
}
