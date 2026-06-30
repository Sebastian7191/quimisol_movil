import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/laboratorio_form_models.dart';
import 'form_ui_helpers.dart';

class FormParte4InfoMuestras extends StatelessWidget {
  final bool isMobile;
  final List<ChecklistFormItem> checklist;
  final List<String> cumpleOptions;
  final TextEditingController totalMuestrasCtrl;
  final String? Function<String>(String?, List<String>) safeDropdownValue;
  final VoidCallback onAgregarChecklist;
  final void Function(int index) onEliminarChecklist;
  final void Function(ChecklistFormItem item, String? value) onCumpleChanged;

  const FormParte4InfoMuestras({
    super.key,
    required this.isMobile,
    required this.checklist,
    required this.cumpleOptions,
    required this.totalMuestrasCtrl,
    required this.safeDropdownValue,
    required this.onAgregarChecklist,
    required this.onEliminarChecklist,
    required this.onCumpleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormUiHelpers.sectionCard(
      title: 'IV. Información de las muestras',
      child: Column(
        children: [
          ...List.generate(checklist.length, (index) {
            final item = checklist[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.fieldBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Palette.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Información ${index + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 23,
                        ),
                      ),
                      const Spacer(),
                      if (checklist.length > 1)
                        IconButton(
                          onPressed: () => onEliminarChecklist(index),
                          icon: Icon(
                            Icons.delete_rounded,
                            color: Colors.red.shade600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FormUiHelpers.field(
                        item.detalleCtrl,
                        'Detalle',
                        width: isMobile ? double.infinity : 520,
                        maxLines: 2,
                      ),
                      FormUiHelpers.dropdownField<String>(
                        label: 'Cumple',
                        value: safeDropdownValue(item.cumple, cumpleOptions),
                        width: 180,
                        items: cumpleOptions,
                        onChanged: (v) => onCumpleChanged(item, v),
                      ),
                      FormUiHelpers.field(
                        item.observacionesCtrl,
                        'Observaciones',
                        width: isMobile ? double.infinity : 320,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: onAgregarChecklist,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar información de muestras'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FormUiHelpers.field(
            totalMuestrasCtrl,
            'Total de muestras entregadas',
            width: 220,
            requiredField: true,
          ),
        ],
      ),
    );
  }
}