import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/laboratorio_input_formatters.dart';
import 'form_ui_helpers.dart';

class FormParte5Recepcion extends StatelessWidget {
  final TextEditingController entregadoFirmaCtrl;
  final TextEditingController entregadoNombreCtrl;
  final TextEditingController entregadoFechaCtrl;

  final TextEditingController recibidoFirmaCtrl;
  final TextEditingController recibidoNombreCtrl;
  final TextEditingController recibidoFechaCtrl;

  final TextEditingController observacionesAdicionalesCtrl;

  final String? Function(String?) validarFecha;

  const FormParte5Recepcion({
    super.key,
    required this.entregadoFirmaCtrl,
    required this.entregadoNombreCtrl,
    required this.entregadoFechaCtrl,
    required this.recibidoFirmaCtrl,
    required this.recibidoNombreCtrl,
    required this.recibidoFechaCtrl,
    required this.observacionesAdicionalesCtrl,
    required this.validarFecha,
  });

  @override
  Widget build(BuildContext context) {
    return FormUiHelpers.sectionCard(
      title: 'V. Recepción',
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FormUiHelpers.miniGroup(
                title: 'Entregado por',
                children: [
                  FormUiHelpers.field(
                    entregadoFirmaCtrl,
                    'Firma',
                    width: double.infinity,
                  ),
                  FormUiHelpers.field(
                    entregadoNombreCtrl,
                    'Nombre',
                    width: double.infinity,
                    requiredField: true,
                  ),
                  FormUiHelpers.field(
                    entregadoFechaCtrl,
                    'Fecha',
                    width: double.infinity,
                    requiredField: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      DateTextInputFormatter(),
                    ],
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return validarFecha(v);
                    },
                  ),
                ],
              ),
              FormUiHelpers.miniGroup(
                title: 'Recibido por',
                children: [
                  FormUiHelpers.field(
                    recibidoFirmaCtrl,
                    'Firma',
                    width: double.infinity,
                  ),
                  FormUiHelpers.field(
                    recibidoNombreCtrl,
                    'Nombre',
                    width: double.infinity,
                    requiredField: true,
                  ),
                  FormUiHelpers.field(
                    recibidoFechaCtrl,
                    'Fecha',
                    width: double.infinity,
                    requiredField: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      DateTextInputFormatter(),
                    ],
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return validarFecha(v);
                    },
                  ),
                ],
              ),
              FormUiHelpers.miniGroup(
                title: 'Observaciones adicionales',
                children: [
                  FormUiHelpers.field(
                    observacionesAdicionalesCtrl,
                    'Observaciones adicionales',
                    width: double.infinity,
                    maxLines: 6,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}