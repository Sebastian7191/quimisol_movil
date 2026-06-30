// lib/features/banners/widgets/preview/banner_promo_preview.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class BannerPromoPreview extends StatelessWidget {
  const BannerPromoPreview({
    super.key,
    required this.title,
    required this.subtitle,
    this.buttonText = 'Ver más',
    this.imageUrl = '',
    this.pickedBytes,
  });

  final String title;
  final String subtitle;
  final String buttonText;

  final String imageUrl;
  final Uint8List? pickedBytes;

  @override
  Widget build(BuildContext context) {
    final hasPicked = pickedBytes != null;
    final hasUrl = imageUrl.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: LayoutBuilder(
            builder: (context, c) {
              // ✅ estilo como tu card “pedido”: imagen grande a la derecha
              final imgW = (c.maxWidth * 0.46).clamp(150.0, 260.0);

              return Row(
                children: [
                  // LEFT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.trim().isEmpty ? 'descuentos' : title.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: Palette.ink,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle.trim().isEmpty ? '20%' : subtitle.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Palette.ink.withValues(alpha: 0.62),
                          ),
                        ),
                        const Spacer(),
                        _PrimaryButton(
                          text: buttonText.trim().isEmpty ? 'Ver más' : buttonText.trim(),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 14),

                  // RIGHT IMAGE
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: imgW,
                      height: double.infinity,
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
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _PrimaryButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Palette.primary.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                blurRadius: 12,
                offset: const Offset(0, 6),
                color: Palette.primary.withValues(alpha: 0.16),
              ),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Palette.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ),
      ),
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
