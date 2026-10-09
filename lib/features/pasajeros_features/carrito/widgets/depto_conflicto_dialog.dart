import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';

/// Pregunta al cliente si quiere vaciar el carrito para empezar uno nuevo en
/// otro departamento. Un pedido se despacha desde un solo almacen, por eso no
/// se pueden mezclar productos de Cochabamba y Santa Cruz en la misma compra.
///
/// Devuelve true si el cliente acepta vaciar el carrito.
Future<bool> confirmarCambioDeDepartamento(
  BuildContext context,
  CartDeptoConflicto conflicto,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Productos de otro departamento'),
      content: Text(
        'Tu carrito tiene productos del almacén de ${conflicto.deptoCarrito} '
        'y este producto es del almacén de ${conflicto.deptoProducto}.\n\n'
        'Cada pedido se entrega desde un solo departamento, así que no se '
        'pueden combinar.\n\n'
        '¿Quieres vaciar el carrito y empezar uno nuevo en '
        '${conflicto.deptoProducto}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Palette.button),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Vaciar y agregar'),
        ),
      ],
    ),
  );

  return ok ?? false;
}
