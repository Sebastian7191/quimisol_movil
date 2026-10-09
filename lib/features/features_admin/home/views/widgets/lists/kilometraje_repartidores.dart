import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

/// Km recorridos por cada repartidor por día: ruta inicial + desvíos.
/// Lee `repartidores_km_diario` (lo escribe la app del repartidor).
class KilometrajeRepartidores extends StatelessWidget {
  const KilometrajeRepartidores({
    super.key,
    required this.stream,
    this.departamento,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  /// Filtro del dashboard (null = todos).
  final String? departamento;

  static double _n(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  static String _km(double v) => '${v.toStringAsFixed(1)} km';

  static String _min(double v) {
    final total = v.round();
    if (total < 60) return '$total min';
    final h = total ~/ 60;
    final m = total % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  static String _diaLabel(String fecha) {
    final p = fecha.split('-');
    if (p.length != 3) return fecha;
    final d = DateTime.tryParse(fecha);
    final dia = d == null ? '' : '${_dias[d.weekday - 1]} ';
    return '$dia${p[2]}/${p[1]}/${p[0]}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _mensaje('No se pudo cargar el kilometraje: ${snap.error}');
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final dep = departamento?.trim().toLowerCase();
        final filas = (snap.data?.docs ?? const [])
            .map((d) => d.data())
            .where(
              (d) =>
                  dep == null ||
                  dep.isEmpty ||
                  (d['departamento'] ?? '').toString().trim().toLowerCase() ==
                      dep,
            )
            .toList();

        if (filas.isEmpty) {
          return _mensaje('Aún no hay recorridos registrados en este rango.');
        }

        // Totales del rango.
        double kmTotal = 0, kmDesvio = 0, minDesvio = 0;
        int viajes = 0;
        for (final f in filas) {
          kmTotal += _n(f['kmTotal']);
          kmDesvio += _n(f['kmDesvio']);
          minDesvio += _n(f['minDesvio']);
          viajes += _n(f['viajes']).round();
        }

        // Agrupado por día, del más reciente al más antiguo.
        final porDia = <String, List<Map<String, dynamic>>>{};
        for (final f in filas) {
          porDia.putIfAbsent((f['fecha'] ?? '').toString(), () => []).add(f);
        }
        final dias = porDia.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  icon: Icons.route_rounded,
                  text: 'Recorrido: ${_km(kmTotal)}',
                  color: Palette.primary,
                ),
                _Chip(
                  icon: Icons.alt_route_rounded,
                  text: 'Desvíos: +${_km(kmDesvio)} · +${_min(minDesvio)}',
                  color: Palette.statsWarning,
                ),
                _Chip(
                  icon: Icons.local_shipping_rounded,
                  text: '$viajes viaje${viajes == 1 ? '' : 's'}',
                  color: Palette.button,
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final dia in dias) ...[
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6),
                child: Text(
                  _diaLabel(dia),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                    fontSize: 13,
                  ),
                ),
              ),
              ...(porDia[dia]!..sort(
                    (a, b) => _n(b['kmTotal']).compareTo(_n(a['kmTotal'])),
                  ))
                  .map((f) => _filaRepartidor(f)),
            ],
          ],
        );
      },
    );
  }

  Widget _filaRepartidor(Map<String, dynamic> f) {
    final nombre = (f['repartidorNombre'] ?? '').toString().trim();
    final viajes = _n(f['viajes']).round();
    final kmTotal = _n(f['kmTotal']);
    final kmDesvio = _n(f['kmDesvio']);
    final minTotal = _n(f['minTotal']);
    final minDesvio = _n(f['minDesvio']);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre.isEmpty ? 'Repartidor' : nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$viajes viaje${viajes == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Palette.ink.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _km(kmTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Palette.primary,
                ),
              ),
              Text(
                kmDesvio > 0 || minDesvio > 0
                    ? '${_min(minTotal)} · desvío +${_km(kmDesvio)} / +${_min(minDesvio)}'
                    : '${_min(minTotal)} · sin desvíos',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: kmDesvio > 0 || minDesvio > 0
                      ? Palette.statsWarning
                      : Palette.ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mensaje(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: TextStyle(
        color: Palette.ink.withValues(alpha: 0.65),
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Palette.ink,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
