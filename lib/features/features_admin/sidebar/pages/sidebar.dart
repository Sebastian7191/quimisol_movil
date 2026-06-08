// lib/features/shell/sidebar_shell_page.dart
//
// ✅ Responsive:
// - Desktop: sidebar por hover
// - Mobile: sidebar overlay (drawer) con botón ☰ y scrim
// ✅ Incluye chat footer global para admin
// ✅ Nuevo módulo: Laboratorios
// ✅ Nuevo módulo: Pagos

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/almacenes/views/almacenes.dart';
import 'package:quimisol_movil/features/features_admin/banners/views/banners.dart';
import 'package:quimisol_movil/features/features_admin/categorias/views/categorias.dart';
import 'package:quimisol_movil/features/features_admin/home/views/dashboard_page.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/pages/lista_laboratorios.dart';
import 'package:quimisol_movil/features/features_admin/pagos/pages/pagos.dart';
import 'package:quimisol_movil/features/features_admin/pedidos/views/pedidos.dart';
import 'package:quimisol_movil/features/features_admin/productos/views/productos.dart';
import 'package:quimisol_movil/features/features_admin/soporte/pages/admin_chat_footer_panel.dart';
import 'package:quimisol_movil/features/features_admin/unidades/views/unidades.dart';
import 'package:quimisol_movil/features/features_admin/usuarios/views/usuarios.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

class SidebarShellPage extends StatefulWidget {
  const SidebarShellPage({super.key});

  @override
  State<SidebarShellPage> createState() => _SidebarShellPageState();
}

class _SidebarShellPageState extends State<SidebarShellPage> {
  int _currentIndex = 0;

  bool _sidebarOpen = false;
  bool _hoveringSidebar = false;
  bool _hoveringTrigger = false;
  bool _isSuperAdmin = false;
  bool _loadingRole = true;

  Timer? _closeTimer;

  Color get _main => Palette.button;
  Color get _accent => Palette.primary;

  List<_SideItem> get _items {
    final baseItems = <_SideItem>[
      const _SideItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/admin/dashboard',
      ),
      const _SideItem(
        icon: Icons.people_alt_rounded,
        label: 'Usuarios',
        route: '/admin/usuarios',
      ),
    ];

    if (_isSuperAdmin) {
      baseItems.add(
        const _SideItem(
          icon: Icons.warehouse_rounded,
          label: 'Almacenes',
          route: '/admin/almacenes',
        ),
      );
    }

    baseItems.addAll([
      const _SideItem(
        icon: Icons.inventory_2_rounded,
        label: 'Productos',
        route: '/admin/productos',
      ),
      const _SideItem(
        icon: Icons.straighten_rounded,
        label: 'Unidades',
        route: '/admin/unidades',
      ),
      const _SideItem(
        icon: Icons.category_rounded,
        label: 'Categorías',
        route: '/admin/categorias',
      ),
      const _SideItem(
        icon: Icons.campaign_rounded,
        label: 'Banners',
        route: '/admin/banners',
      ),
      const _SideItem(
        icon: Icons.science_rounded,
        label: 'Laboratorios',
        route: '/admin/laboratorios',
      ),
      const _SideItem(
        icon: Icons.receipt_long_rounded,
        label: 'Pedidos',
        route: '/admin/pedidos',
      ),
    ]);

    if (_isSuperAdmin) {
      baseItems.add(
        const _SideItem(
          icon: Icons.payments_rounded,
          label: 'Pagos',
          route: '/admin/pagos',
        ),
      );
    }

