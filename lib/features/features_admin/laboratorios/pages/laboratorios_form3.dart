import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/cliente_mayorista_option.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/models/laboratorios3_models.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form3/form_parte1.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form3/form_parte2.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form3/form_parte3.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/widgets/laboratorios_form3/form_parte4.dart';

class FormulariosForm3Page extends StatefulWidget {
  final String? idPadre;
  final Map<String, dynamic>? initialData;

  const FormulariosForm3Page({super.key, this.idPadre, this.initialData});

  @override
  State<FormulariosForm3Page> createState() => _FormulariosForm3PageState();
}

class _FormulariosForm3PageState extends State<FormulariosForm3Page> {
  final _formKey = GlobalKey<FormState>();

  final CollectionReference<Map<String, dynamic>> _laboratoriosRef =
      FirebaseFirestore.instance.collection('laboratorios');

  bool _saving = false;

  // Parte 1 · Información del cliente
  late final TextEditingController clienteCtrl;
  late final TextEditingController proyectoCtrl;
  late final TextEditingController atnCtrl;
  late final TextEditingController direccionCtrl;
  late final TextEditingController provinciaCtrl;
  late final TextEditingController departamentoCtrl;

  // Clientes mayoristas
  List<ClienteMayoristaOption> _clientesMayoristas = [];
  String? _clienteMayoristaSeleccionadoId;
  bool _cargandoClientesMayoristas = true;

  // Parte 2 · Información de la muestra
  late final TextEditingController identificacionLaboratorioCtrl;
  late final TextEditingController codigoClienteCtrl;
  late final TextEditingController tipoMuestraMatrizCtrl;
  late final TextEditingController fechaRecepcionCtrl;
  late final TextEditingController fechaEntregaCtrl;

  // Parte 3 · Información del muestreo
  late final TextEditingController lugarMuestreoCtrl;
  late final TextEditingController fechaMuestreoCtrl;
  late final TextEditingController horaMuestreoCtrl;
  late final TextEditingController condicionesClimaticasCtrl;
  late final TextEditingController temperaturaAmbienteCtrl;
  late final TextEditingController responsableMuestreoCtrl;
  late final TextEditingController observacionesCtrl;
  late final TextEditingController coordenadasMuestreoCtrl;
  late final TextEditingController coordenadaXCtrl;
  late final TextEditingController coordenadaYCtrl;

  // Parte 4 · Resultados
  late List<Formulario3ResultadoItem> resultados;

  bool get _isEdit => widget.initialData != null;

  String get _idPadreFinal {
    final fromWidget = widget.idPadre?.trim();
    final fromDataParent = widget.initialData?['parentId']?.toString().trim();
    final fromDataId = widget.initialData?['id']?.toString().trim();

    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;
    if (fromDataParent != null && fromDataParent.isNotEmpty) {
      return fromDataParent;
    }
    if (fromDataId != null && fromDataId.isNotEmpty) return fromDataId;

    return _generarId();
  }

