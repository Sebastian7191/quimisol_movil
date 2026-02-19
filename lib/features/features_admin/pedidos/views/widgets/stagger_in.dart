import 'package:flutter/material.dart';

class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.child, required this.delayMs});
  final Widget child;
  final int delayMs;

  @override
  State<StaggerIn> createState() => StaggerInState();
}

class StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_c);

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}