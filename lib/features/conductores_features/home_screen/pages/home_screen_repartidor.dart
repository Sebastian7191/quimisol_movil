// lib/features/conductores_features/home_screen/pages/home_screen_conductor.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/pages/repartidor_viajes_page.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/widgets/resumen_dia_header.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/widgets/logout_dialog.dart';

class HomeScreenConductor extends StatefulWidget {
  const HomeScreenConductor({super.key});

  @override
  State<HomeScreenConductor> createState() => _HomeScreenConductorState();
}

class _HomeScreenConductorState extends State<HomeScreenConductor> {
  late final AuthService _authService;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
  }

  Future<void> _logout() async {
    final salio = await confirmarCerrarSesion(
      context,
      onLogout: () => _authService.logout(),
    );

    if (!salio || !mounted) return;
    Modular.to.navigate('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.fieldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Palette.gradientStart.withOpacity(0.45),
                Palette.gradientEnd.withOpacity(0.65),
              ],
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.logout_rounded, color: Palette.ink),
          onPressed: _logout,
        ),
        // Dos líneas (saludo + resumen): un poco más alto que el estándar.
        toolbarHeight: 66,
        title: const ResumenDiaHeader(),
      ),
      body: const RepartidorViajesPage(),
    );
  }
}
