class NewAlmacenFormResult {
  final String nombre;
  final String departamento;
  final String descripcion;
  final String ubicacion;

  NewAlmacenFormResult({
    required this.nombre,
    required this.departamento,
    required this.descripcion,
    this.ubicacion = '',
  });
}