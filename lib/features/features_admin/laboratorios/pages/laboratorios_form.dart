import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class LaboratorioFormPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const LaboratorioFormPage({super.key, this.initialData});

  @override
  State<LaboratorioFormPage> createState() => _LaboratorioFormPageState();
}

class _LaboratorioFormPageState extends State<LaboratorioFormPage> {
  final _formKey = GlobalKey<FormState>();

  final CollectionReference<Map<String, dynamic>> _laboratoriosRef =
      FirebaseFirestore.instance.collection('laboratorios');

  late final TextEditingController _idCtrl;
  late final TextEditingController _codigoCtrl;
  late final TextEditingController _versionCtrl;
  late final TextEditingController _vigenciaCtrl;

  late final TextEditingController _empresaClienteCtrl;
  late final TextEditingController _solicitanteCtrl;
  late final TextEditingController _proyectoInstalacionCtrl;
  late final TextEditingController _direccionCtrl;

  late final TextEditingController _fechaMuestreoCtrl;
  late final TextEditingController _fechaRecepcionCtrl;
  late final TextEditingController _horaRecepcionCtrl;
  late final TextEditingController _numeroCotizacionCtrl;
  late final TextEditingController _temperaturaCtrl;
  late final TextEditingController _nombreTecnicoCtrl;

  late final TextEditingController _totalMuestrasCtrl;

  late final TextEditingController _entregadoFirmaCtrl;
  late final TextEditingController _entregadoNombreCtrl;
  late final TextEditingController _entregadoFechaCtrl;

  late final TextEditingController _recibidoFirmaCtrl;
  late final TextEditingController _recibidoNombreCtrl;
  late final TextEditingController _recibidoFechaCtrl;

  late final TextEditingController _observacionesAdicionalesCtrl;

  bool _temperaturaNoAplica = false;
  bool _muestreoPorQuimisol = false;
  bool _muestraTomadaPorCliente = false;
  bool _guardando = false;

  List<MuestraFormItem> _muestras = [];
  List<ChecklistFormItem> _checklist = [];

  bool get isEdit => widget.initialData != null;
  String? get _firestoreId => widget.initialData?['firestoreId']?.toString();

  final List<String> _tiposMuestra = const [
    'AP',
    'AC',
    'ARD',
    'ARI',
    'AB',
    'AS',
    'S',
    'Z',
    'L',
  ];

  final List<String> _tiposEnvase = const [
    'P',
    'V',
    'VA',
    'VB',
    'B',
  ];

  final List<String> _cumpleOptions = const [
    'SI',
    'NO',
    'N/A',
    '-',
  ];

