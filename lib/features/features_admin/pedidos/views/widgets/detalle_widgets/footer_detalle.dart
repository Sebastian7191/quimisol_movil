
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class Footer extends StatelessWidget {
  const Footer({
    super.key,
    required this.isSaving,
    required this.onClose,
    required this.onSave,
    this.readOnly = false,
  });

  final bool isSaving;
  final VoidCallback? onClose;
  final VoidCallback? onSave;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        border: Border(
          top: BorderSide(color: Palette.ink.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              readOnly
                  ? 'Este pedido ya fue entregado y no puede modificarse.'
                  : 'Asigna repartidor y fecha antes de guardar.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: readOnly
                    ? Palette.statsWarning
                    : Palette.ink.withValues(alpha: 0.62),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(onPressed: onClose, child: const Text('Cerrar')),
          if (!readOnly) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onSave,
              icon: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(isSaving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ],
      ),
    );
  }
}
