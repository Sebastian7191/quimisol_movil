import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/pages/laboratorios_forms_switch_page.dart';

class LaboratoriosPage extends StatefulWidget {
  const LaboratoriosPage({super.key});

  @override
  State<LaboratoriosPage> createState() => _LaboratoriosPageState();
}

class _LaboratoriosPageState extends State<LaboratoriosPage> {
  final TextEditingController _searchCtrl = TextEditingController();

  final CollectionReference<Map<String, dynamic>> _laboratoriosRef =
      FirebaseFirestore.instance.collection('laboratorios');

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> items) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return items;

    return items.where((e) {
      final id = (e['id'] ?? '').toString().toLowerCase();
      final tipo = (e['tipo'] ?? '').toString().toLowerCase();
      return id.contains(q) || tipo.contains(q);
    }).toList();
  }

  Future<void> _crearNuevo() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LaboratoriosFormsSwitchPage(),
      ),
    );
  }

  Future<Map<String, dynamic>?> _readSubform(
    String parentId,
    String subcollection,
  ) async {
    try {
      final doc = await _laboratoriosRef
          .doc(parentId)
          .collection(subcollection)
          .doc('data')
          .get();

      if (!doc.exists) return null;
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _abrirSwitch(Map<String, dynamic> item) async {
    final parentId = (item['id'] ?? item['firestoreId'] ?? '').toString();
    if (parentId.isEmpty) return;

    final results = await Future.wait([
      _readSubform(parentId, 'formulario_1'),
      _readSubform(parentId, 'formulario_2'),
      _readSubform(parentId, 'formulario_3'),
    ]);

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LaboratoriosFormsSwitchPage(
          initialIndex: 0,
          initialDataForm1: results[0],
          initialDataForm2: results[1],
          initialDataForm3: results[2],
        ),
      ),
    );
  }

  Future<void> _eliminar(Map<String, dynamic> item) async {
    final firestoreId = (item['firestoreId'] ?? '').toString();
    if (firestoreId.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Eliminar laboratorio'),
          content: Text(
            '¿Deseas eliminar el registro ${item['id'] ?? firestoreId}?\n\n'
            'Esto eliminará solo el documento padre. Si tienes subcolecciones, deben limpiarse aparte.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    try {
      await _laboratoriosRef.doc(firestoreId).delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registro eliminado correctamente'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo eliminar: $e'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _mapDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      return {
        'firestoreId': doc.id,
        ...data,
      };
    }).toList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final isMobile = c.maxWidth < 900;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Laboratorios',
                            style: TextStyle(
                              fontSize: isMobile ? 22 : 28,
                              fontWeight: FontWeight.w900,
                              color: Palette.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gestión de formularios 1, 2 y 3',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.black.withValues(alpha: 0.62),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _crearNuevo,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nuevo laboratorio'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.button,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Palette.primary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Buscar por ID...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Palette.fieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: Palette.primary.withValues(alpha: 0.12),
                          ),
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
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Palette.primary.withValues(alpha: 0.12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _laboratoriosRef
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Text(
                                  'Error al cargar laboratorios:\n${snapshot.error}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          final items = _mapDocs(docs);
                          final data = _applyFilter(items);

                          if (data.isEmpty) {
                            return const Center(
                              child: Text('No hay laboratorios registrados'),
                            );
                          }

                          return isMobile
                              ? _buildMobileList(data)
                              : _buildDesktopTable(data);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<Map<String, dynamic>> data) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: data.length,
      itemBuilder: (_, i) {
        final item = data[i];
        final parentId = (item['id'] ?? item['firestoreId'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FutureBuilder<_LaboratorioResumen>(
            future: _buildResumen(parentId),
            builder: (context, snapshot) {
              final resumen = snapshot.data ?? _LaboratorioResumen.empty();

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Palette.fieldBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Palette.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _desktopCell(
                            'ID',
                            '${item['id'] ?? parentId}',
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _desktopCell(
                            'Cliente / Empresa',
                            resumen.cliente,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _desktopCell(
                            'Solicitante / Att.',
                            resumen.solicitante,
                          ),
                        ),
                        Expanded(
                          child: _desktopCell(
                            'Form. 1',
                            resumen.hasForm1 ? 'Sí' : 'No',
                          ),
                        ),
                        Expanded(
                          child: _desktopCell(
                            'Form. 2',
                            resumen.hasForm2 ? 'Sí' : 'No',
                          ),
                        ),
                        Expanded(
                          child: _desktopCell(
                            'Form. 3',
                            resumen.hasForm3 ? 'Sí' : 'No',
                          ),
                        ),
                        Expanded(
                          child: _desktopCell(
                            'Estado',
                            '${item['estado'] ?? 'Activo'}',
                          ),
                        ),
                        SizedBox(
                          width: 150,
                          child: Wrap(
                            spacing: 8,
                            children: [
                              IconButton(
                                tooltip: 'Abrir',
                                onPressed: () => _abrirSwitch(item),
                                icon: const Icon(Icons.open_in_new_rounded),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _eliminar(item),
                                icon: Icon(
                                  Icons.delete_rounded,
                                  color: Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _desktopCell(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> data) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = data[i];
        final parentId = (item['id'] ?? item['firestoreId'] ?? '').toString();

        return FutureBuilder<_LaboratorioResumen>(
          future: _buildResumen(parentId),
          builder: (context, snapshot) {
            final resumen = snapshot.data ?? _LaboratorioResumen.empty();

            return Container(
              padding: const EdgeInsets.all(14),
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
                    '${item['id'] ?? parentId}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _mobileInfo('Cliente / Empresa', resumen.cliente),
                  _mobileInfo('Solicitante / Att.', resumen.solicitante),
                  _mobileInfo(
                    'Formularios',
                    'F1: ${resumen.hasForm1 ? 'Sí' : 'No'} · '
                        'F2: ${resumen.hasForm2 ? 'Sí' : 'No'} · '
                        'F3: ${resumen.hasForm3 ? 'Sí' : 'No'}',
                  ),
                  _mobileInfo('Estado', '${item['estado'] ?? 'Activo'}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _abrirSwitch(item),
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text('Abrir'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _eliminar(item),
                          icon: const Icon(Icons.delete_rounded, size: 18),
                          label: const Text('Eliminar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _mobileInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value.isEmpty ? '-' : value),
          ],
        ),
      ),
    );
  }

  Future<_LaboratorioResumen> _buildResumen(String parentId) async {
    final results = await Future.wait([
      _readSubform(parentId, 'formulario_1'),
      _readSubform(parentId, 'formulario_2'),
      _readSubform(parentId, 'formulario_3'),
    ]);

    final form1 = results[0];
    final form2 = results[1];
    final form3 = results[2];

    String cliente = '';
    String solicitante = '';

    if (form2 != null) {
      final infoCliente = Map<String, dynamic>.from(
        form2['informacionGeneralCliente'] ?? {},
      );
      cliente = (infoCliente['empresaCliente'] ?? '').toString();
      solicitante = (infoCliente['solicitante'] ?? '').toString();
    }

    if (cliente.isEmpty && form3 != null) {
      final infoGeneral = Map<String, dynamic>.from(
        form3['informacionGeneral'] ?? {},
      );
      final infoCliente = Map<String, dynamic>.from(
        infoGeneral['informacionCliente'] ?? {},
      );
      cliente = (infoCliente['cliente'] ?? '').toString();
      solicitante = (infoCliente['att'] ?? '').toString();
    }

    if (cliente.isEmpty && form1 != null) {
      final datosGenerales = Map<String, dynamic>.from(
        form1['datosGenerales'] ?? {},
      );
      cliente = (datosGenerales['areaSolicitante'] ?? '').toString();
      solicitante = (datosGenerales['solicitadoPor'] ?? '').toString();
    }

    return _LaboratorioResumen(
      cliente: cliente,
      solicitante: solicitante,
      hasForm1: form1 != null,
      hasForm2: form2 != null,
      hasForm3: form3 != null,
    );
  }
}

class _LaboratorioResumen {
  final String cliente;
  final String solicitante;
  final bool hasForm1;
  final bool hasForm2;
  final bool hasForm3;

  const _LaboratorioResumen({
    required this.cliente,
    required this.solicitante,
    required this.hasForm1,
    required this.hasForm2,
    required this.hasForm3,
  });

  factory _LaboratorioResumen.empty() {
    return const _LaboratorioResumen(
      cliente: '',
      solicitante: '',
      hasForm1: false,
      hasForm2: false,
      hasForm3: false,
    );
  }
}