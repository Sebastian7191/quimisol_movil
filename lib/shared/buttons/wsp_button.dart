import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WhatsAppButton extends StatefulWidget {
  /// Número de WhatsApp en formato internacional (sin + ni 00)
  final String phone;
  /// Mensaje inicial opcional
  final String message;
  /// Tamaño del ícono (por defecto 28)
  final double iconSize;
  /// Posición inferior/derecha
  final double bottom;
  final double right;

  const WhatsAppButton({
    super.key,
    this.phone = '59177961504', // 🇧🇴 ejemplo
    this.message = '¡Hola! Quiero más información.',
    this.iconSize = 28,
    this.bottom = 20,
    this.right = 20,
  });

  @override
  State<WhatsAppButton> createState() => _WhatsAppButtonState();
}

class _WhatsAppButtonState extends State<WhatsAppButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scaleAnimation = Tween(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openWhatsApp() async {
    final encodedMsg = Uri.encodeComponent(widget.message);
    final url = Uri.parse('https://wa.me/${widget.phone}?text=$encodedMsg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir WhatsApp')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: widget.bottom,
      right: widget.right,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: GestureDetector(
          onTap: _openWhatsApp,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(FontAwesomeIcons.whatsapp, color: Colors.white, size: widget.iconSize),
          ),
        ),
      ),
    );
  }
}
