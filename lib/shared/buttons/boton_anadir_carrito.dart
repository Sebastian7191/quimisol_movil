import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/services/postgresql/carrito/carrito_service.dart';
import 'package:quimisol_movil/core/storage/auth_storage.dart';

class BotonAnadirCarrito extends StatelessWidget {
  final int idProducto;
  final int cantidad;

  const BotonAnadirCarrito({
    super.key,
    required this.idProducto,
    this.cantidad = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        final idUsuario = await AuthStorage.getIdPersona();

        if (idUsuario == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes iniciar sesión')),
          );
          return;
        }

        try {
          final ok = await CarritoService.agregarProductoAlCarrito(
            idUsuario: idUsuario,
            idProducto: idProducto,
            cantidad: cantidad,
          );
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Producto añadido a la cesta')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Añadir a la cesta'),
    );
  }
}
