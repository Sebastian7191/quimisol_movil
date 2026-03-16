import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

class LaboratorioClienteDetalleParte3Page extends StatelessWidget {
  final String laboratorioId;
  final Map<String, dynamic> laboratorioData;
  final String clienteNombre;

  const LaboratorioClienteDetalleParte3Page({
    super.key,
    required this.laboratorioId,
    required this.laboratorioData,
    required this.clienteNombre,
  });

  @override
  Widget build(BuildContext context) {
    final encabezado = Map<String, dynamic>.from(
      laboratorioData['encabezado'] ?? {},
    );
    final descripcionMuestras = Map<String, dynamic>.from(
      laboratorioData['descripcionMuestras'] ?? {},
    );
    final muestras = (descripcionMuestras['muestras'] as List?) ?? [];

    final codigo = (encabezado['codigo'] ?? 'Sin código').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Detalle de laboratorio',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _Parte3Header(
            clienteNombre: clienteNombre,
            codigo: codigo,
            totalMuestras: muestras.length,
          ),

          const SizedBox(height: 16),
          _SectionCard(
            title: 'Descripción de las muestras',
            subtitle:
                'Consulta el detalle registrado para cada muestra del laboratorio.',
            child: muestras.isEmpty
                ? const _EmptyMuestrasState()
                : Column(
                    children: List.generate(muestras.length, (index) {
                      final item = Map<String, dynamic>.from(muestras[index]);

                      final no = (item['no'] ?? index + 1).toString();
                      final codigoMuestra = (item['codigoMuestra'] ?? '-')
                          .toString();
                      final tipoMuestra = (item['tipoMuestra'] ?? '-')
                          .toString();
                      final cantidad = (item['cantidad'] ?? '-').toString();
                      final volumenPeso = (item['volumenPeso'] ?? '-')
                          .toString();
                      final tipoEnvase = (item['tipoEnvase'] ?? '-').toString();
                      final descripcion = (item['descripcion'] ?? '-')
                          .toString();
                      final numeroLab = (item['numeroLaboratorio'] ?? '-')
                          .toString();

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == muestras.length - 1 ? 0 : 14,
                        ),
                        child: _MuestraCard(
                          no: no,
                          codigoMuestra: codigoMuestra,
                          tipoMuestra: tipoMuestra,
                          cantidad: cantidad,
                          volumenPeso: volumenPeso,
                          tipoEnvase: tipoEnvase,
                          descripcion: descripcion,
                          numeroLaboratorio: numeroLab,
                        ),
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Parte3Header extends StatelessWidget {
  final String clienteNombre;
  final String codigo;
  final int totalMuestras;

  const _Parte3Header({
    required this.clienteNombre,
    required this.codigo,
    required this.totalMuestras,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Palette.primary, Palette.button],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Palette.primary.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                      codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      clienteNombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.90),
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeaderChip(
                icon: Icons.inventory_2_outlined,
                label: '$totalMuestras muestras',
              ),
              const _HeaderChip(
                icon: Icons.visibility_outlined,
                label: 'Solo lectura',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool compactText;

  const _MiniStatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.compactText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Palette.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.55),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w900,
                    fontSize: compactText ? 13 : 18,
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

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionBadge(
            icon: Icons.format_list_bulleted_rounded,
            label: 'Detalle',
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _SectionBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.button.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Palette.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Palette.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMuestrasState extends StatelessWidget {
  const _EmptyMuestrasState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Palette.button.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_rounded,
              color: Palette.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No hay muestras registradas',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando existan muestras asociadas a este laboratorio, aparecerán aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.58),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _MuestraCard extends StatelessWidget {
  final String no;
  final String codigoMuestra;
  final String tipoMuestra;
  final String cantidad;
  final String volumenPeso;
  final String tipoEnvase;
  final String descripcion;
  final String numeroLaboratorio;

  const _MuestraCard({
    required this.no,
    required this.codigoMuestra,
    required this.tipoMuestra,
    required this.cantidad,
    required this.volumenPeso,
    required this.tipoEnvase,
    required this.descripcion,
    required this.numeroLaboratorio,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Palette.button.withValues(alpha: 0.95),
                      Palette.primary.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    no,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Detalle de muestra',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'N° $no',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.65),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _DatoMini(
                      icon: Icons.qr_code_2_rounded,
                      titulo: 'Código muestra',
                      valor: codigoMuestra,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DatoMini(
                      icon: Icons.category_outlined,
                      titulo: 'Tipo muestra',
                      valor: tipoMuestra,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DatoMini(
                      icon: Icons.format_list_numbered_rounded,
                      titulo: 'Cantidad',
                      valor: cantidad,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DatoMini(
                      icon: Icons.scale_outlined,
                      titulo: 'Volumen / Peso',
                      valor: volumenPeso,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DatoMini(
                      icon: Icons.inventory_2_outlined,
                      titulo: 'Tipo envase',
                      valor: tipoEnvase,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _DatoMini(
                      icon: Icons.science_outlined,
                      titulo: 'N° laboratorio',
                      valor: numeroLaboratorio,
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 17,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Descripción',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  descripcion.trim().isEmpty ? '-' : descripcion,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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

class _DatoMini extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String valor;

  const _DatoMini({
    required this.icon,
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: Palette.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
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
            valor.trim().isEmpty ? '-' : valor,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeaderChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
