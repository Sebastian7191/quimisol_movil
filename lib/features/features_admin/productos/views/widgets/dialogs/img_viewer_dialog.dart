import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class ImageViewerDialog extends StatelessWidget {
  final String title;
  final String imagenPath;
  final String imagenUrl;

  const ImageViewerDialog({
    super.key,
    required this.title,
    required this.imagenPath,
    required this.imagenUrl,
  });

  Widget _buildImageContent(String imagenUrl) {
    final url = imagenUrl.trim();
    if (url.isEmpty) {
      return Center(
        child: Text(
          'Sin imagen',
          style: TextStyle(color: Palette.ink.withValues(alpha: 0.7)),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(
        child: Text(
          'No se pudo cargar la imagen',
          style: TextStyle(color: Palette.ink.withValues(alpha: 0.75)),
        ),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Palette.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildImageContent(imagenUrl),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.button,
                    foregroundColor: Palette.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