    return baseItems;
  }

  List<Widget> get _pages {
    final basePages = <Widget>[
      const DashboardPage(),
      const UsuariosPage(),
    ];

    if (_isSuperAdmin) {
      basePages.add(const AlmacenesPage());
    }

    basePages.addAll([
      const ProductosPage(),
      const UnidadesPage(),
      const CategoriasPage(),
      const BannersPage(),
      const LaboratoriosPage(),
      const PedidosPage(),
    ]);

    if (_isSuperAdmin) {
      basePages.add(const PagosPage());
    }

    return basePages;
  }

  void _cancelCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _openSidebar() {
    _cancelCloseTimer();
    if (!_sidebarOpen) setState(() => _sidebarOpen = true);
  }

  void _closeSidebar() {
    _cancelCloseTimer();
    if (_sidebarOpen) setState(() => _sidebarOpen = false);
  }

  void _toggleSidebar() {
    if (_sidebarOpen) {
      _closeSidebar();
    } else {
      _openSidebar();
    }
  }

  void _scheduleClose() {
    _cancelCloseTimer();
    _closeTimer = Timer(const Duration(milliseconds: 160), () {
      final keepOpen = _hoveringSidebar || _hoveringTrigger;
      if (!keepOpen && mounted) {
        setState(() => _sidebarOpen = false);
      }
    });
  }

  int _indexFromPath(String path) {
    final items = _items;
    for (int i = 0; i < items.length; i++) {
      if (path.startsWith(items[i].route)) return i;
    }
    return 0;
  }

  void _syncIndexWithPath(String path) {
    final idx = _indexFromPath(path);
    if (idx != _currentIndex && mounted) {
      setState(() => _currentIndex = idx);
    }
  }

  void _goTo(int index) {
    final items = _items;
    if (index < 0 || index >= items.length) return;

    setState(() => _currentIndex = index);
    Modular.to.navigate(items[index].route);
  }

  Future<void> _loadRole() async {
    try {
      final auth = Modular.get<AuthService>();
      final role = await auth.getUserRole();

      if (!mounted) return;

      setState(() {
        _isSuperAdmin = role == 'superadmin';
        _loadingRole = false;
      });

      final currentPath = Modular.to.path;
      _syncIndexWithPath(currentPath);

      final allowedRoutes = _items.map((e) => e.route).toList();
      final isAllowed = allowedRoutes.any((route) => currentPath.startsWith(route));

      if (!isAllowed) {
        Modular.to.navigate('/admin/dashboard');
        _syncIndexWithPath('/admin/dashboard');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSuperAdmin = false;
        _loadingRole = false;
      });
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Cerrar sesión',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text('¿Seguro que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Salir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.button,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final auth = Modular.get<AuthService>();
      await auth.logout();

      if (!mounted) return;
      Modular.to.navigate('/auth/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cerrar sesión: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();

    _loadRole();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = Modular.to.path;

      if (p == '/' || p.isEmpty || p == '/admin' || p == '/admin/') {
        Modular.to.navigate('/admin/dashboard');
        _syncIndexWithPath('/admin/dashboard');
      } else {
        _syncIndexWithPath(p);
      }
    });

    Modular.to.addListener(() {
      if (!mounted || _loadingRole) return;
      _syncIndexWithPath(Modular.to.path);
    });
  }

  @override
  void dispose() {
    _cancelCloseTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return const Scaffold(
        backgroundColor: Palette.fieldBg,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final pages = _pages;
    if (_currentIndex >= pages.length) {
      _currentIndex = 0;
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final isMobile = w < 900;

        final double mobileSidebarW =
            math.min(288.0, (w * 0.82)).clamp(240.0, 320.0);

        final body = Stack(
          children: [
            Positioned.fill(
              child: Padding(
                // ✅ En móvil dejamos espacio arriba para que el botón ☰
                // flotante (top: 10, ~42px) no tape el header de la página.
                padding: isMobile
                    ? const EdgeInsets.fromLTRB(10, 64, 10, 10)
                    : const EdgeInsets.all(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    color: Palette.white,
                    child: pages[_currentIndex],
                  ),
                ),
              ),
            ),
            Positioned(
              left: isMobile ? 10 : 18,
              bottom: isMobile ? 30 : 16,
              child: const AdminChatFooterPanel(),
            ),
          ],
        );

        if (isMobile) {
          return Scaffold(
            backgroundColor: Palette.fieldBg,
            body: SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: body),

                  Positioned(
                    top: 10,
                    left: 10,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _toggleSidebar,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Palette.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _main.withValues(alpha: 0.35),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            _sidebarOpen
                                ? Icons.close_rounded
                                : Icons.menu_rounded,
                            color: Palette.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (_sidebarOpen)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _closeSidebar,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.25),
                        ),
                      ),
                    ),

                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    top: 0,
                    bottom: 0,
                    left: _sidebarOpen ? 0 : -mobileSidebarW - 10,
                    child: Material(
                      color: Colors.transparent,
                      child: _Sidebar(
                        isOpen: true,
                        currentIndex: _currentIndex,
                        items: _items,
                        mainColor: _main,
                        accentColor: _accent,
                        onChanged: (i) {
                          _goTo(i);
                          _closeSidebar();
                        },
                        onLogout: _logout,
                        openWidth: mobileSidebarW,
                        closedWidth: 86,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Palette.fieldBg,
          body: Row(
            children: [
              MouseRegion(
                onEnter: (_) {
                  _hoveringTrigger = true;
                  _openSidebar();
                },
                onExit: (_) {
                  _hoveringTrigger = false;
                  _scheduleClose();
                },
                child: const SizedBox(width: 6, height: double.infinity),
              ),
              MouseRegion(
                onEnter: (_) {
                  _hoveringSidebar = true;
                  _openSidebar();
                },
                onExit: (_) {
                  _hoveringSidebar = false;
                  _scheduleClose();
                },
                child: _Sidebar(
                  isOpen: _sidebarOpen,
                  currentIndex: _currentIndex,
                  items: _items,
                  mainColor: _main,
                  accentColor: _accent,
                  onChanged: _goTo,
                  onLogout: _logout,
                  openWidth: 288,
                  closedWidth: 86,
                ),
              ),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}

class _SideItem {
  final IconData icon;
  final String label;
  final String route;

  const _SideItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _Sidebar extends StatelessWidget {
  final bool isOpen;
  final int currentIndex;
  final List<_SideItem> items;
  final Color mainColor;
  final Color accentColor;
  final ValueChanged<int> onChanged;
  final VoidCallback onLogout;
  final double openWidth;
  final double closedWidth;

  const _Sidebar({
    required this.isOpen,
    required this.currentIndex,
    required this.items,
    required this.mainColor,
    required this.accentColor,
    required this.onChanged,
    required this.onLogout,
    required this.openWidth,
    required this.closedWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isOpen ? openWidth : closedWidth,
      decoration: BoxDecoration(
        color: Palette.white,
        border: Border(
          right: BorderSide(
            color: mainColor.withValues(alpha: 0.55),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _SidebarHeader(
            open: isOpen,
            mainColor: mainColor,
            accentColor: accentColor,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final selected = i == currentIndex;
                return _SidebarItemTile(
                  open: isOpen,
                  selected: selected,
                  icon: items[i].icon,
                  label: items[i].label,
                  mainColor: mainColor,
                  onTap: () => onChanged(i),
                );
              },
            ),
          ),
          _LogoutTile(
            open: isOpen,
            onTap: onLogout,
          ),
          _SidebarFooter(open: isOpen),
        ],
      ),
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  final bool open;
  final Color mainColor;
  final Color accentColor;

  const _SidebarHeader({
    required this.open,
    required this.mainColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            mainColor.withValues(alpha: 0.95),
            Palette.secondary.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Palette.white,
            child: Icon(Icons.business_rounded, color: accentColor),
          ),
          if (open) ...[
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quimisol Admin',
                    style: TextStyle(
                      color: Palette.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Panel de control',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Icon(
            open ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: Palette.white.withValues(alpha: 0.9),
          ),
        ],
      ),
    );
  }
}

class _SidebarItemTile extends StatelessWidget {
  final bool open;
  final bool selected;
  final IconData icon;
  final String label;
  final Color mainColor;
  final VoidCallback onTap;

  const _SidebarItemTile({
    required this.open,
    required this.selected,
    required this.icon,
    required this.label,
    required this.mainColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? mainColor.withValues(alpha: 0.22) : Colors.transparent;
    final iconColor = selected ? Palette.primary : Palette.ink;
    final textColor = selected ? Palette.primary : Palette.ink;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? mainColor.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: open ? 14 : 10,
            vertical: 12,
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              if (open) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight:
                          selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoutTile extends StatelessWidget {
  final bool open;
  final VoidCallback onTap;

  const _LogoutTile({
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.22),
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: open ? 14 : 10,
              vertical: 12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: Colors.red.shade600,
                  size: 21,
                ),
                if (open) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  final bool open;

  const _SidebarFooter({required this.open});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Palette.ink.withValues(alpha: 0.8),
          ),
          if (open) ...[
            const SizedBox(width: 8),
            Text(
              'Admin',
              style: TextStyle(
                fontSize: 12,
                color: Palette.ink.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}