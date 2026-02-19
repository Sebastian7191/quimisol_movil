import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/banners/controllers/banners_dialog_controller.dart';


import 'banner_phone_preview_frame.dart';
import 'banner_card_body_preview.dart';

class BannerDialogPreviewPanel extends StatelessWidget {
  const BannerDialogPreviewPanel({super.key, required this.controller});

  final BannersDialogController controller;

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Palette.button.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Palette.button.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.phone_iphone_rounded,
                  color: Palette.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Vista previa',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ✅ CLAVE: ocupar el alto disponible del panel y encajar el teléfono
          Expanded(
            child: ValueListenableBuilder<int>(
              valueListenable: controller.previewTick,
              builder: (_, __, ___) {
                final t = controller.tituloCtrl.text.trim();
                final s = controller.subtituloCtrl.text.trim();

                final url = controller.previewUrl;
                final bytes = controller.previewBytes;

                // Tamaño “base” del teléfono (el FittedBox lo reduce si no cabe)
                const double phoneWidth = 292;

                final phone = SizedBox(
                  width: phoneWidth,
                  child: BannerPhonePreviewFrame(
                    title: 'Vista previa móvil',
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cardW =
                            (constraints.maxWidth * 0.92).clamp(210.0, 260.0);

                        return ColoredBox(
                          color: Palette.white,
                          child: ScrollConfiguration(
                            behavior: const _NoScrollbarScrollBehavior(),
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding:
                                  const EdgeInsets.only(top: 10, bottom: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min, // ✅ CLAVE
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints:
                                          BoxConstraints(maxWidth: cardW),
                                      child: SizedBox(
                                        height: 130,
                                        child: BannerCardBodyPreview(
                                          titulo: t.isEmpty ? 'Banner' : t,
                                          subtitulo: s.isEmpty ? '-' : s,
                                          imageUrl: url,
                                          pickedBytes: bytes,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );

                // ✅ Encajar dentro del panel para que JAMÁS desborde (alto o ancho)
                return LayoutBuilder(
                  builder: (_, box) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: box.maxWidth,
                          maxHeight: box.maxHeight,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown, // ✅ anti-overflow definitivo
                          alignment: Alignment.topCenter,
                          child: phone,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final Widget child;
  const _PanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.button.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _NoScrollbarScrollBehavior extends ScrollBehavior {
  const _NoScrollbarScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
