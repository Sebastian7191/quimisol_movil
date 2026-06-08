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

  // Android: crear canal de notificaciones (requerido Android 8+)
  await _localNotifs
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);

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

    _localNotifs.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
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
  }

  runApp(
    ModularApp(
      module: AppModule(),
      child: const AppWidget(),
    ),
  );
}
