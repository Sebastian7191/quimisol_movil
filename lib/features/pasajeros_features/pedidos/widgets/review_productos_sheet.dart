// lib/features/pasajeros_features/pedidos/widgets/review_productos_sheet.dart

import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/pedidos/widgets/rating_stars.dart';

class ReviewProductosSheet extends StatefulWidget {
  final List<Map<String, dynamic>> items;

  const ReviewProductosSheet({
    super.key,
    required this.items,
  });

  @override
  State<ReviewProductosSheet> createState() => _ReviewProductosSheetState();
}

class _ReviewProductosSheetState extends State<ReviewProductosSheet> {
  late List<int> ratings;
  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    ratings = List.generate(widget.items.length, (_) => 5);
    controllers =
        List.generate(widget.items.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  String _nameOf(Map<String, dynamic> item) {
    return (item['name'] ??
            item['nombre'] ??
            item['productName'] ??
            'Producto')
        .toString()
        .trim();
  }

  String _imageOf(Map<String, dynamic> item) {
    return (item['imageUrl'] ??
            item['imagenUrl'] ??
            item['urlImagen'] ??
            '')
        .toString()
        .trim();
  }

  int _qtyOf(Map<String, dynamic> item) {
    final v = item['qty'] ?? item['cantidad'] ?? 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
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
              'Califica tus productos',
              style: TextStyle(
                color: Palette.primary,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuéntanos qué tal te parecieron los productos que compraste.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Palette.ink.withOpacity(0.72),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) {
                  final item = widget.items[i];
                  final name = _nameOf(item);
                  final imageUrl = _imageOf(item);
                  final qty = _qtyOf(item);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Palette.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Palette.primary.withOpacity(0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ProductoThumb(imageUrl: imageUrl),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name.isNotEmpty ? name : 'Producto',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Palette.primary,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Cantidad comprada: $qty',
                                    style: TextStyle(
                                      color: Palette.ink.withOpacity(0.65),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: RatingStars(
                            value: ratings[i],
                            onChanged: (v) => setState(() => ratings[i] = v),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: controllers[i],
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Reseña opcional del producto...',
                            filled: true,
                            fillColor: Palette.fieldBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Palette.primary.withOpacity(0.10),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Palette.primary.withOpacity(0.10),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Palette.button),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final result = <Map<String, dynamic>>[];

                  for (int i = 0; i < widget.items.length; i++) {
                    result.add({
                      ...widget.items[i],
                      'rating': ratings[i],
                      'comentario': controllers[i].text.trim(),
                    });
                  }

                  Navigator.pop(context, result);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Palette.button,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Guardar calificaciones',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductoThumb extends StatelessWidget {
  final String imageUrl;

  const _ProductoThumb({
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;

    if (!hasImage) {
      return _placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        height: 64,
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: 64,
              height: 64,
              color: Palette.fieldBg,
              alignment: Alignment.center,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Palette.button,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Palette.primary.withOpacity(0.08),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        color: Palette.primary.withOpacity(0.75),
        size: 28,
      ),
    );
  }
}