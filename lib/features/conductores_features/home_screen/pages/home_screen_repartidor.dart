// lib/features/conductores_features/home_screen/pages/home_screen_conductor.dart
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/pages/repartidor_viajes_page.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/pages/pedidos_mapa_page.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/services/repartidor_servicio_localizacion.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

class HomeScreenConductor extends StatefulWidget {
  const HomeScreenConductor({super.key});

  @override
  State<HomeScreenConductor> createState() => _HomeScreenConductorState();
}

class _HomeScreenConductorState extends State<HomeScreenConductor> {
  bool _isOnline = false;

  late final AuthService _authService;
  late final RepartidorLocationService _locationService;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
    _locationService = RepartidorLocationService();
  }

  @override
  void dispose() {
    _locationService.stop();
    super.dispose();
  }

  Future<void> _logout() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _locationService.clear(uid);
    }
    await _authService.logout();
    if (!mounted) return;
    Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
  }

  void _toggleOnline(bool v) async {
    setState(() => _isOnline = v);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (v) {
      await _locationService.start(uid: uid);
    } else {
      _locationService.stop();
    }
  }

  void _openPedidosMapa() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PedidosMapaPage()),
    );
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
        title: _StatusSwitch(
          isOnline: _isOnline,
          onChanged: _toggleOnline,
        ),
        actions: [
          IconButton(
            tooltip: 'Mapa de pedidos',
            icon: Icon(Icons.map_rounded, color: Palette.ink),
            onPressed: _openPedidosMapa,
          ),
          const SizedBox(width: 6),
        ],
      ),

      // ✅ OCUPADO: no muestra pedidos / ACTIVO: muestra cards
      body: _isOnline ? const RepartidorViajesPage() : const _OcupadoEmptyState(),
    );
  }
}

class _OcupadoEmptyState extends StatelessWidget {
  const _OcupadoEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.do_not_disturb_on_rounded,
              size: 64,
              color: Palette.ink.withOpacity(0.55),
            ),
            const SizedBox(height: 12),
            Text(
              'Estás en modo Ocupado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Palette.ink.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cambia a "Activo" para ver los pedidos disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Palette.ink.withOpacity(0.65),
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================================
/// 🔥 SWITCH BONITO (MINIMAL + PRO)
/// =======================================================
class _StatusSwitch extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onChanged;

  const _StatusSwitch({
    required this.isOnline,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isOnline),
      child: Container(
        width: 190,
        height: 36,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Palette.fieldBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: Palette.primary.withOpacity(0.2),
          ),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 92,
                decoration: BoxDecoration(
                  color: isOnline ? Palette.statsSuccess : Palette.statsDanger,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: !isOnline
                            ? Colors.white
                            : Palette.ink.withOpacity(0.6),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Activo',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isOnline
                            ? Colors.white
                            : Palette.ink.withOpacity(0.6),
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
