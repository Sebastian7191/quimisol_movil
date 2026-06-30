import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class BannerCardBodyPreview extends StatelessWidget {
  const BannerCardBodyPreview({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.imageUrl,
    this.pickedBytes,
  });

  final String titulo;
  final String subtitulo;
  final String imageUrl;
  final Uint8List? pickedBytes;

  @override
  Widget build(BuildContext context) {
    final hasPicked = pickedBytes != null;
    final hasUrl = imageUrl.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.button.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 10),
          child: LayoutBuilder(
            builder: (context, c) {
              final isMobileCard = c.maxWidth < 420;

              if (isMobileCard) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: SizedBox(
                            width: double.infinity,
                            height: 96,
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
                    ),
                    const SizedBox(height: 10),
                    Text(
                      titulo.trim().isEmpty ? 'Banner' : titulo.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: Palette.ink,
                        height: 1.05,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitulo.trim().isEmpty ? '-' : subtitulo.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink.withValues(alpha: 0.62),
                      ),
                    ),
                    const Spacer(),
                  ],
                );
              }

              // Desktop/Tablet preview: mismo layout horizontal, sin botón
              final imageW = (c.maxWidth * 0.34).clamp(110.0, 200.0);

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo.trim().isEmpty ? 'Banner' : titulo.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: Palette.ink,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitulo.trim().isEmpty ? '-' : subtitulo.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Palette.ink.withValues(alpha: 0.62),
                          ),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: imageW,
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

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black12,
      child: Center(
        child: Icon(
          Icons.image_not_supported_rounded,
          color: Palette.ink.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
