/*import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quimisol/core/providers/favoritos_provider.dart';

class FavButton extends StatelessWidget {
  final Map<String, dynamic> producto;

  const FavButton({
    super.key,
    required this.producto,
  });

  @override
  Widget build(BuildContext context) {
    final favoritos = Provider.of<FavoritosProvider>(context);
    final idProducto = producto['idproducto'];
    final esFavorito = favoritos.esFavorito(idProducto);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        padding: const EdgeInsets.all(6),
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        icon: Icon(
          esFavorito ? Icons.favorite : Icons.favorite_border,
          color: esFavorito ? Colors.red : Colors.grey,
          size: 20,
        ),
        onPressed: () => favoritos.toggleFavorito(producto),
      ),
    );
  }
}*/