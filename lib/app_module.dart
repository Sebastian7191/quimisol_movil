// lib/app_module.dart
import 'package:flutter_modular/flutter_modular.dart';

// === SERVICES ===
import 'package:quimisol_movil/core/firebase/firebase_auth_service.dart';
import 'package:quimisol_movil/features/conductores_features/navbar/pages/nav_bar_repartidores.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

// === STORES ===
import 'package:quimisol_movil/shared/stores/user_store.dart';

// === PAGES ===
import 'package:quimisol_movil/features/auth/pages/login_screen.dart';
import 'package:quimisol_movil/features/pasajeros_features/navbar/pages/nav_bar_pasajeros.dart';
import 'package:quimisol_movil/features/splash/pages/splashscreen.dart';

class AppModule extends Module {
  @override
  void binds(Injector i) {
    // Auth
    i.addSingleton<AuthService>(FirebaseAuthService.new);

    // User global (escucha FirebaseAuth + Firestore)
    i.addSingleton<UserStore>(UserStore.new);
  }

  @override
  void routes(RouteManager r) {
    // 🔵 Splash → decide navegación
    r.child('/', child: (_) => const SplashPage());

    // 🔐 Login
    r.child('/login', child: (_) => const LoginScreen());

    // 🚕 Home pasajero
    r.child('/home-pasajero', child: (_) => const Navbar());

    // 🚖 Home conductor
    r.child('/home-conductor', child: (_) => const NavBarRepartidores());
  }
}