  @override
  void initState() {
    super.initState();

    final data = widget.initialData ?? {};

    final encabezado = Map<String, dynamic>.from(data['encabezado'] ?? {});
    final infoCliente =
        Map<String, dynamic>.from(data['informacionGeneralCliente'] ?? {});
    final datosGenerales = Map<String, dynamic>.from(data['datosGenerales'] ?? {});
    final descripcionMuestras =
        Map<String, dynamic>.from(data['descripcionMuestras'] ?? {});
    final infoMuestras =
        Map<String, dynamic>.from(data['informacionMuestras'] ?? {});
    final recepcion = Map<String, dynamic>.from(data['recepcion'] ?? {});
    final entregadoPor = Map<String, dynamic>.from(recepcion['entregadoPor'] ?? {});
    final recibidoPor = Map<String, dynamic>.from(recepcion['recibidoPor'] ?? {});

    _idCtrl = TextEditingController(
      text: (data['id'] ?? _generarId()).toString(),
    );
    _codigoCtrl = TextEditingController(
      text: (encabezado['codigo'] ?? 'FTSGI-01-02').toString(),
    );
    _versionCtrl = TextEditingController(
      text: (encabezado['version'] ?? '1').toString(),
    );
    _vigenciaCtrl = TextEditingController(
      text: (encabezado['vigencia'] ?? '18-09-2024').toString(),
    );

    _empresaClienteCtrl = TextEditingController(
      text: (infoCliente['empresaCliente'] ?? '').toString(),
    );
    _solicitanteCtrl = TextEditingController(
      text: (infoCliente['solicitante'] ?? '').toString(),
    );
    _proyectoInstalacionCtrl = TextEditingController(
      text: (infoCliente['proyectoInstalacion'] ?? '').toString(),
    );
    _direccionCtrl = TextEditingController(
      text: (infoCliente['direccion'] ?? '').toString(),
    );

    _fechaMuestreoCtrl = TextEditingController(
      text: (datosGenerales['fechaMuestreo'] ?? '').toString(),
    );
    _fechaRecepcionCtrl = TextEditingController(
      text: (datosGenerales['fechaRecepcionMuestra'] ?? '').toString(),
    );
    _horaRecepcionCtrl = TextEditingController(
      text: (datosGenerales['horaRecepcionMuestra'] ?? '').toString(),
    );
    _numeroCotizacionCtrl = TextEditingController(
      text: (datosGenerales['numeroCotizacion'] ?? '').toString(),
    );
    _temperaturaCtrl = TextEditingController(
      text: (datosGenerales['temperaturaRecipiente'] ?? '').toString(),
    );
    _nombreTecnicoCtrl = TextEditingController(
      text: (datosGenerales['nombreTecnico'] ?? '').toString(),
    );

    _totalMuestrasCtrl = TextEditingController(
      text: (infoMuestras['totalMuestrasEntregadas'] ?? '').toString(),
    );

    _entregadoFirmaCtrl = TextEditingController(
      text: (entregadoPor['firma'] ?? '').toString(),
    );
    _entregadoNombreCtrl = TextEditingController(
      text: (entregadoPor['nombre'] ?? '').toString(),
    );
    _entregadoFechaCtrl = TextEditingController(
      text: (entregadoPor['fecha'] ?? '').toString(),
    );

    _recibidoFirmaCtrl = TextEditingController(
      text: (recibidoPor['firma'] ?? '').toString(),
    );
    _recibidoNombreCtrl = TextEditingController(
      text: (recibidoPor['nombre'] ?? '').toString(),
    );
    _recibidoFechaCtrl = TextEditingController(
      text: (recibidoPor['fecha'] ?? '').toString(),
    );

    _observacionesAdicionalesCtrl = TextEditingController(
      text: (recepcion['observacionesAdicionales'] ?? '').toString(),
    );

    _temperaturaNoAplica = datosGenerales['temperaturaNoAplica'] == true;
    _muestreoPorQuimisol = datosGenerales['muestreoPorQuimisol'] == true;
    _muestraTomadaPorCliente = datosGenerales['muestraTomadaPorCliente'] == true;

    final muestrasData = (descripcionMuestras['muestras'] as List?) ?? [];
    if (muestrasData.isNotEmpty) {
      _muestras = muestrasData
          .map((e) => MuestraFormItem.fromMap(
                Map<String, dynamic>.from(e),
                tiposMuestraValidos: _tiposMuestra,
                tiposEnvaseValidos: _tiposEnvase,
              ))
          .toList();
    } else {
      _muestras = List.generate(
        2,
        (index) => MuestraFormItem(no: index + 1),
      );
    }

    final checklistData = (infoMuestras['items'] as List?) ?? [];
    if (checklistData.isNotEmpty) {
      _checklist = checklistData
          .map((e) => ChecklistFormItem.fromMap(
                Map<String, dynamic>.from(e),
                cumpleValidos: _cumpleOptions,
              ))
          .toList();
    } else {
      _checklist = [
        ChecklistFormItem(
          orden: 1,
          detalle:
              '¿Se tiene definido los parámetros a ensayar? (adjuntar solicitud o cotización)',
          cumple: 'SI',
        ),
        ChecklistFormItem(
          orden: 2,
          detalle:
              '¿Se han utilizado conservadoras diferentes para evitar la contaminación cruzada?',
          cumple: 'SI',
        ),
        ChecklistFormItem(
          orden: 3,
          detalle: '¿La conservadora se encuentra cerrada?',
          cumple: 'SI',
        ),
        ChecklistFormItem(
          orden: 4,
          detalle: '¿Los envases están herméticamente cerrados (sin derrame)?',
          cumple: 'SI',
        ),
        ChecklistFormItem(
          orden: 5,
          detalle:
              '¿La cantidad de muestra es suficiente para los ensayos solicitados?',
          cumple: 'SI',
        ),
        ChecklistFormItem(
          orden: 6,
          detalle: '¿Se han utilizado conservantes en los envases?',
          cumple: '-',
        ),
        ChecklistFormItem(
          orden: 7,
          detalle: '¿Los envases cuentan con la identificación respectiva?',
          cumple: 'SI',
        ),
        ChecklistFormItem(
          orden: 8,
          detalle:
              '¿Los datos de las etiquetas coinciden con los descritos en los registros?',
          cumple: 'SI',
        ),
      ];
    }

    _reordenarMuestras();
    _reordenarChecklist();
  }

