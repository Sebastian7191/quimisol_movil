import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

// ✅ Locales (para DateFormat con 'es_BO' y DatePicker/TimePicker en español)
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app_module.dart';
import 'app_widget.dart';
import 'firebase_options.dart';

// ⚠️ Mapbox: IMPORTA SOLO si vas a usarlo (móvil). En web está causando crash.
// Si lo dejas importado no pasa nada siempre, pero la llamada sí rompe.
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// ─────────────────────────────────────────────────────────────
// Canal de notificaciones Android (debe coincidir con el que
// declaramos en AndroidManifest.xml y en el que envían las
// Cloud Functions con androidChannelId).
// ─────────────────────────────────────────────────────────────
const AndroidNotificationChannel _channel = AndroidNotificationChannel(
  'quimisol_general',
  'Notificaciones Quimisol',
  description: 'Pedidos, pagos y actualizaciones de Quimisol',
  importance: Importance.high,
  playSound: true,
);

// ✅ Debe coincidir con `androidChannelId: "support_chat_channel"` que usa
// la Cloud Function `notificarMensajeSoporte`. Si este canal no existe en
// el dispositivo, Android descarta la notificación en silencio cuando la
// app está en segundo plano o cerrada.
const AndroidNotificationChannel _supportChatChannel = AndroidNotificationChannel(
  'support_chat_channel',
  'Chat de soporte',
  description: 'Mensajes nuevos del chat de soporte',
  importance: Importance.high,
  playSound: true,
);

// ✅ Debe coincidir con `androidChannelId: "orders_channel"` que usan
// notificarNuevoPedido, notificarPedidoEntregado, notificarCambioEstadoPago
// y notificarConductorAsignado. Igual que arriba: si no se crea aquí,
// Android descarta esas notificaciones en segundo plano (faltaba este canal).
const AndroidNotificationChannel _ordersChannel = AndroidNotificationChannel(
  'orders_channel',
  'Pedidos',
  description: 'Pedidos nuevos, entregas, pagos y asignaciones',
  importance: Importance.high,
  playSound: true,
);

// ✅ Debe coincidir con `androidChannelId: "reminders_channel"` que usan
// recordatorioPedidosPendientes y recordatorioStockBajo (Cloud Functions
// programadas con onSchedule).
const AndroidNotificationChannel _remindersChannel = AndroidNotificationChannel(
  'reminders_channel',
  'Recordatorios',
  description: 'Recordatorios automáticos de gestión (pedidos, inventario)',
  importance: Importance.high,
  playSound: true,
);

// ✅ Elige el canal según el `type` que mandan las Cloud Functions, para
// que cada notificación caiga en el canal correcto tanto en primer plano
// (aquí) como en segundo plano (lo decide el `androidChannelId` del push).
AndroidNotificationChannel _channelForType(String type) {
  if (type == 'support_chat') return _supportChatChannel;
  if (type.startsWith('recordatorio_') || type.startsWith('alerta_')) {
    return _remindersChannel;
  }
  if (type == 'nuevo_pedido_pendiente' || type.startsWith('pedido_')) {
    return _ordersChannel;
  }
  return _channel;
}

final FlutterLocalNotificationsPlugin _localNotifs =
    FlutterLocalNotificationsPlugin();

// ─────────────────────────────────────────────────────────────
// Handler de fondo: se ejecuta cuando la app está cerrada o en
// segundo plano. DEBE ser una función top-level (no un método).
// ─────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // El sistema Android/iOS muestra la notificación automáticamente.
  // Aquí puedes guardar datos o actualizar Firestore si necesitas.
}

// ─────────────────────────────────────────────────────────────
// Configuración de notificaciones locales + foreground handler
// ─────────────────────────────────────────────────────────────
Future<void> _setupNotifications() async {
  // iOS: mostrar notificaciones cuando la app está en primer plano
  await FirebaseMessaging.instance
      .setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  // Android: crear canales de notificaciones (requerido Android 8+)
  final androidNotifs = _localNotifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidNotifs?.createNotificationChannel(_channel);
  await androidNotifs?.createNotificationChannel(_supportChatChannel);
  await androidNotifs?.createNotificationChannel(_ordersChannel);
  await androidNotifs?.createNotificationChannel(_remindersChannel);

  // Inicializar flutter_local_notifications
  await _localNotifs.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  // Mostrar notificación local cuando la app está en PRIMER PLANO
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // ✅ Elegir canal según el tipo (mismo criterio que `androidChannelId`
    // en las Cloud Functions), para que coincida con lo que se ve en
    // segundo plano.
    final channel = _channelForType((message.data['type'] ?? '').toString());

    _localNotifs.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Registrar handler de fondo ANTES de initializeApp
  FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

  // ✅ Inicializa Firebase (con opciones por plataforma)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Configurar notificaciones locales + foreground
  await _setupNotifications();

  // ✅ Inicializa datos de locale para Intl (evita LocaleDataException)
  await initializeDateFormatting('es_BO', null);
  Intl.defaultLocale = 'es_BO';

  // ✅ Mapbox token (SOLO móvil/desktop nativo, NO web)
  if (!kIsWeb) {
    MapboxOptions.setAccessToken("TOKEN_MAPBOX");
  }

  // ✅ Fullscreen (mejor solo en móvil; en web no aplica)
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );

    // ✅ Bloqueamos la app en vertical (evita desbordes de layout en
    // horizontal). Solo móvil/desktop nativo, en web no aplica.
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(
    ModularApp(
      module: AppModule(),
      child: const AppWidget(),
    ),
  );
}
