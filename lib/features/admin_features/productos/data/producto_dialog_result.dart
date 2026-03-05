

import 'package:quimisol_movil/features/admin_features/productos/data/form_result.dart';

class DescuentoDraft {
  final String tipo; // "PORCENTAJE" | "MONTO"
  final double valor;

  const DescuentoDraft({required this.tipo, required this.valor});

  bool get isValid => valor > 0;
}

/// Resultado del diálogo:
/// - producto: datos del producto
/// - descuento: opcional (null si NO)
/// - promoBannerEnabled: si debe activarse el banner en Firestore
class ProductoDialogResult {
  final ProductoFormResult producto;
  final DescuentoDraft? descuento;

  // ✅ NUEVO
  final bool promoBannerEnabled;

  const ProductoDialogResult({
    required this.producto,
    required this.descuento,
    this.promoBannerEnabled = false, // ✅ default para no romper nada
  });
}