  String _generarId() {
    final now = DateTime.now();
    return 'LAB-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}';
  }

  void _reordenarMuestras() {
    for (int i = 0; i < _muestras.length; i++) {
      _muestras[i].no = i + 1;
    }
  }

  void _reordenarChecklist() {
    for (int i = 0; i < _checklist.length; i++) {
      _checklist[i].ordenCtrl.text = '${i + 1}';
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _codigoCtrl.dispose();
    _versionCtrl.dispose();
    _vigenciaCtrl.dispose();
    _empresaClienteCtrl.dispose();
    _solicitanteCtrl.dispose();
    _proyectoInstalacionCtrl.dispose();
    _direccionCtrl.dispose();
    _fechaMuestreoCtrl.dispose();
    _fechaRecepcionCtrl.dispose();
    _horaRecepcionCtrl.dispose();
    _numeroCotizacionCtrl.dispose();
    _temperaturaCtrl.dispose();
    _nombreTecnicoCtrl.dispose();
    _totalMuestrasCtrl.dispose();
    _entregadoFirmaCtrl.dispose();
    _entregadoNombreCtrl.dispose();
    _entregadoFechaCtrl.dispose();
    _recibidoFirmaCtrl.dispose();
    _recibidoNombreCtrl.dispose();
    _recibidoFechaCtrl.dispose();
    _observacionesAdicionalesCtrl.dispose();

    for (final m in _muestras) {
      m.dispose();
    }
    for (final c in _checklist) {
      c.dispose();
    }

    super.dispose();
  }

  void _agregarMuestra() {
    setState(() {
      _muestras.add(MuestraFormItem(no: _muestras.length + 1));
      _reordenarMuestras();
    });
  }

  void _eliminarMuestra(int index) {
    if (_muestras.length <= 1) return;
    setState(() {
      _muestras[index].dispose();
      _muestras.removeAt(index);
      _reordenarMuestras();
    });
  }

  void _agregarChecklist() {
    setState(() {
      _checklist.add(
        ChecklistFormItem(
          orden: _checklist.length + 1,
          detalle: '',
          cumple: 'SI',
        ),
      );
      _reordenarChecklist();
    });
  }

  void _eliminarChecklist(int index) {
    if (_checklist.length <= 1) return;
    setState(() {
      _checklist[index].dispose();
      _checklist.removeAt(index);
      _reordenarChecklist();
    });
  }

  String? _validarFecha(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final regex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!regex.hasMatch(v)) return 'Usa formato MM/DD/YYYY';
    return null;
  }

  String? _validarHora(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final regex = RegExp(r'^\d{2}:\d{2}$');
    if (!regex.hasMatch(v)) return 'Usa formato HH:mm';
    final parts = v.split(':');
    final hh = int.tryParse(parts[0]) ?? -1;
    final mm = int.tryParse(parts[1]) ?? -1;
    if (hh < 0 || hh > 23 || mm < 0 || mm > 59) {
      return 'Hora inválida';
    }
    return null;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_formKey.currentState!.validate()) return;

    _reordenarMuestras();
    _reordenarChecklist();

    final currentVersion = int.tryParse(_versionCtrl.text.trim()) ?? 1;
    final nextVersion = isEdit ? currentVersion + 1 : currentVersion;
    final now = FieldValue.serverTimestamp();

