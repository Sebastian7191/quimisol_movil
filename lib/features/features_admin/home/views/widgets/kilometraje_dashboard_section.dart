import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

// Datos escritos por la app del repartidor (solo lectura desde el admin):
// /repartidores_km_diario/{repartidorUid}_{yyyy-MM-dd}
const _coleccion = 'repartidores_km_diario';

final _diaFmt = DateFormat('yyyy-MM-dd');
const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

/// Día actual en hora de Bolivia (UTC-4), igual que el campo `fecha`.
String _hoyBolivia() =>
    _diaFmt.format(DateTime.now().toUtc().subtract(const Duration(hours: 4)));

String _normDep(String v) => v.toLowerCase().replaceAll(RegExp(r'\s+'), '');

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse((v ?? '').toString()) ?? 0;
}

String _km(double v) => '${v.toStringAsFixed(1)} km';

String _min(double v) {
  final m = v.round();
  if (m < 60) return '$m min';
  final h = m ~/ 60;
  final r = m % 60;
  return r == 0 ? '$h h' : '$h h $r min';
}

String _diaHeader(String fecha) {
  final d = DateTime.tryParse(fecha);
  if (d == null) return fecha;
  return '${_diasSemana[d.weekday - 1]} ${DateFormat('dd/MM/yyyy').format(d)}';
}

class _KmDia {
  final String uid;
  final String nombre;
  final String departamento;
  final String fecha;
  final double kmDesvio;
  final double minDesvio;
  final double kmTotal;
  final double minTotal;
  final int viajes;
  final int desvios;

  const _KmDia({
    required this.uid,
    required this.nombre,
    required this.departamento,
    required this.fecha,
    required this.kmDesvio,
    required this.minDesvio,
    required this.kmTotal,
    required this.minTotal,
    required this.viajes,
    required this.desvios,
  });

  factory _KmDia.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final nombre = (d['repartidorNombre'] ?? '').toString().trim();
    return _KmDia(
      uid: (d['repartidorUid'] ?? '').toString(),
      nombre: nombre.isEmpty ? 'Repartidor' : nombre,
      departamento: (d['departamento'] ?? '').toString(),
      fecha: (d['fecha'] ?? '').toString(),
      kmDesvio: _num(d['kmDesvio']),
      minDesvio: _num(d['minDesvio']),
      kmTotal: _num(d['kmTotal']),
      minTotal: _num(d['minTotal']),
      viajes: _num(d['viajes']).round(),
      desvios: _num(d['desvios']).round(),
    );
  }
}

/// Km recorridos por repartidor y por día (ruta inicial + desvios).
/// Respeta el rango de fechas y el departamento del dashboard.
class KilometrajeDashboardSection extends StatefulWidget {
  final double width;
  final DateTime? rangeStart;
  final String? departamento;

  const KilometrajeDashboardSection({
    super.key,
    required this.width,
    required this.rangeStart,
    required this.departamento,
  });

  @override
  State<KilometrajeDashboardSection> createState() =>
      _KilometrajeDashboardSectionState();
}

class _KilometrajeDashboardSectionState
    extends State<KilometrajeDashboardSection> {
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _buildStream();
  }

  @override
  void didUpdateWidget(covariant KilometrajeDashboardSection old) {
    super.didUpdateWidget(old);
    // El departamento se filtra en memoria; solo el rango cambia la consulta.
    if (old.rangeStart != widget.rangeStart) _stream = _buildStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStream() {
    // Rango sobre un solo campo (texto yyyy-MM-dd): no requiere índice compuesto.
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection(_coleccion)
        .where('fecha', isLessThanOrEqualTo: _hoyBolivia());
    final from = widget.rangeStart;
    if (from != null) {
      q = q.where('fecha', isGreaterThanOrEqualTo: _diaFmt.format(from));
    }
    return q.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kilometraje de repartidores',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
              color: Palette.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Por día: ruta inicial + desvíos detectados en el viaje',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Palette.ink.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) return _error(snap.error);
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }

              final dep = widget.departamento;
              final items = (snap.data?.docs ?? const [])
                  .map(_KmDia.fromDoc)
                  .where((e) => e.fecha.isNotEmpty)
                  .where((e) =>
                      dep == null || _normDep(e.departamento) == _normDep(dep))
                  .toList();

              if (items.isEmpty) {
                return _box(
                  child: Text(
                    'Aún no hay recorridos registrados en este rango.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Palette.ink.withValues(alpha: 0.78),
                    ),
                  ),
                );
              }

              return _content(items);
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Palette.ink.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Estimación según la ruta (Mapbox), no odómetro. '
                  'No incluye la vuelta al almacén.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _content(List<_KmDia> items) {
    var kmTotal = 0.0, kmDesvio = 0.0, minDesvio = 0.0;
    var viajes = 0;
    final porDia = <String, List<_KmDia>>{};
    for (final e in items) {
      kmTotal += e.kmTotal;
      kmDesvio += e.kmDesvio;
      minDesvio += e.minDesvio;
      viajes += e.viajes;
      porDia.putIfAbsent(e.fecha, () => []).add(e);
    }

    // yyyy-MM-dd ordena bien como texto: más reciente primero.
    final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(Icons.route_rounded, 'Recorrido: ${_km(kmTotal)}', Palette.primary),
            _chip(
              Icons.alt_route_rounded,
              'Desvíos: +${_km(kmDesvio)} · +${_min(minDesvio)}',
              Palette.statsWarning,
            ),
            _chip(
              Icons.local_shipping_rounded,
              '$viajes ${viajes == 1 ? 'viaje' : 'viajes'}',
              Palette.ink,
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final dia in dias) ...[
          _diaGroup(dia, porDia[dia]!..sort((a, b) => b.kmTotal.compareTo(a.kmTotal))),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _diaGroup(String fecha, List<_KmDia> filas) {
    return _box(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: Palette.primary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 6),
              Text(
                _diaHeader(fecha),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final f in filas) _fila(f),
        ],
      ),
    );
  }

  Widget _fila(_KmDia f) {
    final huboDesvio = f.desvios > 0 || f.kmDesvio > 0 || f.minDesvio > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.delivery_dining_rounded,
            size: 20,
            color: Palette.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${f.viajes} ${f.viajes == 1 ? 'viaje' : 'viajes'} · ${_min(f.minTotal)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Palette.ink.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  huboDesvio
                      ? 'desvío +${_km(f.kmDesvio)} / +${_min(f.minDesvio)}'
                      : 'sin desvíos',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: huboDesvio
                        ? Palette.statsWarning
                        : Palette.ink.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _km(f.kmTotal),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Palette.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(Object? e) {
    final sinPermiso = e is FirebaseException && e.code == 'permission-denied';
    return _box(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: Palette.statsDanger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No se pudo cargar el kilometraje',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Palette.statsDanger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sinPermiso
                      ? 'Sin permiso de lectura sobre "$_coleccion". '
                          'Revisa las reglas de Firestore.'
                      : '$e',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.primary.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}
