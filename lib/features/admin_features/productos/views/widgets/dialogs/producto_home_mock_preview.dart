import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class ProductoHomeMockPreview extends StatelessWidget {
  const ProductoHomeMockPreview({
    super.key,
    required this.productCard,
    this.bannerHeight = 120,
    this.cardTopOffset = 0,
    this.headerHeight = 66,
  });

  final Widget productCard;

  /// Alto del banner (tipo “New Collection”).
  final double bannerHeight;

  /// Offset extra para ajustar la posición del card (si quieres afinar).
  final double cardTopOffset;

  /// Alto del header tipo tu foto.
  final double headerHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        const double padX = 14;
        const double topPad = 10;

        // Top header (como tu foto) y banner debajo
        final double headerTop = topPad;
        final double bannerTop = headerTop + headerHeight + 12;

        // Card más abajo (zona roja)
        final double cardTop = bannerTop + bannerHeight + 34 + cardTopOffset;

        return Stack(
          children: [
            Positioned.fill(child: Container(color: Palette.fieldBg)),

            // ✅ Header tipo foto (sin buscador)
            Positioned(
              top: headerTop,
              left: padX,
              right: padX,
              child: _TopHeaderMock(height: headerHeight),
            ),

            // ✅ Banner
            Positioned(
              top: bannerTop,
              left: padX,
              right: padX,
              child: _BannerMock(height: bannerHeight),
            ),

            // ✅ Card en la “zona roja”
            Positioned(top: cardTop, left: padX, child: productCard),
          ],
        );
      },
    );
  }
}

class _TopHeaderMock extends StatelessWidget {
  const _TopHeaderMock({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Palette.button.withValues(alpha: 0.22),
            Palette.card.withValues(alpha: 0.95),
          ],
        ),
        border: Border.all(color: Palette.button.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          // ubicación: icon + "Todos" + flecha
          Icon(
            Icons.location_on_outlined,
            size: 20,
            color: Palette.ink.withValues(alpha: 0.78),
          ),
          const SizedBox(width: 8),
          const Text(
            'Todos',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Palette.ink,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Palette.ink.withValues(alpha: 0.65),
          ),

          const Spacer(),

          // icons derecha
          _HeaderIcon(icon: Icons.notifications_none_rounded),
          const SizedBox(width: 10),
          _HeaderIcon(icon: Icons.shopping_cart_outlined),
          const SizedBox(width: 10),

          // avatar círculo con letra (como tu ejemplo)
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Palette.statsDanger.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'S',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, size: 20, color: Palette.ink.withValues(alpha: 0.70)),
    );
  }
}

class _BannerMock extends StatelessWidget {
  const _BannerMock({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'New Collection',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Discount 50% for\nthe first transaction',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Palette.ink.withValues(alpha: 0.55),
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Shop Now',
                    style: TextStyle(
                      color: Palette.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 110,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Palette.button.withValues(alpha: 0.25),
                    Palette.card.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.chair_rounded,
                  color: Palette.ink.withValues(alpha: 0.25),
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
