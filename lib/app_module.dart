import 'package:flutter_modular/flutter_modular.dart';

// === SERVICES ===
import 'package:quimisol_movil/core/firebase/firebase_auth_service.dart';
import 'package:quimisol_movil/core/services/session/session_service.dart';
import 'package:quimisol_movil/features/features_admin/sidebar/pages/sidebar.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

// === STORES ===
import 'package:quimisol_movil/shared/stores/user_store.dart';

// === PAGES (AUTH / APP) ===
import 'package:quimisol_movil/features/splash/pages/splashscreen.dart';
import 'package:quimisol_movil/features/auth/pages/login_screen.dart';
import 'package:quimisol_movil/features/auth/pages/completar_perfil.dart';

// === NAVBARS ===
import 'package:quimisol_movil/features/pasajeros_features/navbar/pages/nav_bar_pasajeros.dart';
import 'package:quimisol_movil/features/conductores_features/navbar/pages/nav_bar_repartidores.dart';

class AppModule extends Module {
  @override
  void binds(Injector i) {
    // 🔐 Session
    i.addSingleton<SessionService>(SessionService.new);

    // 🔐 Auth (depende de SessionService)
    i.addSingleton<AuthService>(
      () => FirebaseAuthService(i.get<SessionService>()),
    );

    // 👤 User global (depende de SessionService)
    i.addSingleton<UserStore>(
      () => UserStore(i.get<SessionService>()),
    );
  }

  @override
  void routes(RouteManager r) {
    // 🔵 Splash (decide todo)
    r.child('/', child: (_) => const SplashPage());

    // 🔐 Login
    r.child('/login', child: (_) => const LoginScreen());

    // 🧩 Completar perfil (PRIMERA VEZ GOOGLE)
    r.child('/perfil-completar', child: (_) => const PerfilCompletarPage());

    // 🚕 Home pasajero
    r.child('/home-pasajero', child: (_) => const Navbar());

    // 🚖 Home conductor (repartidor)
    r.child('/home-conductor', child: (_) => const NavBarRepartidores());

    // ==========================
    // ✅ ADMIN (Shell Sidebar)
    // ==========================
    r.child('/admin', child: (_) => const SidebarShellPage());
    r.child('/dashboard', child: (_) => const SidebarShellPage());
    r.child('/usuarios', child: (_) => const SidebarShellPage());
    r.child('/almacenes', child: (_) => const SidebarShellPage());
    r.child('/productos', child: (_) => const SidebarShellPage());
    r.child('/unidades', child: (_) => const SidebarShellPage());

    r.child('/almacenes/:id', child: (_) => const SidebarShellPage());
  }
}
