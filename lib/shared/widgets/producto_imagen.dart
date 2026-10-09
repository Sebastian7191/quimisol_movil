import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';

/// Foto de un producto dentro de un pedido o carrito.
///
/// Los pedidos guardan la URL de la foto que tenía el producto al comprar.
/// Si el admin cambia la foto, el archivo viejo se borra de Storage y esa
/// URL deja de funcionar. En ese caso (o si no hay URL) se muestra la foto
/// actual del producto (`productos/{productId}`).
class ProductoImagen extends StatelessWidget {
  const ProductoImagen({
    super.key,
    required this.productId,
    required this.imageUrl,
    this.size = 52,
    this.radius = 10,
  });

  final String productId;
  final String imageUrl;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? _FotoActual(productId: productId, size: size)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _FotoActual(productId: productId, size: size),
              ),
      ),
    );
  }
}

/// Foto actual del producto (una consulta por producto mientras la app
/// está abierta).
class _FotoActual extends StatelessWidget {
  const _FotoActual({required this.productId, required this.size});

  final String productId;
  final double size;

  static final Map<String, Future<String>> _cache = {};

  static Future<String> _urlActual(String id) {
    if (id.isEmpty) return Future.value('');
    return _cache.putIfAbsent(id, () async {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('productos')
            .doc(id)
            .get();
        final d = snap.data() ?? const <String, dynamic>{};
        return (d['imagenUrl'] ?? d['imageUrl'] ?? '').toString().trim();
      } catch (_) {
        _cache.remove(id); // se reintenta la próxima vez
        return '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlActual(productId.trim()),
      builder: (context, snap) {
        final url = snap.data ?? '';
        if (url.isEmpty) return _SinFoto(size: size);
        return Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _SinFoto(size: size),
        );
      },
    );
  }
}

class _SinFoto extends StatelessWidget {
  const _SinFoto({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.ink.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size * 0.42,
        color: Palette.ink.withValues(alpha: 0.4),
      ),
    );
  }
}
