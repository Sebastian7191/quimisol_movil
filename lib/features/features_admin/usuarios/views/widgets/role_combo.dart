import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import '../../controllers/usuarios_controller.dart';

class RoleComboFancy extends StatefulWidget {
  const RoleComboFancy({
    super.key,
    required this.controller,
    required this.uid,
    required this.currentRole,
    this.onChanged,
  });

  final UsuariosController controller;
  final String uid;
  final String currentRole;
  final ValueChanged<String>? onChanged;

  @override
  State<RoleComboFancy> createState() => _RoleComboFancyState();
}

class _RoleComboFancyState extends State<RoleComboFancy> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _setRole(String role) async {
    if (_saving) return;
    if (role == widget.currentRole) return;

    setState(() {
      _saving = true;
      _saved = false;
    });

    try {
      await widget.controller.setRole(
        uid: widget.uid,
        role: role,
      );

      widget.onChanged?.call(role);

      if (!mounted) return;
      setState(() => _saved = true);

      await Future.delayed(const Duration(milliseconds: 750));
      if (mounted) setState(() => _saved = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo actualizar rol: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _colorFor(String r) {
    switch (r) {
      case 'superadmin':
        return Colors.amber.shade700;
      case 'admin':
        return Palette.primary;
      case 'repartidor':
        return Palette.statsSuccess;
      case 'cliente_mayorista':
        return Colors.deepPurple;
      case 'cliente':
      default:
        return Palette.button;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;
    final color = _colorFor(widget.currentRole);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: ScaleTransition(scale: anim, child: child),
            ),
            child: _saving
                ? SizedBox(
                    key: const ValueKey('loading'),
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : _saved
                    ? Icon(
                        Icons.check_circle_rounded,
                        key: const ValueKey('saved'),
                        color: color,
                        size: 18,
                      )
                    : Icon(
                        Icons.tune_rounded,
                        key: const ValueKey('idle'),
                        color: color,
                        size: 18,
                      ),
          ),
          const SizedBox(width: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: widget.currentRole,
              dropdownColor: Palette.white,
              borderRadius: BorderRadius.circular(14),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: ink.withValues(alpha: .55),
              ),
              style: TextStyle(
                color: ink,
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
              ),
              onChanged:
                  _saving ? null : (v) => _setRole(v ?? widget.currentRole),
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
                DropdownMenuItem(
                  value: 'cliente_mayorista',
                  child: Text('Cliente Mayorista'),
                ),
                DropdownMenuItem(
                  value: 'repartidor',
                  child: Text('Repartidor'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}