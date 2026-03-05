class UnidadOption {
  final String id;
  final String nombre;
  final String abreviatura;

  const UnidadOption({
    required this.id,
    required this.nombre,
    required this.abreviatura,
  });

  String get label =>
      abreviatura.trim().isEmpty ? nombre : '$nombre ($abreviatura)';
}