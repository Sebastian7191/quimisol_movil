import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/features_admin/laboratorios/pages/laboratorios_form.dart';

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
      final infoCliente =
          Map<String, dynamic>.from(e['informacionGeneralCliente'] ?? {});
      final datosGenerales =
          Map<String, dynamic>.from(e['datosGenerales'] ?? {});
      final encabezado = Map<String, dynamic>.from(e['encabezado'] ?? {});

      final empresa =
          (infoCliente['empresaCliente'] ?? '').toString().toLowerCase();
      final solicitante =
          (infoCliente['solicitante'] ?? '').toString().toLowerCase();
      final id = (e['id'] ?? '').toString().toLowerCase();
      final fecha = (datosGenerales['fechaRecepcionMuestra'] ?? '')
          .toString()
          .toLowerCase();
      final codigo = (encabezado['codigo'] ?? '').toString().toLowerCase();

      return empresa.contains(q) ||
          solicitante.contains(q) ||
          id.contains(q) ||
          fecha.contains(q) ||
          codigo.contains(q);
    }).toList();
  }

  Future<void> _crearNuevo() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LaboratorioFormPage(),
      ),
    );
  }

  Future<void> _editar(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LaboratorioFormPage(initialData: item),
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
          title: const Text('Eliminar registro'),
          content: Text(
            '¿Deseas eliminar el formulario ${item['id'] ?? ''}?',
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
          content: Text('Formulario eliminado correctamente'),
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
                            'Gestión de formularios de recepción de muestras',
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
                        label: const Text('Nuevo formulario'),
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
                        hintText:
                            'Buscar por código, empresa, solicitante o fecha...',
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
                              child: Text('No hay formularios registrados'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            Palette.primary.withValues(alpha: 0.07),
          ),
          columnSpacing: 22,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 68,
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Empresa / Cliente')),
            DataColumn(label: Text('Solicitante')),
            DataColumn(label: Text('Fecha recepción')),
            DataColumn(label: Text('Hora')),
            DataColumn(label: Text('Total muestras')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('Acciones')),
          ],
          rows: data.map((item) {
            final infoCliente =
                Map<String, dynamic>.from(item['informacionGeneralCliente'] ?? {});
            final datosGenerales =
                Map<String, dynamic>.from(item['datosGenerales'] ?? {});
            final infoMuestras =
                Map<String, dynamic>.from(item['informacionMuestras'] ?? {});

            return DataRow(
              cells: [
                DataCell(Text('${item['id'] ?? ''}')),
                DataCell(Text('${infoCliente['empresaCliente'] ?? ''}')),
                DataCell(Text('${infoCliente['solicitante'] ?? ''}')),
                DataCell(Text('${datosGenerales['fechaRecepcionMuestra'] ?? ''}')),
                DataCell(Text('${datosGenerales['horaRecepcionMuestra'] ?? ''}')),
                DataCell(Text('${infoMuestras['totalMuestrasEntregadas'] ?? ''}')),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${item['estado'] ?? 'Activo'}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 8,
                    children: [
                      IconButton(
                        tooltip: 'Editar',
                        onPressed: () => _editar(item),
                        icon: const Icon(Icons.edit_rounded),
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
            );
          }).toList(),
        ),
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
        final infoCliente =
            Map<String, dynamic>.from(item['informacionGeneralCliente'] ?? {});
        final datosGenerales =
            Map<String, dynamic>.from(item['datosGenerales'] ?? {});
        final infoMuestras =
            Map<String, dynamic>.from(item['informacionMuestras'] ?? {});

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
                '${item['id'] ?? ''}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              _mobileInfo('Empresa', '${infoCliente['empresaCliente'] ?? ''}'),
              _mobileInfo('Solicitante', '${infoCliente['solicitante'] ?? ''}'),
              _mobileInfo(
                'Recepción',
                '${datosGenerales['fechaRecepcionMuestra'] ?? ''} - ${datosGenerales['horaRecepcionMuestra'] ?? ''}',
              ),
              _mobileInfo(
                'Total muestras',
                '${infoMuestras['totalMuestrasEntregadas'] ?? ''}',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editar(item),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Editar'),
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
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}