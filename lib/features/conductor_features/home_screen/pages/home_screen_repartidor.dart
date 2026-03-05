// lib/features/conductores_features/home_screen/pages/home_screen_conductor.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductor_features/home_screen/pages/repartidor_viajes_page.dart';
import 'package:quimisol_movil/features/conductor_features/home_screen/pages/pedidos_mapa_page.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

class HomeScreenConductor extends StatefulWidget {
  const HomeScreenConductor({super.key});

  @override
  State<HomeScreenConductor> createState() => _HomeScreenConductorState();
}

class _HomeScreenConductorState extends State<HomeScreenConductor> {
  // ✅ Firestore: cambia esto si tu colección tiene otro nombre
  static const String kUsersCollection = 'usuarios';

  bool _isOnline = false;

  late final AuthService _authService;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _estadoSub;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();

    _bindEstadoFromFirestore();
  }

  @override
  void dispose() {
    _estadoSub?.cancel();
    super.dispose();
  }

  /// ================================
  /// 🔥 Firestore binding (escucha estado)
  /// ================================
  void _bindEstadoFromFirestore() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection(kUsersCollection)
        .doc(uid);

    _estadoSub?.cancel();
    _estadoSub = docRef.snapshots().listen((snap) {
      final data = snap.data();
      final estado = (data?['estado'] as bool?) ?? false;

      if (estado != _isOnline) {
        if (mounted) setState(() => _isOnline = estado);
      }
    }, onError: (_) {});
  }

  /// Set en Firestore: estado = true/false
  Future<void> _setEstadoInFirestore(bool v) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection(kUsersCollection)
        .doc(uid);

    await docRef.set(
      {
        'estado': v,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Cambia el estado: optimista + guarda en Firestore
  Future<void> _toggleOnline(bool v) async {
    setState(() => _isOnline = v);

    try {
      await _setEstadoInFirestore(v);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isOnline = !v);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar tu estado.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _logout() async {
    try {
      // ✅ Dejarlo ocupado al salir
      await _setEstadoInFirestore(false);
    } catch (_) {
      // Ignorar para no bloquear logout
    }

    await _authService.logout();
    if (!mounted) return;
    Modular.to.pushNamedAndRemoveUntil('/login', (_) => false);
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
                Palette.gradientStart.withValues(alpha: 0.45),
                Palette.gradientEnd.withValues(alpha: 0.65),
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
          onChanged: (v) => _toggleOnline(v),
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
              color: Palette.ink.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              'Estás en modo Ocupado',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Palette.ink.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Cambia a "Activo" para ver los pedidos disponibles.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Palette.ink.withValues(alpha: 0.65),
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
            color: Palette.primary.withValues(alpha: 0.2),
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
                      color: Colors.black.withValues(alpha: 0.18),
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
                            : Palette.ink.withValues(alpha: 0.6),
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
                            : Palette.ink.withValues(alpha: 0.6),
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
