import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/features/conductores_features/navbar/pages/nav_bar_repartidores.dart';

class ConductoresModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const NavBarRepartidores());
  }
}
