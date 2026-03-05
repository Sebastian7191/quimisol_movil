import 'dart:typed_data';

class ProductoFormResult {
  final String codigo;
  final String nombre;
  final String descripcion;
  final String tipoItem;
  final String unidadId;
  final String unidadNombre;
  final double precio;
  final int stock;

  final Uint8List? imageBytes;
  final String? imageName;

  final String almacenId;
  final String almacenNombre;

  // ✅ NUEVO
  final String? categoriaId;
  final String? categoriaNombre;

  ProductoFormResult({
    required this.codigo,
    required this.nombre,
    required this.descripcion,
    required this.tipoItem,
    required this.unidadId,
    required this.unidadNombre,
    required this.precio,
    required this.stock,
    this.imageBytes,
    this.imageName,
    required this.almacenId,
    required this.almacenNombre,

    // ✅ NUEVO
    this.categoriaId,
    this.categoriaNombre,
  });
}
