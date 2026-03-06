// lib/features/pasajeros_features/pedidos/widgets/review_entrega_sheet.dart

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
          Container(
            width: 54,
            height: 6,
            decoration: BoxDecoration(
              color: Palette.ink.withOpacity(0.14),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 18),
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
              color: Palette.ink.withOpacity(0.72),
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
                borderSide: BorderSide(color: Palette.primary.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Palette.primary.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Palette.button),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
        ],
      ),
    );
  }
}