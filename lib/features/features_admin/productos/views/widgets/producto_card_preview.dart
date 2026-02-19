import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class ProductoCardPreview extends StatelessWidget {
  const ProductoCardPreview({
    super.key,
    required this.name,
    required this.priceFinal,
    required this.stock,
    this.rating = 0.0,
    this.imageUrl = '',
    this.pickedBytes,
    this.priceBase,
    this.discountBadgeText, // ahora se muestra como línea debajo del precio
  });

  final String name;
  final double priceFinal;
  final int stock;
  final double rating;

  final String imageUrl;
  final Uint8List? pickedBytes;

  final double? priceBase;
  final String? discountBadgeText;

  @override
  Widget build(BuildContext context) {
    final hasPicked = pickedBytes != null;
    final hasUrl = imageUrl.trim().isNotEmpty;

    final hasDiscount = (priceBase != null) && (priceBase! > priceFinal);
    final discountLine =
        (discountBadgeText ?? '').trim().isEmpty ? null : discountBadgeText!.trim();

    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Like (sin badge arriba)
            Row(
              children: [
                const Spacer(),
                Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: Palette.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 17,
                    color: Palette.ink.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // imagen
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: SizedBox(
                  width: double.infinity,
                  child: hasPicked
                      ? Image.memory(pickedBytes!, fit: BoxFit.cover)
                      : (hasUrl
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (_, __, ___) => const _NoImage(),
                            )
                          : const _NoImage()),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              name.trim().isEmpty ? 'Producto' : name.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: Palette.ink,
              ),
            ),

            const SizedBox(height: 6),

            // ✅ fila precio + rating SIN overflow
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Bs. ${priceFinal.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: Palette.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasDiscount)
                        Flexible(
                          child: Text(
                            'Bs. ${priceBase!.toStringAsFixed(2)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w800,
                              color: Palette.ink.withValues(alpha: 0.45),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 17, color: Color(0xFFFFB300)),
                    const SizedBox(width: 2),
                    Text(
                      rating <= 0 ? '0.0' : rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // ✅ descuento debajo del precio
            if (hasDiscount && discountLine != null) ...[
              const SizedBox(height: 6),
              Text(
                discountLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Palette.statsDanger.withValues(alpha: 0.95),
                  fontWeight: FontWeight.w900,
                  fontSize: 12.0,
                ),
              ),
            ],

            const SizedBox(height: 6),

            Text(
              'Stock: $stock',
              style: TextStyle(
                fontSize: 12.0,
                fontWeight: FontWeight.w800,
                color: Palette.ink.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PhonePreviewFrame extends StatelessWidget {
  const PhonePreviewFrame({
    super.key,
    required this.child,
    this.title = 'Vista previa móvil',
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Palette.ink.withValues(alpha: 0.7),
            fontWeight: FontWeight.w900,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AspectRatio(
              aspectRatio: 9 / 19.5,
              child: Stack(
                children: [
                  Container(
                    color: Palette.fieldBg,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 24, 14, 18),
                      child: child,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        height: 18,
                        width: 96,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        height: 4,
                        width: 90,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
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
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.fieldBg,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Palette.ink.withValues(alpha: 0.25),
          size: 34,
        ),
      ),
    );
  }
}
