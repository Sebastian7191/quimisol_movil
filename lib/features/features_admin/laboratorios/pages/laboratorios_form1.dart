import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/cliente_mayorista_option.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/formulario1_models.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form1/form_parte1.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form1/form_parte2.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form1/form_parte3.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form1/form_parte4.dart';

class FormulariosForm1Page extends StatefulWidget {
  final String? idPadre;
  final Map<String, dynamic>? initialData;

  const FormulariosForm1Page({
    super.key,
    this.idPadre,
    this.initialData,
  });

  @override
  State<FormulariosForm1Page> createState() => _FormulariosForm1PageState();
}

class _FormulariosForm1PageState extends State<FormulariosForm1Page> {
  final _formKey = GlobalKey<FormState>();

  final CollectionReference<Map<String, dynamic>> _laboratoriosRef =
      FirebaseFirestore.instance.collection('laboratorios');

  bool _guardando = false;

  bool get isEdit => widget.initialData != null;

  late final TextEditingController _idCtrl;

  // Parte 1
  late final TextEditingController _registroCtrl;
  late final TextEditingController _solicitadoPorCtrl;
  late final TextEditingController _areaSolicitanteCtrl;
  late final TextEditingController _tipoServicioCtrl;

  // Clientes mayoristas
  List<ClienteMayoristaOption> _clientesMayoristas = [];
  String? _clienteMayoristaSeleccionadoId;
  bool _cargandoClientesMayoristas = true;

  // Parte 2
  List<Formulario1DetalleItem> _detalleItems = [];

  // Parte 3
  List<Formulario1CriterioItem> _criterios = [];
  late final TextEditingController _responsableSolicitudNombreCtrl;
  late final TextEditingController _responsableSolicitudCargoCtrl;
  late final TextEditingController _responsableSolicitudFirmaCtrl;

  late final TextEditingController _responsableAprobacionNombreCtrl;
  late final TextEditingController _responsableAprobacionCargoCtrl;
  late final TextEditingController _responsableAprobacionFirmaCtrl;

  // Parte 4
  List<Formulario1EvaluacionItem> _evaluacion = [];

  String get _idPadreFinal {
    final fromWidget = widget.idPadre?.trim();
    final fromData = widget.initialData?['id']?.toString().trim();

    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    if (fromData != null && fromData.isNotEmpty) return fromData;

    return _generarId();
  }

