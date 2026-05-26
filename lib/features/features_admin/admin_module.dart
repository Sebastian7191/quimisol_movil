import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/features/features_admin/sidebar/pages/sidebar.dart';

class AdminModule extends Module {
  @override
  void routes(RouteManager r) {
    r.child('/', child: (_) => const SidebarShellPage());
    r.child('/dashboard', child: (_) => const SidebarShellPage());
    r.child('/usuarios', child: (_) => const SidebarShellPage());
    r.child('/almacenes', child: (_) => const SidebarShellPage());
    r.child('/almacenes/:id', child: (_) => const SidebarShellPage());
    r.child('/productos', child: (_) => const SidebarShellPage());
    r.child('/unidades', child: (_) => const SidebarShellPage());
    r.child('/categorias', child: (_) => const SidebarShellPage());
    r.child('/banners', child: (_) => const SidebarShellPage());
    r.child('/laboratorios', child: (_) => const SidebarShellPage());
    r.child('/pedidos', child: (_) => const SidebarShellPage());
    r.child('/pagos', child: (_) => const SidebarShellPage());
  }
}
