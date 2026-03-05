class PedidoItemData {
  final String nombre;
  final String imageUrl;
  final int cantidad;
  final double precio;

  PedidoItemData({
    required this.nombre,
    required this.imageUrl,
    required this.cantidad,
    required this.precio,
  });

  double get subtotal => cantidad * precio;

  factory PedidoItemData.fromMap(Map<String, dynamic> map) {
    return PedidoItemData(
      nombre: (map['name'] ?? map['nombre'] ?? '—').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      cantidad: _asInt(map['qty'] ?? map['cantidad'], fallback: 1),
      precio: _asDouble(map['price'] ?? map['precio']),
    );
  }
}

// helpers locales 
double _asDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _asInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? fallback;
}