  @override
  void initState() {
    super.initState();

    final data = widget.initialData ?? {};
    final parte1 = _asMap(data['parte1InformacionCliente']);
    final parte2 = _asMap(data['parte2InformacionMuestra']);
    final parte3 = _asMap(data['parte3InformacionMuestreo']);
    final rawResultados = (data['parte4ResultadosEnsayo'] as List?) ?? [];

    clienteCtrl = TextEditingController(
      text: (parte1['cliente'] ?? '').toString(),
    );
    proyectoCtrl = TextEditingController(
      text: (parte1['proyecto'] ?? '').toString(),
    );
    atnCtrl = TextEditingController(text: (parte1['atn'] ?? '').toString());
    direccionCtrl = TextEditingController(
      text: (parte1['direccion'] ?? '').toString(),
    );
    provinciaCtrl = TextEditingController(
      text: (parte1['provincia'] ?? '').toString(),
    );
    departamentoCtrl = TextEditingController(
      text: (parte1['departamento'] ?? '').toString(),
    );

    identificacionLaboratorioCtrl = TextEditingController(
      text: (parte2['identificacionLaboratorio'] ?? '').toString(),
    );
    codigoClienteCtrl = TextEditingController(
      text: (parte2['codigoCliente'] ?? '').toString(),
    );
    tipoMuestraMatrizCtrl = TextEditingController(
      text: (parte2['tipoMuestraMatriz'] ?? '').toString(),
    );
    fechaRecepcionCtrl = TextEditingController(
      text: (parte2['fechaRecepcion'] ?? '').toString(),
    );
    fechaEntregaCtrl = TextEditingController(
      text: (parte2['fechaEntrega'] ?? '').toString(),
    );

    lugarMuestreoCtrl = TextEditingController(
      text: (parte3['lugarMuestreo'] ?? '').toString(),
    );
    fechaMuestreoCtrl = TextEditingController(
      text: (parte3['fechaMuestreo'] ?? '').toString(),
    );
    horaMuestreoCtrl = TextEditingController(
      text: (parte3['horaMuestreo'] ?? '').toString(),
    );
    condicionesClimaticasCtrl = TextEditingController(
      text: (parte3['condicionesClimaticas'] ?? '').toString(),
    );
    temperaturaAmbienteCtrl = TextEditingController(
      text: (parte3['temperaturaAmbiente'] ?? '').toString(),
    );
    responsableMuestreoCtrl = TextEditingController(
      text: (parte3['responsableMuestreo'] ?? '').toString(),
    );
    observacionesCtrl = TextEditingController(
      text: (parte3['observaciones'] ?? '').toString(),
    );
    coordenadasMuestreoCtrl = TextEditingController(
      text: (parte3['coordenadasMuestreo'] ?? '').toString(),
    );
    coordenadaXCtrl = TextEditingController(
      text: (parte3['x'] ?? '').toString(),
    );
    coordenadaYCtrl = TextEditingController(
      text: (parte3['y'] ?? '').toString(),
    );

    resultados = rawResultados.isNotEmpty
        ? rawResultados
              .whereType<Map>()
              .map(
                (e) => Formulario3ResultadoItem.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList()
        : [Formulario3ResultadoItem(item: 1)];

    _cargarClientesMayoristas();
  }

  String _generarId() {
    final now = DateTime.now();
    return 'LAB-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.millisecond.toString().padLeft(3, '0')}';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
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
      final clienteActual = clienteCtrl.text.trim();

      if (clienteActual.isNotEmpty) {
        for (final item in items) {
          if (item.nombre == clienteActual) {
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
      clienteCtrl.text = nombre;
    });
  }

  String? _validarFecha(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final regex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!regex.hasMatch(text)) {
      return 'Usa formato DD/MM/YYYY';
    }

    final parts = text.split('/');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) {
      return 'Fecha inválida';
    }

    try {
      final date = DateTime(year, month, day);
      if (date.day != day || date.month != month || date.year != year) {
        return 'Fecha inválida';
      }
    } catch (_) {
      return 'Fecha inválida';
    }

    return null;
  }

  String? _validarHora(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;

    final regex = RegExp(r'^\d{2}:\d{2}$');
    if (!regex.hasMatch(text)) {
      return 'Usa formato HH:MM';
    }

    final parts = text.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return 'Hora inválida';
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return 'Hora inválida';
    }

