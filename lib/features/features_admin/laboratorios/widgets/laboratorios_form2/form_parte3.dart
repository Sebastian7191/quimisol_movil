import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/laboratorio_form_models.dart';
import 'form_ui_helpers.dart';

class FormParte3Muestras extends StatelessWidget {
  final bool isMobile;
  final List<MuestraFormItem> muestras;
  final List<String> tiposMuestra;
  final List<String> tiposEnvase;
  final String? Function<String>(String?, List<String>) safeDropdownValue;
  final VoidCallback onAgregarMuestra;
  final void Function(int index) onEliminarMuestra;
  final void Function(MuestraFormItem item, String? value) onTipoMuestraChanged;
  final void Function(MuestraFormItem item, String? value) onTipoEnvaseChanged;

  const FormParte3Muestras({
    super.key,
    required this.isMobile,
    required this.muestras,
    required this.tiposMuestra,
    required this.tiposEnvase,
    required this.safeDropdownValue,
    required this.onAgregarMuestra,
    required this.onEliminarMuestra,
    required this.onTipoMuestraChanged,
    required this.onTipoEnvaseChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormUiHelpers.sectionCard(
      title: 'III. Descripción de las muestras',
      subtitle:
          'Tipo de muestra:\n'
          'AP = Agua Potable\n'
          'AC = Agua de consumo\n'
          'ARD = Agua Residual Doméstica\n'
          'ARI = Agua residual Industrial\n'
          'AB = Agua Subterránea\n'
          'AS = Agua Superficial\n'
          'S = Suelo\n'
          'Z = Cenizas\n'
          'L = Líquida\n\n'
          'Tipo de envase:\n'
          'P = Plástico\n'
          'V = Vidrio\n'
          'VA = Vidrio Ámbar\n'
          'VB = Vidrio Bacteriológico\n'
          'B = Bolsa plástica',
      child: Column(
        children: [
          ...List.generate(muestras.length, (index) {
            final item = muestras[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.fieldBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Palette.primary.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Muestra ${item.no}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const Spacer(),
                      if (muestras.length > 1)
                        IconButton(
                          onPressed: () => onEliminarMuestra(index),
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
                        item.codigoMuestraCtrl,
                        'Códigos de muestras',
                        width: isMobile ? double.infinity : 260,
                        requiredField: true,
                        maxLines: 2,
                      ),
                      FormUiHelpers.dropdownField<String>(
                        label: 'Tipo muestra',
                        value: safeDropdownValue(item.tipoMuestra, tiposMuestra),
                        width: 180,
                        items: tiposMuestra,
                        onChanged: (v) => onTipoMuestraChanged(item, v),
                      ),
                      FormUiHelpers.field(
                        item.cantidadCtrl,
                        'Cantidad',
                        width: 150,
                      ),
                      FormUiHelpers.field(
                        item.volumenPesoCtrl,
                        'Volumen / Peso',
                        width: 180,
                      ),
                      FormUiHelpers.dropdownField<String>(
                        label: 'Tipo envase',
                        value: safeDropdownValue(item.tipoEnvase, tiposEnvase),
                        width: 180,
                        items: tiposEnvase,
                        onChanged: (v) => onTipoEnvaseChanged(item, v),
                      ),
                      FormUiHelpers.field(
                        item.descripcionCtrl,
                        'Descripción',
                        width: isMobile ? double.infinity : 320,
                      ),
                      FormUiHelpers.field(
                        item.numeroLaboratorioCtrl,
                        'No. de laboratorio',
                        width: 180,
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
              onPressed: onAgregarMuestra,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar muestra'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}