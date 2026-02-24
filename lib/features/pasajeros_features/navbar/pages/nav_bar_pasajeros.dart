import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/home_page_clientes.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/pages/lista_pedidos.dart';
import 'package:quimisol_movil/features/pasajeros_features/perfil/pages/perfil.dart';
import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist.dart';
import 'package:quimisol_movil/features/pasajeros_features/soporte/pages/soporte_chat_page.dart'; // ✅ chat soporte

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeCliente(),
      const WishlistPage(),
      const MisPedidosPage(),
      const SoporteChatPage(), // ✅ Soporte (chat)
      const PerfilPage(),
    ];

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      extendBody: true,
      body: pages[_currentIndex],
      bottomNavigationBar: _BottomPillNavbarAnimated(
        currentIndex: _currentIndex,
        onChanged: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// Navbar: mismo diseño + estilos nuevos (blanco + borde rosa + letras moradas)
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
      _NavItem(icon: Icons.favorite_rounded, label: 'Deseados'),
      _NavItem(icon: Icons.shopping_cart_outlined, label: 'Pedidos'),
      _NavItem(icon: Icons.support_agent_rounded, label: 'Soporte'), // ✅ NUEVO
      _NavItem(icon: Icons.person_outline_rounded, label: 'Perfil'),
    ];

    final w = MediaQuery.of(context).size.width;
    final barWidth = math.min(w - 28, 560.0);
    const barHeight = 64.0;

    const bubbleSize = 58.0;
    final notchRadius = bubbleSize * 0.52;

    // ✅ Colores
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
              bubbleLeft = bubbleLeft.clamp(-14.0, barWidth - bubbleSize + 14.0);

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Fondo pill + notch animado
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
                                padding: EdgeInsets.only(top: isSelected ? 4 : 12),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      items[i].icon,
                                      size: 24,
                                      color: isSelected ? iconSelected : iconUnselected,
                                    ),
                                    const SizedBox(height: 4),
                                    AnimatedDefaultTextStyle(
                                      duration: const Duration(milliseconds: 180),
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

                  // Burbuja flotante animada
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
  const _NavItem({required this.icon, required this.label});
}

/// Painter ORIGINAL (sin límites del notch) + relleno blanco + borde rosado
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