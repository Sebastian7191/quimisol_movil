import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
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
import 'package:quimisol_movil/core/services/notification/local_notification_service.dart';

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

  bool _isFirstEmission = true;
  bool _checkingReview = false;
  final Set<String> _processedPedidoIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pedidosSub;

  bool _isFirstPagoEmission = true;
  final Set<String> _notifiedRejectedIds = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _pagoSub;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startReviewListener();
      _startPaymentRejectionListener();
    });
  }

  @override
  void dispose() {
    _pedidosSub?.cancel();
    _pagoSub?.cancel();
    super.dispose();
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

  void _startPaymentRejectionListener() {
    try {
      if (Modular.get<GuestStore>().value) return;
    } catch (_) {}

    _pagoSub = _reviewService.watchPagosRechazados().listen((snap) async {
      if (!mounted) return;

      if (_isFirstPagoEmission) {
        _isFirstPagoEmission = false;
        // Primera emisión: registrar rechazos ya existentes sin notificar.
        for (final doc in snap.docs) {
          _notifiedRejectedIds.add(doc.id);
        }
        return;
      }

      // Emisiones siguientes: solo pedidos que acaban de ser rechazados.
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final doc = change.doc;
        if (_notifiedRejectedIds.contains(doc.id)) continue;
        _notifiedRejectedIds.add(doc.id);

        final data = doc.data();
        final pedidoCode =
            (data?['codigo'] ?? doc.id).toString().trim();

        // Notificación local (aparece en el sistema aunque la app esté en foco).
        await LocalNotificationService()
            .showPaymentRejected(pedidoCode: pedidoCode);

        if (!mounted) return;

        // Banner in-app con acceso rápido a Pedidos.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'El pago del pedido #$pedidoCode fue rechazado. '
              'Sube un nuevo comprobante.',
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'Ver',
              textColor: Colors.white,
              onPressed: () {
                if (mounted) setState(() => _currentIndex = 2);
              },
            ),
          ),
        );
      }
    });
  }

  // Escucha en tiempo real pedidos Entregados. En la primera emisión procesa
  // cualquier reseña pendiente (igual que antes al abrir la app). En emisiones
  // siguientes detecta pedidos que acaban de cambiar a Entregado y dispara el
  // flujo de reseña sin que el usuario tenga que cerrar y volver a abrir.
  void _startReviewListener() {
    try {
      if (Modular.get<GuestStore>().value) return;
    } catch (_) {}

    _pedidosSub = _reviewService.watchDeliveredOrders().listen((snap) async {
      if (!mounted) return;

      if (_isFirstEmission) {
        _isFirstEmission = false;
        // Primera emisión: buscar pedido Entregado sin reseña (inicio de app).
        for (final doc in snap.docs) {
          final data = doc.data();
          if (data['reviewEntrega'] == null) {
            await _runReviewFlow(doc);
            break;
          }
        }
        return;
      }

      // Emisiones posteriores: solo documentos recién añadidos al resultado
      // (pedidos que acaban de pasar a estado Entregado).
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final doc = change.doc;
        final data = doc.data();
        if (data == null || data['reviewEntrega'] != null) continue;
        if (_processedPedidoIds.contains(doc.id)) continue;

        await _runReviewFlow(doc);
        break;
      }
    });
  }

  Future<void> _runReviewFlow(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (!mounted || _checkingReview) return;

    _checkingReview = true;
    _processedPedidoIds.add(doc.id);

    try {
      final data = doc.data();
      if (data == null) return;
      final pedidoId = doc.id;
      final pedidoCode = (data['codigo'] ?? pedidoId).toString().trim();

      final itemsRaw = (data['items'] as List?) ?? [];
      final items = itemsRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (items.isEmpty) return;

      final entregaResult = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Palette.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => ReviewEntregaSheet(pedidoCode: pedidoCode),
      );

      if (!mounted || entregaResult == null) return;

      if (entregaResult['skipped'] == true) {
        await _reviewService.skipEntregaReview(pedidoId: pedidoId);
        return;
      }

      await _reviewService.saveEntregaReview(
        pedidoId: pedidoId,
        rating: (entregaResult['rating'] ?? 5) as int,
        comentario: (entregaResult['comentario'] ?? '').toString(),
      );

      if (!mounted) return;

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

      if (!mounted || productResult == null) return;

      await _reviewService.saveProductReviews(
        pedidoId: pedidoId,
        reviews: productResult,
      );

      if (!mounted) return;

      setState(() => _currentIndex = 2);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gracias por calificar tu pedido y productos.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Palette.statsSuccess,
        ),
      );
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

        return PopScope(
          // Sin esto, "atras" en cualquier pestaña que no sea Principal
          // cerraba la app: el navbar es la ruta raiz, asi que el pop se
          // llevaba toda la pantalla. Ahora solo sale desde Principal.
          canPop: _currentIndex == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;

            // Soporte vive en el IndexedStack y tambien recibe este evento.
            // Si solo estaba cerrando su selector de emojis, no cambiamos
            // de pestaña encima.
            if (SoporteChatPage.selectorEmojisAbierto) return;

            if (_currentIndex != 0) setState(() => _currentIndex = 0);
          },
          child: Scaffold(
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