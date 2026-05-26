import 'package:flutter_modular/flutter_modular.dart';

// === SERVICIOS GLOBALES ===
import 'package:quimisol_movil/core/firebase/firebase_auth_service.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

// === STORES GLOBALES ===
import 'package:quimisol_movil/shared/stores/user_store.dart';

// === SUB-MÓDULOS POR FEATURE ===
import 'package:quimisol_movil/features/splash/splash_module.dart';
import 'package:quimisol_movil/features/auth/auth_module.dart';
import 'package:quimisol_movil/features/features_admin/admin_module.dart';
import 'package:quimisol_movil/features/pasajeros_features/pasajeros_module.dart';
import 'package:quimisol_movil/features/conductores_features/conductores_module.dart';

class AppModule extends Module {
  @override
  void binds(Injector i) {
    // 🔐 Auth (global, usado por todos los módulos)
    i.addSingleton<AuthService>(FirebaseAuthService.new);

    // 👤 User global
    i.addSingleton<UserStore>(UserStore.new);
  }

  @override
  void routes(RouteManager r) {
    // 🔵 Splash en raíz: /
    r.module('/', module: SplashModule());

    // 🔐 Auth: /auth/login, /auth/perfil-completar
    r.module('/auth', module: AuthModule());

    // 🛠️ Admin: /admin, /admin/dashboard, /admin/usuarios, ...
    r.module('/admin', module: AdminModule());

    // 🚕 Pasajeros: /pasajero
    r.module('/pasajero', module: PasajerosModule());

    // 🚖 Conductores: /conductor
    r.module('/conductor', module: ConductoresModule());
  }
}
