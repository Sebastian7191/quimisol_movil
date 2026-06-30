import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/laboratorios3_models.dart';

class Formulario3Parte4 extends StatelessWidget {
  final bool isMobile;
  final List<Formulario3ResultadoItem> items;
  final VoidCallback onAgregarItem;
  final void Function(int index) onEliminarItem;

  const Formulario3Parte4({
    super.key,
    required this.isMobile,
    required this.items,
    required this.onAgregarItem,
    required this.onEliminarItem,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Parte 4 · Resultados de ensayo',
      child: Column(
        children: [
          if (isMobile)
            ...List.generate(items.length, (index) {
              final item = items[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == items.length - 1 ? 0 : 12,
                ),
                child: _MobileItemCard(
                  item: item,
                  canDelete: items.length > 1,
                  onDelete: () => onEliminarItem(index),
                ),
              );
            })
          else
            _DesktopTable(
              items: items,
              onEliminarItem: onEliminarItem,
            ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onAgregarItem,
              style: FilledButton.styleFrom(
                backgroundColor: Palette.button,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Agregar resultado'),
            ),
          ),
        ],
      ),
    );
  }
}

String? _requiredValidator(String? value) {
  if ((value ?? '').trim().isEmpty) return 'Campo requerido';
  return null;
}

class _DesktopTable extends StatelessWidget {
  final List<Formulario3ResultadoItem> items;
  final void Function(int index) onEliminarItem;

  const _DesktopTable({
    required this.items,
    required this.onEliminarItem,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Palette.fieldBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 52,
                child: Text(
                  'Item',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Parámetros')),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Método de ensayo')),
              SizedBox(width: 8),
              Expanded(child: Text('Unidad')),
              SizedBox(width: 8),
              Expanded(child: Text('L.D.')),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Límites máximos')),
              SizedBox(width: 8),
              Expanded(flex: 2, child: Text('Resultados')),
              SizedBox(width: 8),
              SizedBox(width: 56),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == items.length - 1 ? 0 : 10,
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
                  SizedBox(
                    width: 52,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Text(
                        '${item.item}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _Field(
                      controller: item.parametrosCtrl,
                      label: 'Parámetros',
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _Field(
                      controller: item.metodoEnsayoCtrl,
                      label: 'Método de ensayo',
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Field(
                      controller: item.unidadCtrl,
                      label: 'Unidad',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Field(
                      controller: item.ldCtrl,
                      label: 'L.D.',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _Field(
                      controller: item.limitesMaximosCtrl,
                      label: 'Límites máximos',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _Field(
                      controller: item.resultadosCtrl,
                      label: 'Resultados',
                      validator: _requiredValidator,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 56,
                    child: IconButton(
                      onPressed: items.length > 1
                          ? () => onEliminarItem(index)
                          : null,
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: Colors.redAccent,
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

class _MobileItemCard extends StatelessWidget {
  final Formulario3ResultadoItem item;
  final bool canDelete;
  final VoidCallback onDelete;

  const _MobileItemCard({
    required this.item,
    required this.canDelete,
    required this.onDelete,
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
          Row(
            children: [
              Text(
                'Ítem ${item.item}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 23,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: canDelete ? onDelete : null,
                icon: const Icon(Icons.delete_outline_rounded),
                color: Colors.redAccent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Field(
            controller: item.parametrosCtrl,
            label: 'Parámetros',
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          _Field(
            controller: item.metodoEnsayoCtrl,
            label: 'Método de ensayo',
            validator: _requiredValidator,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Field(
                  controller: item.unidadCtrl,
                  label: 'Unidad',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Field(
                  controller: item.ldCtrl,
                  label: 'L.D.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Field(
            controller: item.limitesMaximosCtrl,
            label: 'Límites máximos',
          ),
          const SizedBox(height: 12),
          _Field(
            controller: item.resultadosCtrl,
            label: 'Resultados',
            validator: _requiredValidator,
          ),
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