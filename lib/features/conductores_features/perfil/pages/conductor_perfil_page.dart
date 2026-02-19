// lib/features/conductores_features/pages/conductor_profile_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/core/theme/palette.dart';

// ✅ IMPORTA TUS PAGES REALES
import 'package:quimisol_movil/features/conductores_features/historial/pages/historial_entregas_page.dart';
import 'package:quimisol_movil/features/conductores_features/notificaciones/pages/notificaciones_page.dart';

class ConductorProfilePage extends StatefulWidget {
  final Future<void> Function() onLogout;

  const ConductorProfilePage({super.key, required this.onLogout});

  @override
  State<ConductorProfilePage> createState() => _ConductorProfilePageState();
}

class _ConductorProfilePageState extends State<ConductorProfilePage> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
    return _fire.collection('usuarios').doc(_uid).snapshots();
  }

  String _firstName(String full) {
    final parts = full.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'Repartidor';
    return parts.first;
  }

  // ✅ YA NAVEGA A TUS PAGES REALES
  void _openHistorial() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HistorialEntregasPage()),
    );
  }

  void _openNotificaciones() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificacionesPage()),
    );
  }

  void _openVehiculo() => _toast('Abrir Mi vehículo (pendiente)');
  void _openDocumentos() => _toast('Abrir Documentos (pendiente)');
  void _openZona() => _toast('Abrir Zona de reparto (pendiente)');
  void _openGanancias() => _toast('Abrir Ganancias (pendiente)');
  void _openSoporte() => _toast('Abrir Soporte (pendiente)');
  void _openAjustes() => _toast('Abrir Ajustes (pendiente)');

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final pink = Palette.button;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _uid.isEmpty ? null : _userStream(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};

            final name = (data['name'] ?? 'Repartidor').toString();
            final email =
                (data['email'] ?? _auth.currentUser?.email ?? '').toString();
            final photo = (data['photo'] ?? '').toString();
            final role = (data['role'] ?? 'repartidor').toString();

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Hola + settings)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '¡Hola, ${_firstName(name)}!',
                          style: TextStyle(
                            color: ink,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      _SoftIconButton(
                        icon: Icons.settings_rounded,
                        onTap: _openAjustes,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Card usuario
                  _ProfileCard(
                    name: name,
                    email: email,
                    role: role,
                    photoUrl: photo,
                    onEdit: () {
                      _toast('Editar perfil (pendiente)');
                      // Si tienes pantalla de editar perfil:
                      // Modular.to.pushNamed('/perfil/editar');
                    },
                  ),

                  const SizedBox(height: 18),

                  // Accesos rápidos (repartidor)
                  Text(
                    'Accesos rápidos',
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final crossAxisCount = w < 360 ? 2 : 4;
                      const spacing = 12.0;
                      const tileHeight = 104.0;

                      return GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          mainAxisExtent: tileHeight,
                        ),
                        children: [
                          _QuickTile(
                            icon: Icons.history_rounded,
                            label: 'Historial\nde entregas',
                            color: pink,
                            onTap: _openHistorial,
                          ),
                          _QuickTile(
                            icon: Icons.notifications_active_rounded,
                            label: 'Notificaciones',
                            color: pink,
                            onTap: _openNotificaciones,
                          ),
                          _QuickTile(
                            icon: Icons.attach_money_rounded,
                            label: 'Ganancias',
                            color: pink,
                            onTap: _openGanancias,
                          ),
                          _QuickTile(
                            icon: Icons.support_agent_rounded,
                            label: 'Soporte',
                            color: pink,
                            onTap: _openSoporte,
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 22),

                  // ✅ Repartidor
                  const _SectionTitleX(title: 'Repartidor'),
                  const SizedBox(height: 14),

                  _MenuRowSimple(
                    icon: Icons.local_shipping_outlined,
                    label: 'Mi vehículo',
                    accent: pink,
                    onTap: _openVehiculo,
                  ),
                  const SizedBox(height: 18),

                  _MenuRowSimple(
                    icon: Icons.badge_outlined,
                    label: 'Documentos (CI / Licencia)',
                    accent: pink,
                    onTap: _openDocumentos,
                  ),
                  const SizedBox(height: 18),

                  _MenuRowSimple(
                    icon: Icons.map_outlined,
                    label: 'Zona de reparto',
                    accent: pink,
                    onTap: _openZona,
                  ),

                  const SizedBox(height: 26),

                  // ✅ Actividad
                  const _SectionTitleX(title: 'Actividad'),
                  const SizedBox(height: 14),

                  _MenuRowSimple(
                    icon: Icons.history_rounded,
                    label: 'Historial de entregas',
                    accent: Palette.primary,
                    onTap: _openHistorial,
                  ),
                  const SizedBox(height: 18),

                  _MenuRowSimple(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notificaciones',
                    accent: Palette.primary,
                    onTap: _openNotificaciones,
                  ),
                  const SizedBox(height: 18),

                  _MenuRowSimple(
                    icon: Icons.payments_outlined,
                    label: 'Ganancias',
                    accent: Palette.primary,
                    onTap: _openGanancias,
                  ),

                  const SizedBox(height: 26),

                  // ✅ Cuenta
                  const _SectionTitleX(title: 'Cuenta'),
                  const SizedBox(height: 14),

                  _MenuRowSimple(
                    icon: Icons.logout_rounded,
                    label: 'Cerrar sesión',
                    accent: const Color(0xFFFF3B30),
                    onTap: () async {
                      await widget.onLogout();
                      if (!mounted) return;
                      Modular.to.navigate('/login');
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ---------------- Widgets ---------------- */

class _SectionTitleX extends StatelessWidget {
  const _SectionTitleX({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Palette.ink,
        fontWeight: FontWeight.w900,
        fontSize: 19,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _SoftIconButton extends StatelessWidget {
  const _SoftIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Palette.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ink.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Icon(icon, color: ink.withOpacity(0.75), size: 23),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.role,
    required this.photoUrl,
    required this.onEdit,
  });

  final String name;
  final String email;
  final String role;
  final String photoUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final pink = Palette.button;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ink.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withOpacity(0.06),
              image: photoUrl.trim().isEmpty
                  ? null
                  : DecorationImage(
                      image: NetworkImage(photoUrl),
                      fit: BoxFit.cover,
                    ),
            ),
            child: photoUrl.trim().isEmpty
                ? Icon(
                    Icons.person_rounded,
                    color: ink.withOpacity(0.40),
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink.withOpacity(0.55),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: pink.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: pink.withOpacity(0.25)),
                  ),
                  child: Text(
                    _prettyRole(role),
                    style: TextStyle(
                      color: Palette.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: Palette.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ink.withOpacity(0.06)),
              ),
              child: Icon(Icons.edit_rounded, color: Palette.primary, size: 23),
            ),
          ),
        ],
      ),
    );
  }

  String _prettyRole(String r) {
    final v = r.toLowerCase().trim();
    if (v == 'admin') return 'Admin';
    if (v == 'conductor') return 'Conductor';
    if (v == 'repartidor') return 'Repartidor';
    return 'Cliente';
  }
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        scale: _down ? 0.98 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ink.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: Palette.primary, size: 21),
              ),
              const SizedBox(height: 10),
              Text(
                widget.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink.withOpacity(0.75),
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRowSimple extends StatefulWidget {
  const _MenuRowSimple({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_MenuRowSimple> createState() => _MenuRowSimpleState();
}

class _MenuRowSimpleState extends State<_MenuRowSimple> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 110),
        opacity: _down ? 0.85 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(widget.icon, color: widget.accent, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: ink.withOpacity(0.82),
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: ink.withOpacity(0.48),
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
