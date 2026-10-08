import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class Formulario3Parte3 extends StatelessWidget {
  final bool isMobile;

  final TextEditingController lugarMuestreoCtrl;
  final TextEditingController fechaMuestreoCtrl;
  final TextEditingController horaMuestreoCtrl;
  final TextEditingController condicionesClimaticasCtrl;
  final TextEditingController temperaturaAmbienteCtrl;
  final TextEditingController responsableMuestreoCtrl;
  final TextEditingController observacionesCtrl;
  final TextEditingController coordenadasMuestreoCtrl;
  final TextEditingController coordenadaXCtrl;
  final TextEditingController coordenadaYCtrl;

  final String? Function(String?)? validarFecha;
  final String? Function(String?)? validarHora;

  const Formulario3Parte3({
    super.key,
    required this.isMobile,
    required this.lugarMuestreoCtrl,
    required this.fechaMuestreoCtrl,
    required this.horaMuestreoCtrl,
    required this.condicionesClimaticasCtrl,
    required this.temperaturaAmbienteCtrl,
    required this.responsableMuestreoCtrl,
    required this.observacionesCtrl,
    required this.coordenadasMuestreoCtrl,
    required this.coordenadaXCtrl,
    required this.coordenadaYCtrl,
    this.validarFecha,
    this.validarHora,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Parte 3 · Información del muestreo',
      child: Column(
        children: [
          if (isMobile) ...[
            _Field(
              controller: lugarMuestreoCtrl,
              label: 'Lugar de muestreo',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: fechaMuestreoCtrl,
              label: 'Fecha de muestreo',
              validator: validarFecha,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: horaMuestreoCtrl,
              label: 'Hora de muestreo',
              validator: validarHora,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: condicionesClimaticasCtrl,
              label: 'Condiciones climáticas',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: temperaturaAmbienteCtrl,
              label: 'Temperatura Ambiente',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: responsableMuestreoCtrl,
              label: 'Responsable del muestreo',
            ),
            const SizedBox(height: 12),
            _Field(
              controller: observacionesCtrl,
              label: 'Observaciones',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            _Field(
              controller: coordenadasMuestreoCtrl,
              label: 'Coordenadas de muestreo',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: coordenadaXCtrl,
                    label: 'X',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: coordenadaYCtrl,
                    label: 'Y',
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: lugarMuestreoCtrl,
                    label: 'Lugar de muestreo',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: fechaMuestreoCtrl,
                    label: 'Fecha de muestreo',
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
                    controller: horaMuestreoCtrl,
                    label: 'Hora de muestreo',
                    validator: validarHora,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: condicionesClimaticasCtrl,
                    label: 'Condiciones climáticas',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: temperaturaAmbienteCtrl,
                    label: 'Temperatura Ambiente',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: responsableMuestreoCtrl,
                    label: 'Responsable del muestreo',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Field(
              controller: observacionesCtrl,
              label: 'Observaciones',
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: coordenadasMuestreoCtrl,
                    label: 'Coordenadas de muestreo',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: coordenadaXCtrl,
                    label: 'X',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: coordenadaYCtrl,
                    label: 'Y',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
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
              fontSize: 16,
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

  const _Field({
    required this.controller,
    required this.label,
    this.validator,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
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