    return null;
  }

  void _agregarResultado() {
    setState(() {
      resultados.add(Formulario3ResultadoItem(item: resultados.length + 1));
    });
  }

  void _eliminarResultado(int index) {
    if (resultados.length == 1) return;

    setState(() {
      resultados[index].dispose();
      resultados.removeAt(index);

      for (int i = 0; i < resultados.length; i++) {
        resultados[i].item = i + 1;
      }
    });
  }

  Future<void> _guardar() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _saving = true);

    try {
      final idPadre = _idPadreFinal.trim();
      final parentRef = _laboratoriosRef.doc(idPadre);
      final form3Ref = parentRef.collection('formulario_3').doc('data');
      final now = FieldValue.serverTimestamp();

      final data = <String, dynamic>{
        'id': idPadre,
        'parentId': idPadre,
        'subDocId': 'data',
        'formulario': 'formulario_3',
        'estado': 'Activo',
        'updatedAt': now,
        if (!_isEdit) 'createdAt': now,
        'parte1InformacionCliente': {
          'cliente': clienteCtrl.text.trim(),
          'clienteId': _clienteMayoristaSeleccionadoId,
          'proyecto': proyectoCtrl.text.trim(),
          'atn': atnCtrl.text.trim(),
          'direccion': direccionCtrl.text.trim(),
          'provincia': provinciaCtrl.text.trim(),
          'departamento': departamentoCtrl.text.trim(),
        },
        'parte2InformacionMuestra': {
          'identificacionLaboratorio': identificacionLaboratorioCtrl.text
              .trim(),
          'codigoCliente': codigoClienteCtrl.text.trim(),
          'tipoMuestraMatriz': tipoMuestraMatrizCtrl.text.trim(),
          'fechaRecepcion': fechaRecepcionCtrl.text.trim(),
          'fechaEntrega': fechaEntregaCtrl.text.trim(),
        },
        'parte3InformacionMuestreo': {
          'lugarMuestreo': lugarMuestreoCtrl.text.trim(),
          'fechaMuestreo': fechaMuestreoCtrl.text.trim(),
          'horaMuestreo': horaMuestreoCtrl.text.trim(),
          'condicionesClimaticas': condicionesClimaticasCtrl.text.trim(),
          'temperaturaAmbiente': temperaturaAmbienteCtrl.text.trim(),
          'responsableMuestreo': responsableMuestreoCtrl.text.trim(),
          'observaciones': observacionesCtrl.text.trim(),
          'coordenadasMuestreo': coordenadasMuestreoCtrl.text.trim(),
          'x': coordenadaXCtrl.text.trim(),
          'y': coordenadaYCtrl.text.trim(),
        },
        'parte4ResultadosEnsayo': resultados.map((e) => e.toMap()).toList(),
      };

      await parentRef.set({
        'id': idPadre,
        'tipo': 'laboratorio',
        'updatedAt': now,
        if (!_isEdit) 'createdAt': now,
      }, SetOptions(merge: true));

      await form3Ref.set(data, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit ? 'Formulario 3 actualizado' : 'Formulario 3 guardado',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    clienteCtrl.dispose();
    proyectoCtrl.dispose();
    atnCtrl.dispose();
    direccionCtrl.dispose();
    provinciaCtrl.dispose();
    departamentoCtrl.dispose();

    identificacionLaboratorioCtrl.dispose();
    codigoClienteCtrl.dispose();
    tipoMuestraMatrizCtrl.dispose();
    fechaRecepcionCtrl.dispose();
    fechaEntregaCtrl.dispose();

    lugarMuestreoCtrl.dispose();
    fechaMuestreoCtrl.dispose();
    horaMuestreoCtrl.dispose();
    condicionesClimaticasCtrl.dispose();
    temperaturaAmbienteCtrl.dispose();
    responsableMuestreoCtrl.dispose();
    observacionesCtrl.dispose();
    coordenadasMuestreoCtrl.dispose();
    coordenadaXCtrl.dispose();
    coordenadaYCtrl.dispose();

    for (final item in resultados) {
      item.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;

    return Scaffold(
      backgroundColor: Palette.white,
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar Ensayo' : 'Nuevo Ensayo'),
        backgroundColor: Palette.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: _cargandoClientesMayoristas
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Formulario3Parte1(
                          isMobile: isMobile,
                          clienteCtrl: clienteCtrl,
                          proyectoCtrl: proyectoCtrl,
                          atnCtrl: atnCtrl,
                          direccionCtrl: direccionCtrl,
                          provinciaCtrl: provinciaCtrl,
                          departamentoCtrl: departamentoCtrl,
                          clientesMayoristas: _clientesMayoristas,
                          clienteSeleccionadoId:
                              _clienteMayoristaSeleccionadoId,
                          cargandoClientesMayoristas:
                              _cargandoClientesMayoristas,
                          onClienteChanged: _onClienteMayoristaChanged,
                        ),
                        const SizedBox(height: 16),
                        Formulario3Parte2(
                          isMobile: isMobile,
                          identificacionLaboratorioCtrl:
                              identificacionLaboratorioCtrl,
                          codigoClienteCtrl: codigoClienteCtrl,
                          tipoMuestraMatrizCtrl: tipoMuestraMatrizCtrl,
                          fechaRecepcionCtrl: fechaRecepcionCtrl,
                          fechaEntregaCtrl: fechaEntregaCtrl,
                          validarFecha: _validarFecha,
                        ),
                        const SizedBox(height: 16),
                        Formulario3Parte3(
                          isMobile: isMobile,
                          lugarMuestreoCtrl: lugarMuestreoCtrl,
                          fechaMuestreoCtrl: fechaMuestreoCtrl,
                          horaMuestreoCtrl: horaMuestreoCtrl,
                          condicionesClimaticasCtrl: condicionesClimaticasCtrl,
                          temperaturaAmbienteCtrl: temperaturaAmbienteCtrl,
                          responsableMuestreoCtrl: responsableMuestreoCtrl,
                          observacionesCtrl: observacionesCtrl,
                          coordenadasMuestreoCtrl: coordenadasMuestreoCtrl,
                          coordenadaXCtrl: coordenadaXCtrl,
                          coordenadaYCtrl: coordenadaYCtrl,
                          validarFecha: _validarFecha,
                          validarHora: _validarHora,
                        ),
                        const SizedBox(height: 16),
                        Formulario3Parte4(
                          isMobile: isMobile,
                          items: resultados,
                          onAgregarItem: _agregarResultado,
                          onEliminarItem: _eliminarResultado,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  side: BorderSide(color: Palette.primary),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _saving ? null : _guardar,
                                style: FilledButton.styleFrom(
                                  backgroundColor: Palette.button,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(_isEdit ? 'Actualizar' : 'Guardar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
