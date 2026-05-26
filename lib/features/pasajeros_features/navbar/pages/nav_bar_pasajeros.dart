import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/home_page_clientes.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/pages/lista_pedidos.dart';
import 'package:quimisol_movil/features/pasajeros_features/perfil/pages/perfil.dart';
import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist.dart';
import 'package:quimisol_movil/features/pasajeros_features/soporte/pages/soporte_chat_page.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/services/pedido_review_service.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/widgets/review_entrega_sheet.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/widgets/review_productos_sheet.dart';
import 'package:quimisol_movil/shared/stores/guest_store.dart';
import 'package:quimisol_movil/shared/widgets/guest_lock_view.dart';

class Navbar extends StatefulWidget {
  final int initialIndex;
  final int initialPedidosTab;

  const Navbar({
    super.key,
    this.initialIndex = 0,
    this.initialPedidosTab = 0,
  });

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  late int _currentIndex;

  final PedidoReviewService _reviewService = PedidoReviewService();

  bool _checkingReview = false;
  bool _reviewFlowDone = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingReviewFlow();
    });
  }

  void _goToDeseados() {
    if (!mounted) return;
    setState(() => _currentIndex = 1);
  }

  void _goToPedidos() {
    if (!mounted) return;
    setState(() => _currentIndex = 2);
  }

  void _goToSoporte() {
    if (!mounted) return;
    setState(() => _currentIndex = 3);
  }

  Future<void> _checkPendingReviewFlow() async {
    if (!mounted || _checkingReview || _reviewFlowDone) return;

    // ✅ Los invitados no tienen pedidos asociados.
    try {
      if (Modular.get<GuestStore>().value) {
        _reviewFlowDone = true;
        return;
      }
    } catch (_) {}

    _checkingReview = true;

    try {
      final doc = await _reviewService.findPendingDeliveredOrder();

      if (!mounted || doc == null || !doc.exists) {
        _reviewFlowDone = true;
        return;
      }

      final data = doc.data() ?? {};
      final pedidoId = doc.id;
      final pedidoCode = (data['codigo'] ?? pedidoId).toString().trim();

      final itemsRaw = (data['items'] as List?) ?? [];
      final items = itemsRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (items.isEmpty) {
        _reviewFlowDone = true;
        return;
      }

      final entregaResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Palette.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => ReviewEntregaSheet(
          pedidoCode: pedidoCode,
        ),
      );

      if (!mounted || entregaResult == null) {
        _reviewFlowDone = true;
        return;
      }

      await _reviewService.saveEntregaReview(
        pedidoId: pedidoId,
        rating: (entregaResult['rating'] ?? 5) as int,
        comentario: (entregaResult['comentario'] ?? '').toString(),
      );

      if (!mounted) {
        _reviewFlowDone = true;
        return;
      }

      final productResult =
          await showModalBottomSheet<List<Map<String, dynamic>>>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Palette.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => ReviewProductosSheet(items: items),
      );

      if (!mounted || productResult == null) {
        _reviewFlowDone = true;
        return;
      }

      await _reviewService.saveProductReviews(
        pedidoId: pedidoId,
        reviews: productResult,
      );

      if (!mounted) {
        _reviewFlowDone = true;
        return;
      }

      setState(() {
        _currentIndex = 2;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gracias por calificar tu pedido y productos.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.statsSuccess,
        ),
      );

      _reviewFlowDone = true;
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al mostrar la calificación: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _checkingReview = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    GuestStore? guestStore;
    try {
      guestStore = Modular.get<GuestStore>();
    } catch (_) {
      guestStore = null;
    }

    return ValueListenableBuilder<bool>(
      valueListenable: guestStore?.isGuest ?? ValueNotifier<bool>(false),
      builder: (_, isGuest, __) {
        final pages = <Widget>[
          const HomeCliente(),
          isGuest
              ? const GuestLockView(
                  icon: Icons.favorite_rounded,
                  title: 'Guarda tus favoritos',
                  message:
                      'Inicia sesión para guardar productos en tu lista de favoritos y volver a ellos cuando quieras.',
                )
              : const WishlistPage(),
          isGuest
              ? const GuestLockView(
                  icon: Icons.shopping_bag_outlined,
                  title: 'Aún no tienes pedidos',
                  message:
                      'Inicia sesión para realizar pedidos y ver el historial de tus compras.',
                )
              : MisPedidosPage(initialTab: widget.initialPedidosTab),
          isGuest
              ? const GuestLockView(
                  icon: Icons.support_agent_rounded,
                  title: 'Soporte para clientes',
                  message:
                      'Inicia sesión para hablar con nuestro equipo de soporte y resolver tus dudas.',
                )
              : const SoporteChatPage(),
          PerfilPage(
            onOpenDeseados: _goToDeseados,
            onOpenPedidos: _goToPedidos,
            onOpenSoporte: _goToSoporte,
          ),
        ];

        return Scaffold(
          backgroundColor: Palette.fieldBg,
          extendBody: true,
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: _BottomPillNavbarAnimated(
            currentIndex: _currentIndex,
            onChanged: (i) => setState(() => _currentIndex = i),
          ),
        );
      },
    );
  }
}

