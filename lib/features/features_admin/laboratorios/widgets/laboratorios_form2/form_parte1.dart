import 'package:flutter/material.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/cliente_mayorista_option.dart';

import 'form_ui_helpers.dart';

class FormParte1CabeceraCliente extends StatelessWidget {
  final bool isMobile;
  final TextEditingController codigoCtrl;
  final TextEditingController versionCtrl;
  final TextEditingController vigenciaCtrl;
  final TextEditingController empresaClienteCtrl;
  final TextEditingController solicitanteCtrl;
  final TextEditingController proyectoInstalacionCtrl;
  final TextEditingController direccionCtrl;

  final List<ClienteMayoristaOption> clientesMayoristas;
  final String? clienteSeleccionadoId;
  final bool cargandoClientesMayoristas;
  final ValueChanged<String?> onClienteChanged;

  const FormParte1CabeceraCliente({
    super.key,
    required this.isMobile,
    required this.codigoCtrl,
    required this.versionCtrl,
    required this.vigenciaCtrl,
    required this.empresaClienteCtrl,
    required this.solicitanteCtrl,
    required this.proyectoInstalacionCtrl,
    required this.direccionCtrl,
    required this.clientesMayoristas,
    required this.clienteSeleccionadoId,
    required this.cargandoClientesMayoristas,
    required this.onClienteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FormUiHelpers.sectionCard(
          title: 'Cabecera del documento',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FormUiHelpers.field(codigoCtrl, 'Código', width: 220),
              FormUiHelpers.readOnlyField(versionCtrl, 'Versión', width: 160),
              FormUiHelpers.field(vigenciaCtrl, 'Vigencia', width: 180),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FormUiHelpers.sectionCard(
          title: 'I. Información general del cliente',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: isMobile ? double.infinity : 360,
                child: DropdownButtonFormField<String>(
                  value: clientesMayoristas.any(
                    (e) => e.id == clienteSeleccionadoId,
                  )
                      ? clienteSeleccionadoId
                      : null,
                  onChanged: cargandoClientesMayoristas ? null : onClienteChanged,
                  decoration: InputDecoration(
                    labelText: 'Empresa / Cliente',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: clientesMayoristas
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.id,
                          child: Text(
                            e.nombre,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
              ),
              FormUiHelpers.field(
                solicitanteCtrl,
                'Solicitante',
                width: isMobile ? double.infinity : 360,
                requiredField: true,
              ),
              FormUiHelpers.field(
                proyectoInstalacionCtrl,
                'Proyecto / Instalación',
                width: isMobile ? double.infinity : 360,
              ),
              FormUiHelpers.field(
                direccionCtrl,
                'Dirección',
                width: isMobile ? double.infinity : 360,
              ),
            ],
          ),
        ),
      ],
    );
  }
}