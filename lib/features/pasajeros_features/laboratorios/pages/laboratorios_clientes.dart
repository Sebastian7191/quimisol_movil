import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/laboratorios/pages/laboratorio_detalle.dart';

class LaboratoriosClientesPage extends StatelessWidget {
  final String clienteNombre;

  const LaboratoriosClientesPage({super.key, required this.clienteNombre});

  @override
  Widget build(BuildContext context) {
    final laboratoriosRef = FirebaseFirestore.instance.collection(
      'laboratorios',
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Mis laboratorios',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          _HeaderCliente(clienteNombre: clienteNombre),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: laboratoriosRef
                  .orderBy('updatedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorState(
                    message: 'Error cargando laboratorios',
                    detail: '${snap.error}',
                  );
                }

                if (snap.connectionState == ConnectionState.waiting) {
                  return const _LoadingLaboratorios();
                }

                final docs = snap.data?.docs ?? [];

                final filtrados = docs.where((doc) {
                  final data = doc.data();
                  final infoCliente = Map<String, dynamic>.from(
                    data['informacionGeneralCliente'] ?? {},
                  );

                  final empresa = (infoCliente['empresaCliente'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();

                  final nombreBuscado = clienteNombre.trim().toLowerCase();

                  return empresa == nombreBuscado;
                }).toList();

                if (filtrados.isEmpty) {
                  return _EmptyLaboratorios(clienteNombre: clienteNombre);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: filtrados.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                      );
                    }

                    final doc = filtrados[index - 1];
                    final data = doc.data();

                    final encabezado = Map<String, dynamic>.from(
                      data['encabezado'] ?? {},
                    );
                    final infoCliente = Map<String, dynamic>.from(
                      data['informacionGeneralCliente'] ?? {},
                    );
                    final datosGenerales = Map<String, dynamic>.from(
                      data['datosGenerales'] ?? {},
                    );
                    final infoMuestras = Map<String, dynamic>.from(
                      data['informacionMuestras'] ?? {},
                    );

                    final codigo = (encabezado['codigo'] ?? 'Sin código')
                        .toString()
                        .trim();
                    final version = (encabezado['version'] ?? '-')
                        .toString()
                        .trim();
                    final solicitante = (infoCliente['solicitante'] ?? '-')
                        .toString()
                        .trim();
                    final proyecto = (infoCliente['proyectoInstalacion'] ?? '-')
                        .toString()
                        .trim();
                    final fechaRecepcion =
                        (datosGenerales['fechaRecepcionMuestra'] ?? '-')
                            .toString()
                            .trim();
                    final totalMuestras =
                        (infoMuestras['totalMuestrasEntregadas'] ?? '-')
                            .toString()
                            .trim();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _LaboratorioCard(
                        codigo: codigo,
                        version: version,
                        solicitante: solicitante,
                        proyecto: proyecto,
                        fechaRecepcion: fechaRecepcion,
                        totalMuestras: totalMuestras,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LaboratorioClienteDetalleParte3Page(
                                laboratorioId: doc.id,
                                laboratorioData: data,
                                clienteNombre: clienteNombre,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCliente extends StatelessWidget {
  final String clienteNombre;

  const _HeaderCliente({required this.clienteNombre});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Palette.primary,
            Palette.button,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Palette.primary.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      clienteNombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aquí podrás ver los formularios de laboratorio asociados a tu empresa y acceder a su detalle.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _LaboratorioCard extends StatelessWidget {
  final String codigo;
  final String version;
  final String solicitante;
  final String proyecto;
  final String fechaRecepcion;
  final String totalMuestras;
  final VoidCallback onTap;

  const _LaboratorioCard({
    required this.codigo,
    required this.version,
    required this.solicitante,
    required this.proyecto,
    required this.fechaRecepcion,
    required this.totalMuestras,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Palette.primary.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Palette.button.withValues(alpha: 0.95),
                            Palette.primary.withValues(alpha: 0.95),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            codigo.isEmpty ? 'Sin código' : codigo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Palette.button.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Formulario',
                                  style: TextStyle(
                                    color: Palette.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Versión $version',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black.withValues(alpha: 0.58),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FB),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Palette.primary,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 10) / 2;

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: _InfoBox(
                            icon: Icons.person_rounded,
                            label: 'Solicitante',
                            value: solicitante.isEmpty ? '-' : solicitante,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _InfoBox(
                            icon: Icons.inventory_2_rounded,
                            label: 'Muestras',
                            value: totalMuestras.isEmpty ? '-' : totalMuestras,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _InfoBox(
                            icon: Icons.event_rounded,
                            label: 'Recepción',
                            value: fechaRecepcion.isEmpty ? '-' : fechaRecepcion,
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: _InfoBox(
                            icon: Icons.assignment_turned_in_rounded,
                            label: 'Estado',
                            value: 'Disponible',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FD),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.03),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Palette.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Proyecto / instalación',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.52),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              proyecto.isEmpty
                                  ? 'Sin proyecto o instalación registrada'
                                  : proyecto,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w800,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Palette.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 18,
                        color: Palette.primary,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Toca para ver el detalle completo',
                          style: TextStyle(
                            color: Palette.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: Palette.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? '-' : value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingLaboratorios extends StatelessWidget {
  const _LoadingLaboratorios();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 180,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.04),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final String detail;

  const _ErrorState({
    required this.message,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.60),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLaboratorios extends StatelessWidget {
  final String clienteNombre;

  const _EmptyLaboratorios({required this.clienteNombre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Palette.button.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.folder_open_rounded,
                size: 44,
                color: Palette.primary,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No hay laboratorios asociados',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No se encontraron formularios de laboratorio para "$clienteNombre".',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.62),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}