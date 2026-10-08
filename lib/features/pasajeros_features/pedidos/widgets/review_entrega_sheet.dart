import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/widgets/rating_stars.dart';

class ReviewEntregaSheet extends StatefulWidget {
  final String pedidoCode;

  const ReviewEntregaSheet({
    super.key,
    required this.pedidoCode,
  });

  @override
  State<ReviewEntregaSheet> createState() => _ReviewEntregaSheetState();
}

class _ReviewEntregaSheetState extends State<ReviewEntregaSheet> {
  int rating = 5;
  final comentarioCtrl = TextEditingController();

  @override
  void dispose() {
    comentarioCtrl.dispose();
    super.dispose();
  }

  void _skip() => Navigator.pop(context, {'skipped': true});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle + X
          Row(
            children: [
              const SizedBox(width: 40),
              Expanded(
                child: Center(
                  child: Container(
                    width: 54,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Palette.ink.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: Palette.ink.withValues(alpha: 0.45),
                    size: 22,
                  ),
                  onPressed: _skip,
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Califícanos',
            style: TextStyle(
              color: Palette.primary,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿Qué tal fue la entrega de tu pedido #${widget.pedidoCode}?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.72),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          RatingStars(
            value: rating,
            onChanged: (v) => setState(() => rating = v),
            size: 34,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: comentarioCtrl,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Descripción opcional por si hubo algún incidente...',
              filled: true,
              fillColor: Palette.fieldBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Palette.primary.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Palette.primary.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Palette.button),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'rating': rating,
                  'comentario': comentarioCtrl.text.trim(),
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.button,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Calificar entrega',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _skip,
            child: Text(
              'No, gracias',
              style: TextStyle(
                color: Palette.ink.withValues(alpha: 0.45),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
