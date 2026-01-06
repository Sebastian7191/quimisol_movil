import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/pages/repartidor_viajes_page.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/services/repartidor_servicio_localizacion.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

class HomeScreenConductor extends StatefulWidget {
  const HomeScreenConductor({super.key});

  @override
  State<HomeScreenConductor> createState() => _HomeScreenConductorState();
}

class _HomeScreenConductorState extends State<HomeScreenConductor> {
  int _currentIndex = 0;
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

  String _titleForTab(int i) {
    switch (i) {
      case 0:
        return 'Viajes';
      case 1:
        return 'Rendimiento';
      case 2:
        return 'Billetera';
      default:
        return 'Conductor';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.fieldBg,

      // ✅ APPBAR OK
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
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
        title: Column(
          children: [
            Text(
              _titleForTab(_currentIndex),
              style: TextStyle(
                color: Palette.ink,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            _StatusSwitch(isOnline: _isOnline, onChanged: _toggleOnline),
          ],
        ),
      ),

      // ✅ ESTO ES LO QUE FALTABA
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          RepartidorViajesPage(), // 0 → VIAJES
          Center(child: Text('Rendimiento')),
          Center(child: Text('Billetera')),
        ],
      ),
    );
  }
}

class _StatusSwitch extends StatelessWidget {
  final bool isOnline;
  final ValueChanged<bool> onChanged;

  const _StatusSwitch({required this.isOnline, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!isOnline),
      child: Container(
        width: 170,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Palette.fieldBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Palette.primary.withOpacity(0.18)),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 220),
              alignment: isOnline
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                width: 82,
                decoration: BoxDecoration(
                  color: isOnline ? Palette.statsSuccess : Palette.statsDanger,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const Row(
              children: [
                Expanded(child: Center(child: Text('Ocupado'))),
                Expanded(child: Center(child: Text('Activo'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
