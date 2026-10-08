import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Abre [url] a pantalla completa con zoom: pellizcar para acercar,
/// arrastrar para moverse y doble toque para alternar el zoom.
Future<void> abrirImagenCompleta(
  BuildContext context,
  String url, {
  String? titulo,
}) {
  if (url.trim().isEmpty) return Future.value();

  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) =>
          _ImagenCompletaPage(url: url, titulo: titulo),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(
            begin: 0.96,
            end: 1.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ),
  );
}

/// Envuelve la imagen de un producto para poder verla en pantalla completa.
///
/// - Mantener presionado siempre la abre (sirve en cards cuyo toque ya
///   lleva al detalle del producto).
/// - Con [abrirAlTocar] también se abre con un toque simple.
class ZoomableImage extends StatelessWidget {
  const ZoomableImage({
    super.key,
    required this.url,
    required this.child,
    this.titulo,
    this.abrirAlTocar = false,
  });

  final String url;
  final String? titulo;
  final bool abrirAlTocar;
  final Widget child;

  void _abrir(BuildContext context) {
    HapticFeedback.selectionClick();
    abrirImagenCompleta(context, url, titulo: titulo);
  }

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) return child;

    return Semantics(
      image: true,
      onLongPressHint: 'Ver imagen en pantalla completa',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: abrirAlTocar ? () => _abrir(context) : null,
        onLongPress: () => _abrir(context),
        child: child,
      ),
    );
  }
}

class _ImagenCompletaPage extends StatefulWidget {
  const _ImagenCompletaPage({required this.url, this.titulo});

  final String url;
  final String? titulo;

  @override
  State<_ImagenCompletaPage> createState() => _ImagenCompletaPageState();
}

class _ImagenCompletaPageState extends State<_ImagenCompletaPage>
    with SingleTickerProviderStateMixin {
  static const double _zoomDobleToque = 2.5;

  final _transform = TransformationController();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Animation<Matrix4>? _zoomAnim;
  Offset _toque = Offset.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(() {
      if (_zoomAnim != null) _transform.value = _zoomAnim!.value;
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _dobleToque() {
    final actual = _transform.value;
    final acercado = actual.getMaxScaleOnAxis() > 1.01;

    final Matrix4 destino;
    if (acercado) {
      destino = Matrix4.identity();
    } else {
      // Acerca centrando el punto tocado.
      final p = _toque;
      destino = Matrix4.identity()
        ..translateByDouble(
          -p.dx * (_zoomDobleToque - 1),
          -p.dy * (_zoomDobleToque - 1),
          0,
          1,
        )
        ..scaleByDouble(_zoomDobleToque, _zoomDobleToque, 1, 1);
    }

    _zoomAnim = Matrix4Tween(
      begin: actual,
      end: destino,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final titulo = (widget.titulo ?? '').trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              onDoubleTapDown: (d) => _toque = d.localPosition,
              onDoubleTap: _dobleToque,
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  // Ocupa todo el espacio disponible: la imagen completa se
                  // ajusta al ancho o alto de la pantalla, sin recortarse.
                  child: Image.network(
                    widget.url,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                    errorBuilder: (_, __, ___) => const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No se pudo cargar la imagen',
                            style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Barra superior: nombre del producto + cerrar. Va posicionada
          // para que el Stack ocupe toda la pantalla y no tome su altura.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                      ),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'Pellizca o toca dos veces para hacer zoom',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
