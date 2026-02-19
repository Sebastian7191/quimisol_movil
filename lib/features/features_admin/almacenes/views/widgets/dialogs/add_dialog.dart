import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'new_almacen_form.dart';

class AddAlmacenDialog extends StatefulWidget {
  const AddAlmacenDialog({super.key});

  @override
  State<AddAlmacenDialog> createState() => _AddAlmacenDialogState();
}

class _AddAlmacenDialogState extends State<AddAlmacenDialog> {
  final _formKey = GlobalKey<FormState>();

  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  String _depto = 'La Paz';
  bool _saving = false;

  final List<String> deptosBolivia = const [
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

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    Navigator.pop(
      context,
      NewAlmacenFormResult(
        nombre: _nombreCtrl.text,
        departamento: _depto,
        descripcion: _descripcionCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Agregar almacén',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
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
                      decoration: InputDecoration(
                        labelText: 'Nombre del almacén',
                        filled: true,
                        fillColor: Palette.fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Ingresa un nombre';
                        }
                        if (v.trim().length < 3) {
                          return 'Mínimo 3 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                     // value: _depto,
                      items: deptosBolivia
                          .map(
                            (d) =>
                                DropdownMenuItem(value: d, child: Text(d)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _depto = v ?? _depto),
                      decoration: InputDecoration(
                        labelText: 'Departamento',
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
                      onPressed:
                          _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Guardar'),
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