import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'new_almacen_form.dart';

class AddAlmacenDialog extends StatefulWidget {
  /// Si pasas estos valores, el diálogo funciona como "Editar"
  final String? initialNombre;
  final String? initialDepartamento;
  final String? initialDescripcion;

  /// Texto del título (si no pasas, se decide solo)
  final String? title;

  /// Texto del botón principal
  final String primaryActionText;

  /// Lista de departamentos (si no pasas, usa Bolivia por defecto)
  final List<String>? departamentos;

  const AddAlmacenDialog({
    super.key,
    this.initialNombre,
    this.initialDepartamento,
    this.initialDescripcion,
    this.title,
    this.primaryActionText = 'Guardar',
    this.departamentos,
  });

  @override
  State<AddAlmacenDialog> createState() => _AddAlmacenDialogState();
}

class _AddAlmacenDialogState extends State<AddAlmacenDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _descripcionCtrl;

  late List<String> _deptos;
  String? _depto;
  bool _saving = false;

  static const List<String> _deptosBolivia = [
    'La Paz',
    'Cochabamba',
    'Santa Cruz',
    'Oruro',
    'Potosí',
    'Chuquisaca',
    'Tarija',
    'Beni',
    'Pando',
  ];

  bool get _isEdit =>
      (widget.initialNombre ?? '').trim().isNotEmpty ||
      (widget.initialDepartamento ?? '').trim().isNotEmpty ||
      (widget.initialDescripcion ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _deptos = (widget.departamentos != null && widget.departamentos!.isNotEmpty)
        ? widget.departamentos!
        : _deptosBolivia;

    _nombreCtrl = TextEditingController(text: widget.initialNombre ?? '');
    _descripcionCtrl = TextEditingController(text: widget.initialDescripcion ?? '');

    final initDepto = (widget.initialDepartamento ?? '').trim();
    _depto = _deptos.contains(initDepto)
        ? initDepto
        : (_deptos.isNotEmpty ? _deptos.first : null);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_depto == null) return;

    setState(() => _saving = true);

    Navigator.pop(
      context,
      NewAlmacenFormResult(
        nombre: _nombreCtrl.text.trim(),
        departamento: _depto!,
        descripcion: _descripcionCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dialogTitle = widget.title ?? (_isEdit ? 'Editar almacén' : 'Agregar almacén');

    return Dialog(
      backgroundColor: Palette.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dialogTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 14),

              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombreCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Nombre del almacén',
                        prefixIcon: Icon(
                          Icons.warehouse_rounded,
                          color: Palette.primary.withValues(alpha: 0.9),
                        ),
                        filled: true,
                        fillColor: Palette.fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return 'Ingresa un nombre';
                        if (t.length < 3) return 'Mínimo 3 caracteres';
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _depto,
                      items: _deptos
                          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: _saving ? null : (v) => setState(() => _depto = v),
                      decoration: InputDecoration(
                        labelText: 'Departamento',
                        prefixIcon: Icon(
                          Icons.place_rounded,
                          color: Palette.primary.withValues(alpha: 0.9),
                        ),
                        filled: true,
                        fillColor: Palette.fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _descripcionCtrl,
                      minLines: 3,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Descripción (opcional)',
                        prefixIcon: Icon(
                          Icons.notes_rounded,
                          color: Palette.primary.withValues(alpha: 0.9),
                        ),
                        filled: true,
                        fillColor: Palette.fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.ink,
                        side: BorderSide(
                          color: Palette.button.withValues(alpha: 0.35),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.primary,
                        foregroundColor: Palette.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                        elevation: 0,
                      ),
                      icon: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_isEdit ? Icons.save_rounded : Icons.add_rounded),
                      label: Text(widget.primaryActionText),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
