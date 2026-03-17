import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/cliente_mayorista_option.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/form_parte1.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/form_parte2.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/form_parte3.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/form_parte4.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/form_parte5.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form2/laboratorio_form_models.dart';

class LaboratorioFormPage extends StatefulWidget {
  final String? idPadre;
  final Map<String, dynamic>? initialData;

  const LaboratorioFormPage({
    super.key,
    this.idPadre,
    this.initialData,
  });

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

  String? get _parentDocId {
    final fromWidget = widget.idPadre?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;

    return widget.initialData?['parentId']?.toString() ??
        widget.initialData?['id']?.toString();
  }

  String get _subDocId => 'data';

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

  final List<String> _tiposEnvase = const ['P', 'V', 'VA', 'VB', 'B'];

  final List<String> _cumpleOptions = const ['SI', 'NO', 'N/A', '-'];

  List<ClienteMayoristaOption> _clientesMayoristas = [];
  String? _clienteMayoristaSeleccionadoId;
  bool _cargandoClientesMayoristas = true;

  @override
  void initState() {
    super.initState();

    final data = widget.initialData ?? {};

    final encabezado = Map<String, dynamic>.from(data['encabezado'] ?? {});
    final infoCliente = Map<String, dynamic>.from(
      data['informacionGeneralCliente'] ?? {},
    );
    final datosGenerales = Map<String, dynamic>.from(
      data['datosGenerales'] ?? {},
    );
    final descripcionMuestras = Map<String, dynamic>.from(
      data['descripcionMuestras'] ?? {},
    );
    final infoMuestras = Map<String, dynamic>.from(
      data['informacionMuestras'] ?? {},
    );
    final recepcion = Map<String, dynamic>.from(data['recepcion'] ?? {});
    final entregadoPor = Map<String, dynamic>.from(
      recepcion['entregadoPor'] ?? {},
    );
    final recibidoPor = Map<String, dynamic>.from(
      recepcion['recibidoPor'] ?? {},
    );

    _idCtrl = TextEditingController(
      text: (widget.idPadre ?? data['parentId'] ?? data['id'] ?? _generarId())
          .toString(),
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
    _muestraTomadaPorCliente =
        datosGenerales['muestraTomadaPorCliente'] == true;

    final muestrasData = (descripcionMuestras['muestras'] as List?) ?? [];
    if (muestrasData.isNotEmpty) {
      _muestras = muestrasData
          .map(
            (e) => MuestraFormItem.fromMap(
              Map<String, dynamic>.from(e),
              tiposMuestraValidos: _tiposMuestra,
              tiposEnvaseValidos: _tiposEnvase,
            ),
          )
          .toList();
    } else {
      _muestras = List.generate(2, (index) => MuestraFormItem(no: index + 1));
    }

    final checklistData = (infoMuestras['items'] as List?) ?? [];
    if (checklistData.isNotEmpty) {
      _checklist = checklistData
          .map(
            (e) => ChecklistFormItem.fromMap(
              Map<String, dynamic>.from(e),
              cumpleValidos: _cumpleOptions,
            ),
          )
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
    _cargarClientesMayoristas();
  }

  String _generarId() {
    final now = DateTime.now();
    return 'LAB-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}';
  }

  Future<void> _cargarClientesMayoristas() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('clientes_mayoristas')
          .get();

      final items = snap.docs.map((doc) {
        final data = doc.data();
        final nombre = (data['name'] ?? '').toString().trim();

        return ClienteMayoristaOption(
          id: doc.id,
          nombre: nombre.isEmpty ? 'Sin nombre' : nombre,
        );
      }).toList();

      String? selectedId;
      final empresaActual = _empresaClienteCtrl.text.trim();

      if (empresaActual.isNotEmpty) {
        for (final item in items) {
          if (item.nombre == empresaActual) {
            selectedId = item.id;
            break;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _clientesMayoristas = items;
        _clienteMayoristaSeleccionadoId = selectedId;
        _cargandoClientesMayoristas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clientesMayoristas = [];
        _clienteMayoristaSeleccionadoId = null;
        _cargandoClientesMayoristas = false;
      });
    }
  }

  void _onClienteMayoristaChanged(String? clienteId) {
    setState(() {
      _clienteMayoristaSeleccionadoId = clienteId;

      ClienteMayoristaOption? seleccionado;
      for (final item in _clientesMayoristas) {
        if (item.id == clienteId) {
          seleccionado = item;
          break;
        }
      }

      final nombre = seleccionado?.nombre ?? '';
      _empresaClienteCtrl.text = nombre;
      _solicitanteCtrl.text = nombre;
    });
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

    final parts = v.split('/');
    final mes = int.tryParse(parts[0]) ?? -1;
    final dia = int.tryParse(parts[1]) ?? -1;
    final anio = int.tryParse(parts[2]) ?? -1;

    if (mes < 1 || mes > 12) return 'Mes inválido';
    if (anio < 1 || anio > DateTime.now().year) return 'Año inválido';
    if (dia < 1) return 'Día inválido';

    final fecha = DateTime.tryParse(
      '${anio.toString().padLeft(4, '0')}-${mes.toString().padLeft(2, '0')}-${dia.toString().padLeft(2, '0')}',
    );

    if (fecha == null ||
        fecha.year != anio ||
        fecha.month != mes ||
        fecha.day != dia) {
      return 'Fecha inválida';
    }

    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    if (fecha.isAfter(hoySinHora)) {
      return 'La fecha no puede ser futura';
    }

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

    final parentId = (_parentDocId ?? _idCtrl.text.trim()).trim();
    if (parentId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo generar el id del formulario.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final subDocId = _subDocId;

    final data = <String, dynamic>{
      'id': parentId,
      'parentId': parentId,
      'subDocId': subDocId,
      'formulario': 'formulario_2',
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
        'observacionesAdicionales': _observacionesAdicionalesCtrl.text.trim(),
      },
      if (!isEdit) 'createdAt': now,
    };

    setState(() => _guardando = true);

    try {
      final parentRef = _laboratoriosRef.doc(parentId);
      final subRef = parentRef.collection('formulario_2').doc(subDocId);

      await parentRef.set({
        'id': parentRef.id,
        'tipo': 'laboratorio',
        'updatedAt': now,
        if (!isEdit) 'createdAt': now,
      }, SetOptions(merge: true));

      await subRef.set(data, SetOptions(merge: true));

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
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _guardando = false);
    }
  }

