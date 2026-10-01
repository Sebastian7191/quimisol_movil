/// Token de acceso de Mapbox.
///
/// Por defecto usa el token de `defaultValue`. Para usar otro sin tocar el
/// código, se puede inyectar al compilar:
///
///   flutter run --dart-define=MAPBOX_TOKEN=pk.xxxxx
///   flutter build apk --release --dart-define-from-file=env.json
///
/// donde `env.json` (ignorado por git) contiene:
///   { "MAPBOX_TOKEN": "pk.xxxxx" }
///
/// Si [accessToken] queda vacío los mapas no cargan; por eso
/// [estaConfigurado] permite avisarlo en vez de fallar en silencio.
class MapboxConfig {
  const MapboxConfig._();

  static const String accessToken = String.fromEnvironment(
    'MAPBOX_TOKEN',
    defaultValue: 'mapbox_token_aqui',
  );

  static bool get estaConfigurado => accessToken.isNotEmpty;
}
