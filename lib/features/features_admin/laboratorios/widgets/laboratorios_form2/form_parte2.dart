import 'package:flutter/material.dart';
import 'form_ui_helpers.dart';

class FormParte2DatosGenerales extends StatelessWidget {
  final bool isMobile;
  final TextEditingController fechaMuestreoCtrl;
  final TextEditingController fechaRecepcionCtrl;
  final TextEditingController horaRecepcionCtrl;
  final TextEditingController numeroCotizacionCtrl;
  final TextEditingController temperaturaCtrl;
  final TextEditingController nombreTecnicoCtrl;

  final bool temperaturaNoAplica;
  final bool muestreoPorQuimisol;
  final bool muestraTomadaPorCliente;

  final ValueChanged<bool?> onTemperaturaNoAplicaChanged;
  final ValueChanged<bool?> onMuestreoPorQuimisolChanged;
  final ValueChanged<bool?> onMuestraTomadaPorClienteChanged;

  final String? Function(String?) validarFecha;
  final String? Function(String?) validarHora;

  const FormParte2DatosGenerales({
    super.key,
    required this.isMobile,
    required this.fechaMuestreoCtrl,
    required this.fechaRecepcionCtrl,
    required this.horaRecepcionCtrl,
    required this.numeroCotizacionCtrl,
    required this.temperaturaCtrl,
    required this.nombreTecnicoCtrl,
    required this.temperaturaNoAplica,
    required this.muestreoPorQuimisol,
    required this.muestraTomadaPorCliente,
    required this.onTemperaturaNoAplicaChanged,
    required this.onMuestreoPorQuimisolChanged,
    required this.onMuestraTomadaPorClienteChanged,
    required this.validarFecha,
    required this.validarHora,
  });

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return FormUiHelpers.sectionCard(
      title: 'II. Datos generales',
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FormUiHelpers.field(
                fechaMuestreoCtrl,
                'Fecha de muestreo',
                width: 220,
                readOnly: true,
                suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    fechaMuestreoCtrl.text = _formatDate(picked);
                  }
                },
                validator: validarFecha,
              ),
              FormUiHelpers.field(
                fechaRecepcionCtrl,
                'Fecha de recepción de muestra',
                width: 260,
                requiredField: true,
                readOnly: true,
                suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    fechaRecepcionCtrl.text = _formatDate(picked);
                  }
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Requerido';
                  }
                  return validarFecha(v);
                },
              ),
              FormUiHelpers.field(
                horaRecepcionCtrl,
                'Hora de recepción de muestra',
                width: 220,
                requiredField: true,
                readOnly: true,
                suffixIcon: const Icon(Icons.access_time_rounded, size: 18),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (picked != null) {
                    horaRecepcionCtrl.text = _formatTime(picked);
                  }
                },
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Requerido';
                  }
                  return validarHora(v);
                },
              ),
              FormUiHelpers.field(
                numeroCotizacionCtrl,
                'Número de cotización',
                width: 220,
              ),
              FormUiHelpers.field(
                temperaturaCtrl,
                'Temperatura del recipiente de la muestra (°C)',
                width: isMobile ? double.infinity : 320,
              ),
              FormUiHelpers.field(
                nombreTecnicoCtrl,
                'QUIMISOL / Nombre Tec.',
                width: isMobile ? double.infinity : 320,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              CheckboxListTile(
                dense: true,
                value: temperaturaNoAplica,
                onChanged: onTemperaturaNoAplicaChanged,
                title: const Text('No aplica'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                dense: true,
                value: muestreoPorQuimisol,
                onChanged: onMuestreoPorQuimisolChanged,
                title: const Text('Muestreo por QUIMISOL'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              CheckboxListTile(
                dense: true,
                value: muestraTomadaPorCliente,
                onChanged: onMuestraTomadaPorClienteChanged,
                title: const Text('Muestra tomada por cliente'),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