  T? _safeDropdownValue<T>(T? value, List<T> items) {
    if (value == null) return null;
    return items.contains(value) ? value : null;
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
              isEdit
                  ? 'Editar formulario Recepción'
                  : 'Nuevo formulario Recepción',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.black87),
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
                        FormParte1CabeceraCliente(
                          isMobile: isMobile,
                          codigoCtrl: _codigoCtrl,
                          versionCtrl: _versionCtrl,
                          vigenciaCtrl: _vigenciaCtrl,
                          empresaClienteCtrl: _empresaClienteCtrl,
                          solicitanteCtrl: _solicitanteCtrl,
                          proyectoInstalacionCtrl: _proyectoInstalacionCtrl,
                          direccionCtrl: _direccionCtrl,
                          clientesMayoristas: _clientesMayoristas,
                          clienteSeleccionadoId:
                              _clienteMayoristaSeleccionadoId,
                          cargandoClientesMayoristas:
                              _cargandoClientesMayoristas,
                          onClienteChanged: _onClienteMayoristaChanged,
                        ),
                        const SizedBox(height: 14),
                        FormParte2DatosGenerales(
                          isMobile: isMobile,
                          fechaMuestreoCtrl: _fechaMuestreoCtrl,
                          fechaRecepcionCtrl: _fechaRecepcionCtrl,
                          horaRecepcionCtrl: _horaRecepcionCtrl,
                          numeroCotizacionCtrl: _numeroCotizacionCtrl,
                          temperaturaCtrl: _temperaturaCtrl,
                          nombreTecnicoCtrl: _nombreTecnicoCtrl,
                          temperaturaNoAplica: _temperaturaNoAplica,
                          muestreoPorQuimisol: _muestreoPorQuimisol,
                          muestraTomadaPorCliente: _muestraTomadaPorCliente,
                          onTemperaturaNoAplicaChanged: (v) {
                            setState(() => _temperaturaNoAplica = v ?? false);
                          },
                          onMuestreoPorQuimisolChanged: (v) {
                            setState(() => _muestreoPorQuimisol = v ?? false);
                          },
                          onMuestraTomadaPorClienteChanged: (v) {
                            setState(
                              () => _muestraTomadaPorCliente = v ?? false,
                            );
                          },
                          validarFecha: _validarFecha,
                          validarHora: _validarHora,
                        ),
                        const SizedBox(height: 14),
                        FormParte3Muestras(
                          isMobile: isMobile,
                          muestras: _muestras,
                          tiposMuestra: _tiposMuestra,
                          tiposEnvase: _tiposEnvase,
                          safeDropdownValue: _safeDropdownValue,
                          onAgregarMuestra: _agregarMuestra,
                          onEliminarMuestra: _eliminarMuestra,
                          onTipoMuestraChanged: (item, value) {
                            setState(() => item.tipoMuestra = value);
                          },
                          onTipoEnvaseChanged: (item, value) {
                            setState(() => item.tipoEnvase = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        FormParte4InfoMuestras(
                          isMobile: isMobile,
                          checklist: _checklist,
                          cumpleOptions: _cumpleOptions,
                          totalMuestrasCtrl: _totalMuestrasCtrl,
                          safeDropdownValue: _safeDropdownValue,
                          onAgregarChecklist: _agregarChecklist,
                          onEliminarChecklist: _eliminarChecklist,
                          onCumpleChanged: (item, value) {
                            setState(() => item.cumple = value);
                          },
                        ),
                        const SizedBox(height: 14),
                        FormParte5Recepcion(
                          entregadoFirmaCtrl: _entregadoFirmaCtrl,
                          entregadoNombreCtrl: _entregadoNombreCtrl,
                          entregadoFechaCtrl: _entregadoFechaCtrl,
                          recibidoFirmaCtrl: _recibidoFirmaCtrl,
                          recibidoNombreCtrl: _recibidoNombreCtrl,
                          recibidoFechaCtrl: _recibidoFechaCtrl,
                          observacionesAdicionalesCtrl:
                              _observacionesAdicionalesCtrl,
                          validarFecha: _validarFecha,
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
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
}