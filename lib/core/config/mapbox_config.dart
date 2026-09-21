/// Token de acceso de Mapbox.
///
/// No se guarda en el código: se inyecta al compilar para que no termine
/// publicado en el repositorio. Hay dos formas de pasarlo:
///
///   flutter run --dart-define=MAPBOX_TOKEN=pk.xxxxx
///   flutter build apk --release --dart-define-from-file=env.json
///
/// donde `env.json` (ignorado por git) contiene:
///   { "MAPBOX_TOKEN": "pk.xxxxx" }
///
/// Si no se pasa, [accessToken] queda vacío y los mapas no cargan; por eso
/// [estaConfigurado] permite avisarlo en vez de fallar en silencio.
class MapboxConfig {
  const MapboxConfig._();

  static const String accessToken = String.fromEnvironment('MAPBOX_TOKEN');

  static bool get estaConfigurado => accessToken.isNotEmpty;
}
