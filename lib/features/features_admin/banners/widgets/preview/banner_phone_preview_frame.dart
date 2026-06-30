// lib/features/banners/widgets/preview/banner_phone_preview_frame.dart
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class BannerPhonePreviewFrame extends StatelessWidget {
  const BannerPhonePreviewFrame({
    super.key,
    required this.child,
    this.title = 'Vista previa móvil',
  });

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    // ✅ Este es el “casco” del teléfono (solo UI)
    Widget phoneShell() {
      return Container(
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
                  color: Palette.white,
                  child: Padding(
                    // ✅ un poco menos bottom para no “pelear” con la barra inferior
                    padding: const EdgeInsets.fromLTRB(4, 24, 4, 14),
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
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        final boundedH = box.maxHeight.isFinite;

        // Si no hay límite de alto (por ejemplo dentro de un scroll),
        // se dibuja normal.
        if (!boundedH) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              phoneShell(),
            ],
          );
        }

        // ✅ Si el alto está limitado (caso del Dialog panel),
        // hacemos que el teléfono se “encaje” y no desborde.
        return SizedBox(
          height: box.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Palette.ink.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),

              // ✅ el resto del alto disponible se lo damos al teléfono
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown, // ✅ ANTI-OVERFLOW
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 292, // ancho base
                      child: phoneShell(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