class _BottomPillNavbarAnimated extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BottomPillNavbarAnimated({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = const <_NavItem>[
      _NavItem(icon: Icons.storefront_rounded, label: 'Principal'),
      _NavItem(icon: Icons.favorite_rounded, label: 'Favoritos'),
      _NavItem(icon: Icons.shopping_cart_outlined, label: 'Pedidos'),
      _NavItem(icon: Icons.support_agent_rounded, label: 'Soporte'),
      _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
    ];

    final w = MediaQuery.of(context).size.width;
    final barWidth = math.min(w - 28, 560.0);
    const barHeight = 64.0;

    const bubbleSize = 58.0;
    final notchRadius = bubbleSize * 0.52;

    final barBg = Palette.white;
    final borderColor = Palette.button;
    final labelColor = Palette.primary;
    final iconUnselected = Palette.ink.withOpacity(0.45);
    final iconSelected = Palette.primary;
    final bubbleColor = Palette.button;
    final bubbleIconColor = Palette.white;

    final unit = barWidth / items.length;
    double targetCenterX(int idx) => (unit * idx) + (unit / 2);
    final targetX = targetCenterX(currentIndex);

    return SafeArea(
      top: false,
      child: SizedBox(
        height: barHeight + 22,
        child: Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            tween: Tween<double>(begin: targetX, end: targetX),
            builder: (context, animatedCenterX, _) {
              double bubbleLeft = animatedCenterX - (bubbleSize / 2);
              bubbleLeft =
                  bubbleLeft.clamp(-14.0, barWidth - bubbleSize + 14.0);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    painter: _PillNotchPainterMove(
                      fillColor: barBg,
                      borderColor: borderColor,
                      radius: 26,
                      notchRadius: notchRadius,
                      notchCenterX: animatedCenterX,
                      borderWidth: 2.0,
                    ),
                    child: SizedBox(
                      width: barWidth,
                      height: barHeight,
                      child: Row(
                        children: List.generate(items.length, (i) {
                          final isSelected = currentIndex == i;

                          return Expanded(
                            child: InkWell(
                              onTap: () => onChanged(i),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                                padding:
                                    EdgeInsets.only(top: isSelected ? 4 : 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      items[i].icon,
                                      size: 24,
                                      color: isSelected
                                          ? iconSelected
                                          : iconUnselected,
                                    ),
                                    const SizedBox(height: 4),
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? labelColor
                                            : labelColor.withOpacity(0.65),
                                      ),
                                      child: Text(
                                        items[i].label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: bubbleLeft,
                    top: -18,
                    child: GestureDetector(
                      onTap: () => onChanged(currentIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: bubbleSize,
                        height: bubbleSize,
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: borderColor.withOpacity(0.9),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          items[currentIndex].icon,
                          color: bubbleIconColor,
                          size: 26,
                        ),
                      ),
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

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.label,
  });
}

class _PillNotchPainterMove extends CustomPainter {
  final Color fillColor;
  final Color borderColor;
  final double borderWidth;
  final double radius;
  final double notchRadius;
  final double notchCenterX;

  _PillNotchPainterMove({
    required this.fillColor,
    required this.borderColor,
    required this.radius,
    required this.notchRadius,
    required this.notchCenterX,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = notchCenterX;

    final leftEdge = 0.0;
    final rightEdge = w;

    const startPad = 14.0;

    double x1 = cx - notchRadius - startPad;
    double x2 = cx - notchRadius;
    double x3 = cx + notchRadius;
    double x4 = cx + notchRadius + startPad;

    x1 = x1.clamp(leftEdge + radius, rightEdge - radius);
    x2 = x2.clamp(leftEdge + radius, rightEdge - radius);
    x3 = x3.clamp(leftEdge + radius, rightEdge - radius);
    x4 = x4.clamp(leftEdge + radius, rightEdge - radius);

    if (x2 < x1) x2 = x1;
    if (x3 < x2) x3 = x2;
    if (x4 < x3) x4 = x3;

    final path = Path();

    path.moveTo(radius, 0);
    path.lineTo(x1, 0);

    path.quadraticBezierTo((x1 + x2) / 2, 0, x2, 10);

    path.arcToPoint(
      Offset(x3, 10),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    path.quadraticBezierTo((x3 + x4) / 2, 0, x4, 0);

    path.lineTo(w - radius, 0);
    path.quadraticBezierTo(w, 0, w, radius);

    path.lineTo(w, h - radius);
    path.quadraticBezierTo(w, h, w - radius, h);

    path.lineTo(radius, h);
    path.quadraticBezierTo(0, h, 0, h - radius);

    path.lineTo(0, radius);
    path.quadraticBezierTo(0, 0, radius, 0);

    path.close();

    canvas.drawShadow(path, Colors.black.withOpacity(0.08), 10, true);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = borderColor.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _PillNotchPainterMove oldDelegate) {
    return oldDelegate.notchCenterX != notchCenterX ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.notchRadius != notchRadius;
  }
}