    final data = <String, dynamic>{
      'id': _idCtrl.text.trim(),
      'estado': 'Activo',
      'updatedAt': now,
      'encabezado': {
        'codigo': _codigoCtrl.text.trim(),
        'version': '$nextVersion',
        'vigencia': _vigenciaCtrl.text.trim(),
      },
      'informacionGeneralCliente': {
        'empresaCliente': _empresaClienteCtrl.text.trim(),
        'solicitante': _solicitanteCtrl.text.trim(),
        'proyectoInstalacion': _proyectoInstalacionCtrl.text.trim(),
        'direccion': _direccionCtrl.text.trim(),
      },
      'datosGenerales': {
        'fechaMuestreo': _fechaMuestreoCtrl.text.trim(),
        'fechaRecepcionMuestra': _fechaRecepcionCtrl.text.trim(),
        'horaRecepcionMuestra': _horaRecepcionCtrl.text.trim(),
        'numeroCotizacion': _numeroCotizacionCtrl.text.trim(),
        'temperaturaRecipiente': _temperaturaCtrl.text.trim(),
        'temperaturaNoAplica': _temperaturaNoAplica,
        'muestreoPorQuimisol': _muestreoPorQuimisol,
        'nombreTecnico': _nombreTecnicoCtrl.text.trim(),
        'muestraTomadaPorCliente': _muestraTomadaPorCliente,
      },
      'descripcionMuestras': {
        'tiposMuestraReferencia': const [
          'AP = Agua Potable',
          'AC = Agua de consumo',
          'ARD = Agua Residual Doméstica',
          'ARI = Agua residual Industrial',
          'AB = Agua Subterránea',
          'AS = Agua Superficial',
          'S = Suelo',
          'Z = Cenizas',
          'L = Líquida',
        ],
        'tiposEnvaseReferencia': const [
          'P = Plástico',
          'V = Vidrio',
          'VA = Vidrio Ámbar',
          'VB = Vidrio Bacteriológico',
          'B = Bolsa plástica',
        ],
        'muestras': _muestras.map((e) => e.toMap()).toList(),
      },
      'informacionMuestras': {
        'items': _checklist.map((e) => e.toMap()).toList(),
        'totalMuestrasEntregadas': _totalMuestrasCtrl.text.trim(),
      },
      'recepcion': {
        'entregadoPor': {
          'firma': _entregadoFirmaCtrl.text.trim(),
          'nombre': _entregadoNombreCtrl.text.trim(),
          'fecha': _entregadoFechaCtrl.text.trim(),
        },
        'recibidoPor': {
          'firma': _recibidoFirmaCtrl.text.trim(),
          'nombre': _recibidoNombreCtrl.text.trim(),
          'fecha': _recibidoFechaCtrl.text.trim(),
        },
        'observacionesAdicionales':
            _observacionesAdicionalesCtrl.text.trim(),
      },
    };

    if (!isEdit) {
      data['createdAt'] = now;
    }

    setState(() => _guardando = true);

