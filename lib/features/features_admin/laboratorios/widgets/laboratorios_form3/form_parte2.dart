import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class Formulario3Parte2 extends StatelessWidget {
  final bool isMobile;
  final TextEditingController identificacionLaboratorioCtrl;
  final TextEditingController codigoClienteCtrl;
  final TextEditingController tipoMuestraMatrizCtrl;
  final TextEditingController fechaRecepcionCtrl;
  final TextEditingController fechaEntregaCtrl;

  final String? Function(String?)? validarFecha;

  const Formulario3Parte2({
    super.key,
    required this.isMobile,
    required this.identificacionLaboratorioCtrl,
    required this.codigoClienteCtrl,
    required this.tipoMuestraMatrizCtrl,
    required this.fechaRecepcionCtrl,
    required this.fechaEntregaCtrl,
    this.validarFecha,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Parte 2 · Información de la muestra',
      child: Column(
        children: [
          if (isMobile) ...[
            _Field(
              controller: identificacionLaboratorioCtrl,
              label: 'Identificación del laboratorio',
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: codigoClienteCtrl,
              label: 'Código del cliente',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: tipoMuestraMatrizCtrl,
              label: 'Tipo de muestra (Matriz)',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: fechaRecepcionCtrl,
              label: 'Fecha de recepción',
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
                  fechaRecepcionCtrl.text =
                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                }
              },
              validator: validarFecha,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: fechaEntregaCtrl,
              label: 'Fecha de entrega',
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
                  fechaEntregaCtrl.text =
                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                }
              },
              validator: validarFecha,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: identificacionLaboratorioCtrl,
                    label: 'Identificación del laboratorio',
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: codigoClienteCtrl,
                    label: 'Código del cliente',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: tipoMuestraMatrizCtrl,
                    label: 'Tipo de muestra (Matriz)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: fechaRecepcionCtrl,
                    label: 'Fecha de recepción',
                    readOnly: true,
                    suffixIcon:
                        const Icon(Icons.calendar_today_rounded, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        fechaRecepcionCtrl.text =
                            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                      }
                    },
                    validator: validarFecha,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: fechaEntregaCtrl,
                    label: 'Fecha de entrega',
                    readOnly: true,
                    suffixIcon:
                        const Icon(Icons.calendar_today_rounded, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        fechaEntregaCtrl.text =
                            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                      }
                    },
                    validator: validarFecha,
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Campo requerido';
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x11000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? suffixIcon;

  const _Field({
    required this.controller,
    required this.label,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
    this.onTap,
    this.readOnly = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Palette.fieldBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Palette.button, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
      ),
    );
  }
}