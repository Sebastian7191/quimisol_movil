import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/features/pasajeros_features/navbar/pages/nav_bar_pasajeros.dart';

class PasajerosModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const Navbar());
  }
}
