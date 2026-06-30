import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/cliente_mayorista_option.dart';

class Formulario1Parte1 extends StatelessWidget {
  final bool isMobile;
  final TextEditingController registroCtrl;
  final TextEditingController solicitadoPorCtrl;
  final TextEditingController areaSolicitanteCtrl;
  final TextEditingController tipoServicioCtrl;

  final List<ClienteMayoristaOption> clientesMayoristas;
  final String? clienteSeleccionadoId;
  final bool cargandoClientesMayoristas;
  final ValueChanged<String?> onClienteChanged;

  const Formulario1Parte1({
    super.key,
    required this.isMobile,
    required this.registroCtrl,
    required this.solicitadoPorCtrl,
    required this.areaSolicitanteCtrl,
    required this.tipoServicioCtrl,
    required this.clientesMayoristas,
    required this.clienteSeleccionadoId,
    required this.cargandoClientesMayoristas,
    required this.onClienteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Parte 1 · Datos generales de la solicitud',
      child: Column(
        children: [
          if (isMobile) ...[
            _FormField(
              label: 'Registro',
              controller: registroCtrl,
            ),
            const SizedBox(height: 12),
            _ClienteDropdownField(
              label: 'Solicitado por',
              clientesMayoristas: clientesMayoristas,
              clienteSeleccionadoId: clienteSeleccionadoId,
              cargandoClientesMayoristas: cargandoClientesMayoristas,
              onClienteChanged: onClienteChanged,
            ),
            const SizedBox(height: 12),
            _FormField(
              label: 'Área solicitante',
              controller: areaSolicitanteCtrl,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 12),
            _FormField(
              label: 'Tipo de servicio',
              controller: tipoServicioCtrl,
              validator: _requiredValidator,
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: 'Registro',
                    controller: registroCtrl,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ClienteDropdownField(
                    label: 'Solicitado por',
                    clientesMayoristas: clientesMayoristas,
                    clienteSeleccionadoId: clienteSeleccionadoId,
                    cargandoClientesMayoristas: cargandoClientesMayoristas,
                    onClienteChanged: onClienteChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _FormField(
                    label: 'Área solicitante',
                    controller: areaSolicitanteCtrl,
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FormField(
                    label: 'Tipo de servicio',
                    controller: tipoServicioCtrl,
                    validator: _requiredValidator,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Campo requerido';
    }
    return null;
  }
}

class _ClienteDropdownField extends StatelessWidget {
  final String label;
  final List<ClienteMayoristaOption> clientesMayoristas;
  final String? clienteSeleccionadoId;
  final bool cargandoClientesMayoristas;
  final ValueChanged<String?> onClienteChanged;

  const _ClienteDropdownField({
    required this.label,
    required this.clientesMayoristas,
    required this.clienteSeleccionadoId,
    required this.cargandoClientesMayoristas,
    required this.onClienteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: clientesMayoristas.any((e) => e.id == clienteSeleccionadoId)
          ? clienteSeleccionadoId
          : null,
      onChanged: cargandoClientesMayoristas ? null : onClienteChanged,
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

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextInputType? keyboardType;

  const _FormField({
    required this.label,
    required this.controller,
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