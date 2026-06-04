import 'package:flutter/material.dart';
import '../../core/theme/palette.dart';

/// Botón principal con animación sutil de press y soporte de loading.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.height = 52,
    this.backgroundColor,
    this.foregroundColor = Colors.white,
    this.borderRadius = 30,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double height;
  final Color? backgroundColor;
  final Color foregroundColor;
  final double borderRadius;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 220),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDown(_) {
    if (widget.isLoading || widget.onPressed == null) return;
    _ctrl.forward();
  }

  void _onUp(_) {
    if (!_ctrl.isAnimating && _ctrl.value == 0) return;
    _ctrl.reverse();
  }

  void _onCancel() {
    _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.isLoading || widget.onPressed == null;
    final bg = widget.backgroundColor ?? Palette.secButton;
    final radius = BorderRadius.circular(widget.borderRadius);

    // Contenido (loader / icon + texto / texto)
    Widget child;
    if (widget.isLoading) {
      child = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(widget.foregroundColor),
        ),
      );
    } else {
      final textWidget = Text(
        widget.label,
        style: TextStyle(
          color: widget.foregroundColor,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          fontSize: 14.5,
        ),
      );

      if (widget.icon != null) {
        child = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: widget.foregroundColor, size: 19),
            const SizedBox(width: 10),
            textWidget,
          ],
        );
      } else {
        child = textWidget;
      }
    }

    return ScaleTransition(
      scale: _scale,
      child: Listener(
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: (_) => _onCancel(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: disabled ? bg.withValues(alpha: 0.55) : bg,
            borderRadius: radius,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: bg.withValues(alpha: 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: disabled ? null : widget.onPressed,
              borderRadius: radius,
              splashColor: Colors.white.withValues(alpha: 0.18),
              highlightColor: Colors.white.withValues(alpha: 0.08),
              child: Center(child: child),
            ),
          ),
        ),
      ),
    );
  }
}