  @override
  void initState() {
    super.initState();

    final data = widget.initialData ?? {};

    final datosGenerales = Map<String, dynamic>.from(
      data['datosGenerales'] ?? {},
    );

    final detalleMuestras = Map<String, dynamic>.from(
      data['detalleMuestras'] ?? {},
    );

    final criteriosYResponsables = Map<String, dynamic>.from(
      data['criteriosYResponsables'] ?? {},
    );

    final evaluacionServicio = Map<String, dynamic>.from(
      data['evaluacionServicio'] ?? {},
    );

    final responsableSolicitud = Map<String, dynamic>.from(
      criteriosYResponsables['responsableSolicitud'] ?? {},
    );

    final responsableAprobacion = Map<String, dynamic>.from(
      criteriosYResponsables['responsableAprobacion'] ?? {},
    );

    _idCtrl = TextEditingController(text: _idPadreFinal);

    // Parte 1
    _registroCtrl = TextEditingController(
      text: (datosGenerales['registro'] ?? '').toString(),
    );
    _solicitadoPorCtrl = TextEditingController(
      text: (datosGenerales['solicitadoPor'] ?? '').toString(),
    );
    _areaSolicitanteCtrl = TextEditingController(
      text: (datosGenerales['areaSolicitante'] ?? '').toString(),
    );
    _tipoServicioCtrl = TextEditingController(
      text: (datosGenerales['tipoServicio'] ?? '').toString(),
    );

    // Parte 2
    final detalleItemsData = (detalleMuestras['items'] as List?) ?? [];
    if (detalleItemsData.isNotEmpty) {
      _detalleItems = detalleItemsData
          .map(
            (e) => Formulario1DetalleItem.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } else {
      _detalleItems = [
        Formulario1DetalleItem(item: 1),
      ];
    }

    // Parte 3
    final criteriosData =
        (criteriosYResponsables['criteriosAceptacion'] as List?) ?? [];
    if (criteriosData.isNotEmpty) {
      _criterios = criteriosData
          .map(
            (e) => Formulario1CriterioItem.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } else {
      _criterios = [
        Formulario1CriterioItem(
          criterio: 'Especificaciones Técnicas según TL-FR-126',
          respuesta: '',
        ),
        Formulario1CriterioItem(
          criterio: 'Documentación de Respaldo / Certificados / Etc.',
          respuesta: '',
        ),
        Formulario1CriterioItem(
          criterio: 'Fechas Caducidad',
          respuesta: '',
        ),
      ];
    }

    _responsableSolicitudNombreCtrl = TextEditingController(
      text: (responsableSolicitud['nombre'] ?? '').toString(),
    );
    _responsableSolicitudCargoCtrl = TextEditingController(
      text: (responsableSolicitud['cargo'] ?? '').toString(),
    );
    _responsableSolicitudFirmaCtrl = TextEditingController(
      text: (responsableSolicitud['firma'] ?? '').toString(),
    );

    _responsableAprobacionNombreCtrl = TextEditingController(
      text: (responsableAprobacion['nombre'] ?? '').toString(),
    );
    _responsableAprobacionCargoCtrl = TextEditingController(
      text: (responsableAprobacion['cargo'] ?? '').toString(),
    );
    _responsableAprobacionFirmaCtrl = TextEditingController(
      text: (responsableAprobacion['firma'] ?? '').toString(),
    );

    // Parte 4
    final evaluacionData = (evaluacionServicio['preguntas'] as List?) ?? [];
    if (evaluacionData.isNotEmpty) {
      _evaluacion = evaluacionData
          .map(
            (e) => Formulario1EvaluacionItem.fromMap(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
    } else {
      _evaluacion = [
        Formulario1EvaluacionItem(
          pregunta:
              'El servicio o producto cumplió con las expectativas por el que fue solicitado',
          respuesta: '',
        ),
        Formulario1EvaluacionItem(
          pregunta:
              'El servicio o producto cumplió con las especificaciones de solicitud',
          respuesta: '',
        ),
        Formulario1EvaluacionItem(
          pregunta:
              'Las condiciones de entrega del servicio o producto son aceptables para su recepción',
          respuesta: '',
        ),
        Formulario1EvaluacionItem(
          pregunta:
              'El servicio o producto cumplió con las exigencias de calidad de TENTA LAB SRL',
          respuesta: '',
        ),
      ];
    }

    _reordenarDetalleItems();
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
      final solicitadoActual = _solicitadoPorCtrl.text.trim();

      if (solicitadoActual.isNotEmpty) {
        for (final item in items) {
          if (item.nombre == solicitadoActual) {
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
      _solicitadoPorCtrl.text = nombre;
    });
  }

  void _reordenarDetalleItems() {
    for (int i = 0; i < _detalleItems.length; i++) {
      _detalleItems[i].item = i + 1;
    }
  }

  void _agregarDetalleItem() {
    setState(() {
      _detalleItems.add(Formulario1DetalleItem(item: _detalleItems.length + 1));
      _reordenarDetalleItems();
    });
  }

  void _eliminarDetalleItem(int index) {
    if (_detalleItems.length <= 1) return;
    setState(() {
      _detalleItems[index].dispose();
      _detalleItems.removeAt(index);
      _reordenarDetalleItems();
    });
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _guardando = true);

    try {
      final idPadre = _idCtrl.text.trim();

      final parentRef = _laboratoriosRef.doc(idPadre);
      final form1Ref = parentRef.collection('formulario_1').doc('data');
      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        'id': idPadre,
        'formulario': 'formulario_1',
        'estado': 'Activo',
        'updatedAt': now,
        if (!isEdit) 'createdAt': now,
        'datosGenerales': {
          'registro': _registroCtrl.text.trim(),
          'solicitadoPor': _solicitadoPorCtrl.text.trim(),
          'areaSolicitante': _areaSolicitanteCtrl.text.trim(),
          'tipoServicio': _tipoServicioCtrl.text.trim(),
        },
        'detalleMuestras': {
          'items': _detalleItems.map((e) => e.toMap()).toList(),
        },
        'criteriosYResponsables': {
          'criteriosAceptacion': _criterios.map((e) => e.toMap()).toList(),
          'responsableSolicitud': {
            'nombre': _responsableSolicitudNombreCtrl.text.trim(),
            'cargo': _responsableSolicitudCargoCtrl.text.trim(),
            'firma': _responsableSolicitudFirmaCtrl.text.trim(),
          },
          'responsableAprobacion': {
            'nombre': _responsableAprobacionNombreCtrl.text.trim(),
            'cargo': _responsableAprobacionCargoCtrl.text.trim(),
            'firma': _responsableAprobacionFirmaCtrl.text.trim(),
          },
        },
        'evaluacionServicio': {
          'preguntas': _evaluacion.map((e) => e.toMap()).toList(),
        },
        'metadata': {
          'codigoFormulario': 'TL-FR-69',
          'titulo': 'Solicitud y recepción de Servicios Externos',
          'version': '07',
          'vigenteDesde': '2024-08-26',
          'pagina': '1 de 2',
        },
      };

      await parentRef.set({
        'id': idPadre,
        'tipo': 'laboratorio',
        'updatedAt': now,
        if (!isEdit) 'createdAt': now,
      }, SetOptions(merge: true));

      await form1Ref.set(data, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Formulario 1 actualizado correctamente'
                : 'Formulario 1 guardado correctamente',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _guardando = false);
      }
    }
  }

  @override
  void dispose() {
    _idCtrl.dispose();

    _registroCtrl.dispose();
    _solicitadoPorCtrl.dispose();
    _areaSolicitanteCtrl.dispose();
    _tipoServicioCtrl.dispose();

    for (final item in _detalleItems) {
      item.dispose();
    }

    for (final item in _criterios) {
      item.dispose();
    }

    _responsableSolicitudNombreCtrl.dispose();
    _responsableSolicitudCargoCtrl.dispose();
    _responsableSolicitudFirmaCtrl.dispose();

    _responsableAprobacionNombreCtrl.dispose();
    _responsableAprobacionCargoCtrl.dispose();
    _responsableAprobacionFirmaCtrl.dispose();

    for (final item in _evaluacion) {
      item.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isMobile = c.maxWidth < 900;

        return Scaffold(
          backgroundColor: Palette.fieldBg,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black87),
            title: Text(
              isEdit
                  ? 'Editar Formulario Solicitud'
                  : 'Nuevo Formulario Solicitud',
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
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
                        Formulario1Parte1(
                          isMobile: isMobile,
                          registroCtrl: _registroCtrl,
                          solicitadoPorCtrl: _solicitadoPorCtrl,
                          areaSolicitanteCtrl: _areaSolicitanteCtrl,
                          tipoServicioCtrl: _tipoServicioCtrl,
                          clientesMayoristas: _clientesMayoristas,
                          clienteSeleccionadoId:
                              _clienteMayoristaSeleccionadoId,
                          cargandoClientesMayoristas:
                              _cargandoClientesMayoristas,
                          onClienteChanged: _onClienteMayoristaChanged,
                        ),
                        const SizedBox(height: 14),
                        Formulario1Parte2(
                          isMobile: isMobile,
                          items: _detalleItems,
                          onAgregarItem: _agregarDetalleItem,
                          onEliminarItem: _eliminarDetalleItem,
                        ),
                        const SizedBox(height: 14),
                        Formulario1Parte3(
                          isMobile: isMobile,
                          criterios: _criterios,
                          responsableSolicitudNombreCtrl:
                              _responsableSolicitudNombreCtrl,
                          responsableSolicitudCargoCtrl:
                              _responsableSolicitudCargoCtrl,
                          responsableSolicitudFirmaCtrl:
                              _responsableSolicitudFirmaCtrl,
                          responsableAprobacionNombreCtrl:
                              _responsableAprobacionNombreCtrl,
                          responsableAprobacionCargoCtrl:
                              _responsableAprobacionCargoCtrl,
                          responsableAprobacionFirmaCtrl:
                              _responsableAprobacionFirmaCtrl,
                          onRespuestaCriterioChanged: (index, value) {
                            setState(() {
                              _criterios[index].respuesta = value;
                            });
                          },
                        ),
                        const SizedBox(height: 14),
                        Formulario1Parte4(
                          isMobile: isMobile,
                          evaluaciones: _evaluacion,
                          onRespuestaEvaluacionChanged: (index, value) {
                            setState(() {
                              _evaluacion[index].respuesta = value;
                            });
                          },
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