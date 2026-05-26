import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/features/splash/pages/splashscreen.dart';

class SplashModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const SplashPage());
  }
}
