// lib/features/productos/data/descuento_draft.dart

class DescuentoDraft {
  final String tipo; // "PORCENTAJE" | "MONTO"
  final double valor;

  const DescuentoDraft({required this.tipo, required this.valor});

  bool get isValid => valor > 0;
}
