class AlmacenRow {
  final String id;
  final String nombre;
  final String departamento;

  const AlmacenRow({
    required this.id,
    required this.nombre,
    required this.departamento,
  });

  factory AlmacenRow.fromFirestore(String id, Map<String, dynamic> data) {
    return AlmacenRow(
      id: id,
      nombre: (data['nombre'] ?? '—').toString(),
      departamento: (data['departamento'] ?? '').toString(),
    );
  }
}