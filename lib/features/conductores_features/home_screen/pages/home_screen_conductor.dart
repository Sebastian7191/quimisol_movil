// lib/features/conductores_features/home_screen/pages/home_screen_conductor.dart

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/stores/user_store.dart';
import 'package:quimisol_movil/shared/models/app_user.dart';

// TABS
import 'package:quimisol_movil/features/conductores_features/viajes/pages/conductor_viaje_page.dart';
import 'package:quimisol_movil/features/conductores_features/rendimiento/pages/conductor_rendimiento_page.dart';
import 'package:quimisol_movil/features/conductores_features/billetera/pages/conductor_billetera_page.dart';

class HomeScreenConductor extends StatefulWidget {
  const HomeScreenConductor({super.key});

  @override
  State<HomeScreenConductor> createState() => _HomeScreenConductorState();
}

class _HomeScreenConductorState extends State<HomeScreenConductor> {
  int _currentIndex = 0;
  bool _isOnline = false;

  late final AuthService _authService;
  late final UserStore _userStore;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
    _userStore = Modular.get<UserStore>();
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (!mounted) return;
    Modular.to.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0A2E73);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),

      // ===========================
      //         DRAWER LATERAL
      // ===========================
      drawer: _buildDrawer(),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,

        // ABRIR MENU LATERAL
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.black87),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),

        // SLIDE SWITCH
        title: _StatusSwitch(
          isOnline: _isOnline,
          onChanged: (value) {
            setState(() => _isOnline = value);
            // Aquí puedes sincronizar con firestore si quieres
          },
        ),

        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.black87),
            onPressed: () {
              // Opciones / Filtros
            },
          ),
        ],
      ),

      // ===========================
      //          TABS
      // ===========================
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          ConductorTripsPage(),
          ConductorRendimientoPage(),
          ConductorBilleteraPage(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list_rounded),
            label: 'Viajes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            label: 'Rendimiento',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Billetera',
          ),
        ],
      ),
    );
  }

  // ======================================
  //               DRAWER
  // ======================================
  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
        child: ValueListenableBuilder<AppUser?>(
          valueListenable: _userStore.user,
          builder: (context, user, _) {
            final name = user?.name ?? 'Conductor';
            final email = user?.email ?? '—';
            final photo = user?.photo;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HEADER
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(color: Color(0xFF0A2E73)),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: Colors.white,
                        backgroundImage: photo != null
                            ? NetworkImage(photo)
                            : null,
                        child: photo == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // LISTA DE OPCIONES
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.local_taxi_rounded),
                        title: const Text("Mis Viajes"),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentIndex = 0);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.show_chart_rounded),
                        title: const Text("Rendimiento"),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentIndex = 1);
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.account_balance_wallet_rounded,
                        ),
                        title: const Text("Billetera"),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() => _currentIndex = 2);
                        },
                      ),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.settings),
                        title: const Text("Configuración"),
                        onTap: () {},
                      ),
                      ListTile(
                        leading: const Icon(Icons.support_agent_rounded),
                        title: const Text("Soporte"),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),

                // LOGOUT
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red),
                  title: const Text(
                    "Cerrar sesión",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: _logout,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ======================================
/// SWITCH ANIMADO (Ocupado / Activo)
/// ======================================
class _StatusSwitch extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onChanged;

  const _StatusSwitch({required this.isOnline, required this.onChanged});

  static const _primaryBlue = Color(0xFF0A2E73);
  static const _accentGreen = Color(0xFF2E8B57);
  static const _accentRed = Color(0xFFC41F33);

  @override
  Widget build(BuildContext context) {
    const double totalWidth = 170;
    const double halfWidth = totalWidth / 2;

    return GestureDetector(
      onTap: () => onChanged(!isOnline),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        width: totalWidth,
        height: 34,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _primaryBlue.withOpacity(0.15), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: isOnline
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: halfWidth - 6,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: isOnline ? _accentGreen : _accentRed,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Ocupado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOnline
                            ? _primaryBlue.withOpacity(0.55)
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Activo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isOnline
                            ? Colors.white
                            : _primaryBlue.withOpacity(0.55),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
