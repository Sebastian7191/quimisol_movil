import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/features/auth/pages/login_screen.dart';
import 'package:quimisol_movil/features/auth/pages/completar_perfil.dart';

class AuthModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child('/login', child: (_) => const LoginScreen());
    r.child('/perfil-completar', child: (_) => const PerfilCompletarPage());
  }
}
