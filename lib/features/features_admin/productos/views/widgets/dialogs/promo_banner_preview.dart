import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class PromoBannerPreview extends StatelessWidget {
  const PromoBannerPreview({
    super.key,
    required this.productTitle,
    required this.discountSubtitle,
    this.imageUrl,
    this.imageBytes,
    this.buttonText = 'Ver más',
  });

  /// Ej: "Alcohol en gel 1L"
  final String productTitle;

  /// Ej: "Descuento -10%" o "Descuento -Bs 5.00"
  final String discountSubtitle;

  /// URL remota (si ya existe imagen guardada)
  final String? imageUrl;

  /// Bytes (si el usuario seleccionó imagen en el dialog)
  final Uint8List? imageBytes;

  /// Texto del botón (por defecto: Ver más)
  final String buttonText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAD5F3),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            // Texto izquierda
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    productTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Palette.ink,
                      fontSize: 17.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    discountSubtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Palette.ink.withValues(alpha: 0.55),
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      fontSize: 14.1,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Botón: Ver más
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: SizedBox(
                      height: 38,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7E57C2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14.5,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(buttonText, maxLines: 1),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Imagen derecha (bytes > url > placeholder)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(width: 112, height: 86, child: _buildImage()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    // 1) si seleccionaron imagen en el dialog
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      return Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
    }

    // 2) si hay URL guardada
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    // 3) placeholder
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF2E7F8),
      child: Icon(
        Icons.local_offer_rounded,
        color: Palette.ink.withValues(alpha: 0.25),
        size: 34,
      ),
    );
  }
}
