import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quimisol_movil/core/theme/palette.dart';

/// Animación de "agregar al carrito": la foto del producto vuela en curva
/// hasta el ícono del carrito, aparece un "+N" con la cantidad y, al llegar,
/// el ícono rebota.
///
/// Los íconos de carrito ([CartCountBadge]) se registran solos como destino;
/// se usa el que está en la pantalla visible.
class CartFly {
  CartFly._();

  static final List<GlobalKey> _destinos = [];

  /// Cambia cada vez que un producto "llega" al carrito (para el rebote).
  static final ValueNotifier<int> llegada = ValueNotifier<int>(0);

  static void registrarDestino(GlobalKey key) => _destinos.add(key);
  static void quitarDestino(GlobalKey key) => _destinos.remove(key);

  static Rect? _rectDe(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Ícono de carrito de la pantalla que está al frente.
  static Rect? _destinoVisible() {
    for (final key in _destinos.reversed) {
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final route = ModalRoute.of(ctx);
      if (route != null && !route.isCurrent) continue;
      final rect = _rectDe(key);
      if (rect != null) return rect;
    }
    return null;
  }

  /// Hace volar la imagen desde [origen] (la foto del producto) hasta el
  /// carrito. Termina cuando la animación acaba.
  static Future<void> animar(
    BuildContext context, {
    required GlobalKey origen,
    required String imageUrl,
    int cantidad = 1,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final pantalla = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    final desde =
        _rectDe(origen) ??
        Rect.fromCenter(
          center: pantalla.center(Offset.zero),
          width: 120,
          height: 120,
        );
    // Sin ícono de carrito a la vista: va a la esquina superior derecha.
    final hasta =
        _destinoVisible() ??
        Rect.fromCenter(
          center: Offset(pantalla.width - 36, padding.top + 30),
          width: 24,
          height: 24,
        );

    final fin = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Vuelo(
        desde: desde,
        hasta: hasta,
        imageUrl: imageUrl,
        cantidad: cantidad,
        onLlegada: () {
          llegada.value++;
          HapticFeedback.mediumImpact();
        },
        onFin: () {
          entry.remove();
          if (!fin.isCompleted) fin.complete();
        },
      ),
    );

    HapticFeedback.lightImpact();
    overlay.insert(entry);
    return fin.future;
  }
}

class _Vuelo extends StatefulWidget {
  const _Vuelo({
    required this.desde,
    required this.hasta,
    required this.imageUrl,
    required this.cantidad,
    required this.onLlegada,
    required this.onFin,
  });

  final Rect desde;
  final Rect hasta;
  final String imageUrl;
  final int cantidad;
  final VoidCallback onLlegada;
  final VoidCallback onFin;

  @override
  State<_Vuelo> createState() => _VueloState();
}

class _VueloState extends State<_Vuelo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1050),
  );
  bool _llego = false;

  // Fases (0..1): salto inicial, vuelo, llegada al carrito.
  static const double _finSalto = 0.16;
  static const double _finVuelo = 0.80;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_llego && _c.value >= _finVuelo) {
        _llego = true;
        widget.onLlegada();
      }
    });
    _c.forward().whenComplete(widget.onFin);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _iv(double t, double a, double b, [Curve c = Curves.linear]) {
    return c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  /// Punto de una curva cuadrática (de Bézier).
  static Offset _bezier(Offset p0, Offset p1, Offset p2, double t) {
    final u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    final p0 = widget.desde.center;
    final p2 = widget.hasta.center;
    // Punto de control por encima de ambos: el vuelo hace un arco.
    final p1 = Offset(
      p0.dx + (p2.dx - p0.dx) * 0.25,
      math.min(p0.dy, p2.dy) - 140,
    );

    final tamInicial = math.min(widget.desde.shortestSide, 120.0);
    const tamFinal = 22.0;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;

          // Salto: crece un poco antes de despegar.
          final salto = math.sin(math.pi * _iv(t, 0, _finSalto));
          final vuelo = _iv(t, _finSalto, _finVuelo, Curves.easeInOutCubic);
          final llegada = _iv(t, _finVuelo, 1);

          final centro = _bezier(p0, p1, p2, vuelo);
          final tam =
              (tamInicial + (tamFinal - tamInicial) * vuelo) *
              (1 + 0.10 * salto);
          final radio = 18 + (tam / 2 - 18) * vuelo;
          final opacidad = 1 - llegada;

          // "+N" que sube desde el producto.
          final mas = _iv(t, 0.05, 0.70);
          final masOpacidad = math.sin(math.pi * mas);

          return Stack(
            children: [
              // Anillo en el carrito al llegar.
              if (llegada > 0)
                Positioned(
                  left: p2.dx - 14 - 20 * llegada,
                  top: p2.dy - 14 - 20 * llegada,
                  child: Container(
                    width: 28 + 40 * llegada,
                    height: 28 + 40 * llegada,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Palette.button.withValues(alpha: 1 - llegada),
                        width: 3 * (1 - llegada) + 0.5,
                      ),
                    ),
                  ),
                ),

              // La foto en vuelo.
              Positioned(
                left: centro.dx - tam / 2,
                top: centro.dy - tam / 2,
                child: Opacity(
                  opacity: opacidad,
                  child: Transform.rotate(
                    angle: -0.35 * vuelo,
                    child: Container(
                      width: tam,
                      height: tam,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(radio),
                        border: Border.all(
                          color: Palette.white,
                          width: 2 + 1 * (1 - vuelo),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Palette.button.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(radio),
                        child: widget.imageUrl.trim().isEmpty
                            ? const _SinImagen()
                            : Image.network(
                                widget.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const _SinImagen(),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              // "+N"
              if (masOpacidad > 0)
                Positioned(
                  left: p0.dx - 30,
                  top: widget.desde.top - 18 - 46 * mas,
                  width: 60,
                  child: Opacity(
                    opacity: masOpacidad,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Palette.button,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Palette.button.withValues(alpha: 0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          '+${widget.cantidad}',
                          style: const TextStyle(
                            color: Palette.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SinImagen extends StatelessWidget {
  const _SinImagen();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.button.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: const Icon(
        Icons.shopping_bag_rounded,
        color: Palette.primary,
        size: 18,
      ),
    );
  }
}
