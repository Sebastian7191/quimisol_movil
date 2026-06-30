import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

import 'package:quimisol_movil/features/features_admin/laboratorios/pages/laboratorios_form1.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/pages/laboratorios_form2.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/pages/laboratorios_form3.dart';

class LaboratoriosFormsSwitchPage extends StatefulWidget {
  final int initialIndex;
  final String? idPadre;
  final Map<String, dynamic>? initialDataForm1;
  final Map<String, dynamic>? initialDataForm2;
  final Map<String, dynamic>? initialDataForm3;

  const LaboratoriosFormsSwitchPage({
    super.key,
    this.initialIndex = 0,
    this.idPadre,
    this.initialDataForm1,
    this.initialDataForm2,
    this.initialDataForm3,
  });

  @override
  State<LaboratoriosFormsSwitchPage> createState() =>
      _LaboratoriosFormsSwitchPageState();
}

class _LaboratoriosFormsSwitchPageState
    extends State<LaboratoriosFormsSwitchPage> {
  late int _currentIndex;

  String? get _idPadreFinal {
    final fromWidget = widget.idPadre?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;

    final fromForm1 = widget.initialDataForm1?['id']?.toString().trim();
    if (fromForm1 != null && fromForm1.isNotEmpty) return fromForm1;

    final fromForm2Parent =
        widget.initialDataForm2?['parentId']?.toString().trim();
    if (fromForm2Parent != null && fromForm2Parent.isNotEmpty) {
      return fromForm2Parent;
    }

    final fromForm2 = widget.initialDataForm2?['id']?.toString().trim();
    if (fromForm2 != null && fromForm2.isNotEmpty) return fromForm2;

    final fromForm3 = widget.initialDataForm3?['id']?.toString().trim();
    if (fromForm3 != null && fromForm3.isNotEmpty) return fromForm3;

    return null;
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 2);
  }

  void _changeTab(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final idPadre = _idPadreFinal;

    final pages = [
      FormulariosForm1Page(
        idPadre: idPadre,
        initialData: widget.initialDataForm1,
      ),
      LaboratorioFormPage(
        idPadre: idPadre,
        initialData: widget.initialDataForm2,
      ),
      FormulariosForm3Page(
        idPadre: idPadre,
        initialData: widget.initialDataForm3,
      ),
    ];

    final titles = const [
      'Formulario Solicitud',
      'Formulario Recepción',
      'Formulario Ensayo',
    ];

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          titles[_currentIndex],
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _FormsSwitchBar(
              currentIndex: _currentIndex,
              onChanged: _changeTab,
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
    );
  }
}

class _FormsSwitchBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _FormsSwitchBar({
    required this.currentIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xffF2F4F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _SwitchItem(
            label: 'Formulario Solicitud',
            isSelected: currentIndex == 0,
            onTap: () => onChanged(0),
          ),
          _SwitchItem(
            label: 'Formulario Recepción',
            isSelected: currentIndex == 1,
            onTap: () => onChanged(1),
          ),
          _SwitchItem(
            label: 'Formulario Ensayo',
            isSelected: currentIndex == 2,
            onTap: () => onChanged(2),
          ),
        ],
      ),
    );
  }
}

class _SwitchItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SwitchItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isSelected ? Palette.button : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}