import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/formulario1_models.dart';

class Formulario1Parte4 extends StatelessWidget {
  final bool isMobile;
  final List<Formulario1EvaluacionItem> evaluaciones;
  final void Function(int index, String? value) onRespuestaEvaluacionChanged;

  const Formulario1Parte4({
    super.key,
    required this.isMobile,
    required this.evaluaciones,
    required this.onRespuestaEvaluacionChanged,
  });

  static const List<String> _opciones = ['SI', 'NO'];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Parte 4 · Evaluación del servicio',
      child: Column(
        children: [
          if (isMobile)
            ...List.generate(evaluaciones.length, (index) {
              final item = evaluaciones[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == evaluaciones.length - 1 ? 0 : 12,
                ),
                child: _EvaluacionCardMobile(
                  index: index,
                  item: item,
                  opciones: _opciones,
                  onChanged: (value) =>
                      onRespuestaEvaluacionChanged(index, value),
                ),
              );
            })
          else
            _EvaluacionDesktopTable(
              evaluaciones: evaluaciones,
              opciones: _opciones,
              onChanged: onRespuestaEvaluacionChanged,
            ),
        ],
      ),
    );
  }
}

class _EvaluacionDesktopTable extends StatelessWidget {
  final List<Formulario1EvaluacionItem> evaluaciones;
  final List<String> opciones;
  final void Function(int index, String? value) onChanged;

  const _EvaluacionDesktopTable({
    required this.evaluaciones,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'Pregunta',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Text(
                  'Respuesta',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(evaluaciones.length, (index) {
          final item = evaluaciones[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == evaluaciones.length - 1 ? 0 : 10,
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _Field(
                      controller: item.preguntaCtrl,
                      label: 'Pregunta',
                      validator: _requiredValidator,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _DropdownRespuesta(
                      value: _safeDropdownValue(item.respuesta, opciones),
                      items: opciones,
                      label: 'Respuesta',
                      onChanged: (value) => onChanged(index, value),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _EvaluacionCardMobile extends StatelessWidget {
  final int index;
  final Formulario1EvaluacionItem item;
  final List<String> opciones;
  final ValueChanged<String?> onChanged;

  const _EvaluacionCardMobile({
    required this.index,
    required this.item,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pregunta ${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 23,
            ),
          ),
          const SizedBox(height: 10),
          _Field(
            controller: item.preguntaCtrl,
            label: 'Pregunta',
            validator: _requiredValidator,
            maxLines: 4,
          ),
          const SizedBox(height: 12),
          _DropdownRespuesta(
            value: _safeDropdownValue(item.respuesta, opciones),
            items: opciones,
            label: 'Respuesta',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _DropdownRespuesta extends StatelessWidget {
  final String? value;
  final List<String> items;
  final String label;
  final ValueChanged<String?>? onChanged;

  const _DropdownRespuesta({
    required this.value,
    required this.items,
    required this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map(
            (e) => DropdownMenuItem<String>(
              value: e,
              child: Text(e),
            ),
          )
          .toList(),
      onChanged: onChanged,
      validator: (value) {
        if ((value ?? '').trim().isEmpty) {
          return 'Campo requerido';
        }
        return null;
      },
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

String? _requiredValidator(String? value) {
  if ((value ?? '').trim().isEmpty) {
    return 'Campo requerido';
  }
  return null;
}

String? _safeDropdownValue(String? value, List<String> items) {
  if (value == null) return null;
  return items.contains(value) ? value : null;
}