    try {
      if (isEdit) {
        final docId = _firestoreId;
        if (docId == null || docId.isEmpty) {
          throw Exception('No se encontró el documento a editar.');
        }
        await _laboratoriosRef.doc(docId).update(data);
      } else {
        await _laboratoriosRef.add(data);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Formulario actualizado correctamente'
                : 'Formulario registrado correctamente',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isMobile = c.maxWidth < 950;

        return Scaffold(
          backgroundColor: Palette.fieldBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.white,
            title: Text(
              isEdit ? 'Editar formulario' : 'Nuevo formulario',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: _guardando ? null : _guardar,
                  icon: _guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.button,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 12 : 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Column(
                      children: [
                        _sectionCard(
                          title: 'Cabecera del documento',
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _field(_codigoCtrl, 'Código', width: 220),
                              _readOnlyField(_versionCtrl, 'Versión', width: 160),
                              _field(_vigenciaCtrl, 'Vigencia', width: 180),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'I. Información general del cliente',
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _field(
                                _empresaClienteCtrl,
                                'Empresa / Cliente',
                                width: isMobile ? double.infinity : 360,
                                requiredField: true,
                              ),
                              _field(
                                _solicitanteCtrl,
                                'Solicitante',
                                width: isMobile ? double.infinity : 360,
                                requiredField: true,
                              ),
                              _field(
                                _proyectoInstalacionCtrl,
                                'Proyecto / Instalación',
                                width: isMobile ? double.infinity : 360,
                              ),
                              _field(
                                _direccionCtrl,
                                'Dirección',
                                width: isMobile ? double.infinity : 360,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'II. Datos generales',
                          child: Column(
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _field(
                                    _fechaMuestreoCtrl,
                                    'Fecha de muestreo',
                                    width: 220,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      DateTextInputFormatter(),
                                    ],
                                    keyboardType: TextInputType.number,
                                    validator: _validarFecha,
                                  ),
                                  _field(
                                    _fechaRecepcionCtrl,
                                    'Fecha de recepción de muestra',
                                    width: 260,
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
                                      return _validarFecha(v);
                                    },
                                  ),
                                  _field(
                                    _horaRecepcionCtrl,
                                    'Hora de recepción de muestra',
                                    width: 220,
                                    requiredField: true,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      TimeTextInputFormatter(),
                                    ],
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Requerido';
                                      }
                                      return _validarHora(v);
                                    },
                                  ),
                                  _field(
                                    _numeroCotizacionCtrl,
                                    'Número de cotización',
                                    width: 220,
                                  ),
                                  _field(
                                    _temperaturaCtrl,
                                    'Temperatura del recipiente de la muestra (°C)',
                                    width: isMobile ? double.infinity : 320,
                                  ),
                                  _field(
                                    _nombreTecnicoCtrl,
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
                                    value: _temperaturaNoAplica,
                                    onChanged: (v) {
                                      setState(() {
                                        _temperaturaNoAplica = v ?? false;
                                      });
                                    },
                                    title: const Text('No aplica'),
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  CheckboxListTile(
                                    dense: true,
                                    value: _muestreoPorQuimisol,
                                    onChanged: (v) {
                                      setState(() {
                                        _muestreoPorQuimisol = v ?? false;
                                      });
                                    },
                                    title: const Text('Muestreo por QUIMISOL'),
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                  CheckboxListTile(
                                    dense: true,
                                    value: _muestraTomadaPorCliente,
                                    onChanged: (v) {
                                      setState(() {
                                        _muestraTomadaPorCliente = v ?? false;
                                      });
                                    },
                                    title:
                                        const Text('Muestra tomada por cliente'),
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
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
                              ...List.generate(_muestras.length, (index) {
                                final item = _muestras[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Palette.fieldBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Palette.primary.withValues(
                                        alpha: 0.08,
                                      ),
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
                                          if (_muestras.length > 1)
                                            IconButton(
                                              onPressed: () =>
                                                  _eliminarMuestra(index),
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
                                          _field(
                                            item.codigoMuestraCtrl,
                                            'Códigos de muestras',
                                            width: isMobile
                                                ? double.infinity
                                                : 260,
                                            requiredField: true,
                                            maxLines: 2,
                                          ),
                                          _dropdownField<String>(
                                            label: 'Tipo muestra',
                                            value: _safeDropdownValue(
                                              item.tipoMuestra,
                                              _tiposMuestra,
                                            ),
                                            width: 180,
                                            items: _tiposMuestra,
                                            onChanged: (v) {
                                              setState(() {
                                                item.tipoMuestra = v;
                                              });
                                            },
                                          ),
                                          _field(
                                            item.cantidadCtrl,
                                            'Cantidad',
                                            width: 150,
                                          ),
                                          _field(
                                            item.volumenPesoCtrl,
                                            'Volumen / Peso',
                                            width: 180,
                                          ),
                                          _dropdownField<String>(
                                            label: 'Tipo envase',
                                            value: _safeDropdownValue(
                                              item.tipoEnvase,
                                              _tiposEnvase,
                                            ),
                                            width: 180,
                                            items: _tiposEnvase,
                                            onChanged: (v) {
                                              setState(() {
                                                item.tipoEnvase = v;
                                              });
                                            },
                                          ),
                                          _field(
                                            item.descripcionCtrl,
                                            'Descripción',
                                            width: isMobile
                                                ? double.infinity
                                                : 320,
                                          ),
                                          _field(
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
                                  onPressed: _agregarMuestra,
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
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'IV. Información de las muestras',
                          child: Column(
                            children: [
                              ...List.generate(_checklist.length, (index) {
                                final item = _checklist[index];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Palette.fieldBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Palette.primary.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Información ${index + 1}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (_checklist.length > 1)
                                            IconButton(
                                              onPressed: () =>
                                                  _eliminarChecklist(index),
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
                                          _field(
                                            item.detalleCtrl,
                                            'Detalle',
                                            width: isMobile
                                                ? double.infinity
                                                : 520,
                                            maxLines: 2,
                                          ),
                                          _dropdownField<String>(
                                            label: 'Cumple',
                                            value: _safeDropdownValue(
                                              item.cumple,
                                              _cumpleOptions,
                                            ),
                                            width: 180,
                                            items: _cumpleOptions,
                                            onChanged: (v) {
                                              setState(() {
                                                item.cumple = v;
                                              });
                                            },
                                          ),
                                          _field(
                                            item.observacionesCtrl,
                                            'Observaciones',
                                            width: isMobile
                                                ? double.infinity
                                                : 320,
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
                                  onPressed: _agregarChecklist,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text(
                                    'Agregar información de muestras',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Palette.primary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _field(
                                _totalMuestrasCtrl,
                                'Total de muestras entregadas',
                                width: 220,
                                requiredField: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        _sectionCard(
                          title: 'V. Recepción',
                          child: Column(
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _miniGroup(
                                    title: 'Entregado por',
                                    children: [
                                      _field(
                                        _entregadoFirmaCtrl,
                                        'Firma',
                                        width: double.infinity,
                                      ),
                                      _field(
                                        _entregadoNombreCtrl,
                                        'Nombre',
                                        width: double.infinity,
                                        requiredField: true,
                                      ),
                                      _field(
                                        _entregadoFechaCtrl,
                                        'Fecha',
                                        width: double.infinity,
                                        requiredField: true,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          DateTextInputFormatter(),
                                        ],
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Requerido';
                                          }
                                          return _validarFecha(v);
                                        },
                                      ),
                                    ],
                                  ),
                                  _miniGroup(
                                    title: 'Recibido por',
                                    children: [
                                      _field(
                                        _recibidoFirmaCtrl,
                                        'Firma',
                                        width: double.infinity,
                                      ),
                                      _field(
                                        _recibidoNombreCtrl,
                                        'Nombre',
                                        width: double.infinity,
                                        requiredField: true,
                                      ),
                                      _field(
                                        _recibidoFechaCtrl,
                                        'Fecha',
                                        width: double.infinity,
                                        requiredField: true,
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                          DateTextInputFormatter(),
                                        ],
                                        keyboardType: TextInputType.number,
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Requerido';
                                          }
                                          return _validarFecha(v);
                                        },
                                      ),
                                    ],
                                  ),
                                  _miniGroup(
                                    title: 'Observaciones adicionales',
                                    children: [
                                      _field(
                                        _observacionesAdicionalesCtrl,
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
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _guardando
                                    ? null
                                    : () => Navigator.pop(context),
                                icon: const Icon(Icons.arrow_back_rounded),
                                label: const Text('Cancelar'),
                                style: OutlinedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _guardando ? null : _guardar,
                                icon: _guardando
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: Text(
                                  _guardando
                                      ? 'Guardando...'
                                      : (isEdit
                                            ? 'Guardar cambios'
                                            : 'Registrar'),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Palette.button,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  T? _safeDropdownValue<T>(T? value, List<T> items) {
    if (value == null) return null;
    return items.contains(value) ? value : null;
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.black.withValues(alpha: 0.62),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _miniGroup({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Palette.primary.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ...children.expand((e) => [e, const SizedBox(height: 10)]).toList()
            ..removeLast(),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    double width = 260,
    bool requiredField = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: width == double.infinity ? null : width,
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator ??
            (requiredField
                ? (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  }
                : null),
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Palette.primary.withValues(alpha: 0.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Palette.button.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _readOnlyField(
    TextEditingController controller,
    String label, {
    double width = 260,
  }) {
    return SizedBox(
      width: width == double.infinity ? null : width,
      child: TextFormField(
        controller: controller,
        readOnly: true,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Palette.primary.withValues(alpha: 0.12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    double width = 220,
  }) {
    final safeValue = items.contains(value) ? value : null;

    return SizedBox(
      width: width,
      child: DropdownButtonFormField<T>(
        value: safeValue,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Palette.primary.withValues(alpha: 0.12),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Palette.button.withValues(alpha: 0.45),
              width: 1.2,
            ),
          ),
        ),
        items: items
            .toSet()
            .map(
              (e) => DropdownMenuItem<T>(
                value: e,
                child: Text(e.toString()),
              ),
            )
            .toList(),
      ),
    );
  }
}

class MuestraFormItem {
  int no;
  final TextEditingController codigoMuestraCtrl;
  final TextEditingController cantidadCtrl;
  final TextEditingController volumenPesoCtrl;
  final TextEditingController descripcionCtrl;
  final TextEditingController numeroLaboratorioCtrl;
  String? tipoMuestra;
  String? tipoEnvase;

  MuestraFormItem({
    required this.no,
    String codigoMuestra = '',
    String cantidad = '',
    String volumenPeso = '',
    String descripcion = '',
    String numeroLaboratorio = '',
    this.tipoMuestra,
    this.tipoEnvase,
  })  : codigoMuestraCtrl = TextEditingController(text: codigoMuestra),
        cantidadCtrl = TextEditingController(text: cantidad),
        volumenPesoCtrl = TextEditingController(text: volumenPeso),
        descripcionCtrl = TextEditingController(text: descripcion),
        numeroLaboratorioCtrl = TextEditingController(text: numeroLaboratorio);

  factory MuestraFormItem.fromMap(
    Map<String, dynamic> map, {
    required List<String> tiposMuestraValidos,
    required List<String> tiposEnvaseValidos,
  }) {
    final tipoMuestraRaw = map['tipoMuestra']?.toString().trim();
    final tipoEnvaseRaw = map['tipoEnvase']?.toString().trim();

    return MuestraFormItem(
      no: (map['no'] ?? 1) as int,
      codigoMuestra: (map['codigoMuestra'] ?? '').toString(),
      cantidad: (map['cantidad'] ?? '').toString(),
      volumenPeso: (map['volumenPeso'] ?? '').toString(),
      descripcion: (map['descripcion'] ?? '').toString(),
      numeroLaboratorio: (map['numeroLaboratorio'] ?? '').toString(),
      tipoMuestra: tiposMuestraValidos.contains(tipoMuestraRaw)
          ? tipoMuestraRaw
          : null,
      tipoEnvase:
          tiposEnvaseValidos.contains(tipoEnvaseRaw) ? tipoEnvaseRaw : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'no': no,
      'codigoMuestra': codigoMuestraCtrl.text.trim(),
      'tipoMuestra': tipoMuestra ?? '',
      'cantidad': cantidadCtrl.text.trim(),
      'volumenPeso': volumenPesoCtrl.text.trim(),
      'tipoEnvase': tipoEnvase ?? '',
      'descripcion': descripcionCtrl.text.trim(),
      'numeroLaboratorio': numeroLaboratorioCtrl.text.trim(),
    };
  }

  void dispose() {
    codigoMuestraCtrl.dispose();
    cantidadCtrl.dispose();
    volumenPesoCtrl.dispose();
    descripcionCtrl.dispose();
    numeroLaboratorioCtrl.dispose();
  }
}

class ChecklistFormItem {
  final TextEditingController ordenCtrl;
  final TextEditingController detalleCtrl;
  final TextEditingController observacionesCtrl;
  String? cumple;

  ChecklistFormItem({
    int orden = 1,
    String detalle = '',
    this.cumple,
    String observaciones = '',
  })  : ordenCtrl = TextEditingController(text: '$orden'),
        detalleCtrl = TextEditingController(text: detalle),
        observacionesCtrl = TextEditingController(text: observaciones);

  factory ChecklistFormItem.fromMap(
    Map<String, dynamic> map, {
    required List<String> cumpleValidos,
  }) {
    final cumpleRaw = map['cumple']?.toString().trim();

    return ChecklistFormItem(
      orden: int.tryParse((map['orden'] ?? '1').toString()) ?? 1,
      detalle: (map['detalle'] ?? '').toString(),
      cumple: cumpleValidos.contains(cumpleRaw) ? cumpleRaw : null,
      observaciones: (map['observaciones'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orden': int.tryParse(ordenCtrl.text.trim()) ?? 0,
      'detalle': detalleCtrl.text.trim(),
      'cumple': cumple ?? '',
      'observaciones': observacionesCtrl.text.trim(),
    };
  }

  void dispose() {
    ordenCtrl.dispose();
    detalleCtrl.dispose();
    observacionesCtrl.dispose();
  }
}

class DateTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 8; i++) {
      buffer.write(digits[i]);
      if ((i == 1 || i == 3) && i != digits.length - 1) {
        buffer.write('/');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class TimeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length && i < 4; i++) {
      buffer.write(digits[i]);
      if (i == 1 && i != digits.length - 1) {
        buffer.write(':');
      }
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}