import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Singleton ligero para mostrar notificaciones locales desde cualquier parte
/// de la app. Se inicializa en modo idempotente (la primera llamada al plugin
/// siempre es segura aunque main.dart ya lo haya inicializado).
class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );
    _ready = true;
  }

  Future<void> showPaymentRejected({required String pedidoCode}) async {
    await _ensureReady();
    await _plugin.show(
      pedidoCode.hashCode.abs(),
      'Pago rechazado',
      'El comprobante del pedido #$pedidoCode fue rechazado. '
          'Por favor, sube un nuevo comprobante.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'orders_channel',
          'Pedidos',
          channelDescription:
              'Pedidos nuevos, entregas, pagos y asignaciones',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
