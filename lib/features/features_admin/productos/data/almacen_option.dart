class AlmacenOption {
  final String id;
  final String nombre;
  final bool activo;

  const AlmacenOption({
    required this.id,
    required this.nombre,
    required this.activo,
  });

  String get label => nombre.trim().isEmpty ? id : nombre.trim();
}