class BannerFormResult {
  final String titulo;
  final String subtitulo;
  final String imagen;
  final String estado; // "ACTIVO" / "INACTIVO"
  final String idproducto;

  BannerFormResult({
    required this.titulo,
    required this.subtitulo,
    required this.imagen,
    required this.estado,
    required this.idproducto,
  });
}
