import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_core/firebase_core.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Inicializa Firebase (con opciones por plataforma)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
