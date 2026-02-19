class ProductoRow {
  final String id;
  final String codigo;
  final String nombre;
  final String tipoItem;

  final String unidadId;
  final String unidadNombre;

  final String descripcion;
  final double precio;
  final int stock;

  final DateTime? createdAt;

  final String imagenUrl;
  final String imagenPath;

  final String almacenId;
  final String almacenNombre;

  // ✅ NUEVO: categoría
  final String categoriaId;
  final String categoriaNombre;

  ProductoRow({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.tipoItem,
    required this.unidadId,
    required this.unidadNombre,
    required this.descripcion,
    required this.precio,
    required this.stock,
    required this.createdAt,
    required this.imagenUrl,
    required this.imagenPath,
    required this.almacenId,
    required this.almacenNombre,

    // ✅ nuevos
    required this.categoriaId,
    required this.categoriaNombre,
  });
}
