import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// ✅ para "Hoy / Mañana / miércoles..."
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/pages/pedido_ruta_map_page.dart';

class RepartidorViajesPage extends StatefulWidget {
  const RepartidorViajesPage({super.key});

  @override
  State<RepartidorViajesPage> createState() => _RepartidorViajesPageState();
}

class _RepartidorViajesPageState extends State<RepartidorViajesPage> {
  Position? _currentPosition;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // ✅ habilita nombres de días/meses en español
    initializeDateFormatting('es');

    _initLocation();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _loadLocation());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    await Geolocator.requestPermission();
    await _loadLocation();
  }

  Future<void> _loadLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (mounted) setState(() => _currentPosition = pos);
  }

  // ─────────────────────────
  // 📐 DISTANCIA (HAVERSINE)
  // ─────────────────────────
  double _deg(double d) => d * math.pi / 180;

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371;
    final dLat = _deg(lat2 - lat1);
    final dLon = _deg(lon2 - lon1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg(lat1)) *
            math.cos(_deg(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  DateTime? _tsToDate(dynamic v) => v is Timestamp ? v.toDate() : null;

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  int _dayDiff(DateTime a, DateTime b) {
    // a - b en días (a y b deben venir ya "a medianoche")
    return a.difference(b).inDays;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _labelForDay(DateTime day, DateTime todayKey) {
    final diff = _dayDiff(day, todayKey);
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    if (diff == -1) return 'Ayer';

    // ✅ ejemplo: "miércoles 22 ene"
    final f = DateFormat("EEEE d MMM", 'es').format(day);
    return _capitalize(f);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty || _currentPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('repartidorUid', isEqualTo: uid)
          .where('estado', whereIn: const ['aceptado', 'En camino'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        // ✅ armamos lista con dist + fecha_envio
        final pedidos = docs.map((doc) {
          final data = doc.data();
          final ubicacion = (data['ubicacion'] as Map<String, dynamic>?) ?? {};

          final lat = (ubicacion['lat'] as num?)?.toDouble();
          final lng = (ubicacion['lng'] as num?)?.toDouble();

          final dist = (lat != null && lng != null)
              ? _distanceKm(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                  lat,
                  lng,
                )
              : 99999.0;

          final fechaEnvio = _tsToDate(data['fecha_envio']); // ✅ el campo
          final day = fechaEnvio == null ? null : _dayKey(fechaEnvio);

          return {
            'id': doc.id,
            'data': data,
            'dist': dist,
            'fecha_envio': fechaEnvio,
            'day': day, // DateTime(yyyy,mm,dd) o null
          };
        }).toList();

        if (pedidos.isEmpty) {
          return Center(
            child: Text(
              'No tienes pedidos asignados',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Palette.ink.withOpacity(0.6),
              ),
            ),
          );
        }

        // ✅ agrupamos por día (según fecha_envio)
        final Map<DateTime, List<Map<String, dynamic>>> grouped = {};
        final List<Map<String, dynamic>> sinFecha = [];

        for (final p in pedidos) {
          final day = p['day'] as DateTime?;
          if (day == null) {
            sinFecha.add(p);
          } else {
            grouped.putIfAbsent(day, () => []).add(p);
          }
        }

        // ✅ orden dentro de cada grupo: fecha_envio DESC, desempate distancia ASC
        int sortPedido(Map<String, dynamic> a, Map<String, dynamic> b) {
          final fa = a['fecha_envio'] as DateTime?;
          final fb = b['fecha_envio'] as DateTime?;

          if (fa == null && fb == null) {
            return (a['dist'] as double).compareTo(b['dist'] as double);
          }
          if (fa == null) return 1;
          if (fb == null) return -1;

          final byFecha = fb.compareTo(fa); // ✅ DESC
          if (byFecha != 0) return byFecha;

          return (a['dist'] as double).compareTo(b['dist'] as double);
        }

        grouped.forEach((_, list) => list.sort(sortPedido));
        sinFecha.sort(sortPedido);

        // ✅ orden de secciones: Hoy, Mañana, luego días futuros, y por último pasados
        final now = DateTime.now();
        final todayKey = _dayKey(now);

        final dayKeys = grouped.keys.toList()
          ..sort((a, b) {
            final da = _dayDiff(a, todayKey);
            final db = _dayDiff(b, todayKey);

            // prioridad: >=0 primero (hoy y futuros), luego negativos (pasados)
            final aFuture = da >= 0;
            final bFuture = db >= 0;
            if (aFuture != bFuture) return aFuture ? -1 : 1;

            // dentro de futuros: asc (hoy, mañana, etc.)
            if (aFuture && bFuture) return a.compareTo(b);

            // dentro de pasados: desc (ayer, antes de ayer...)
            return b.compareTo(a);
          });

        // ✅ render: headers + cards
        final children = <Widget>[];

        for (final day in dayKeys) {
          final label = _labelForDay(day, todayKey);
          children.add(_SectionHeader(title: label));

          final list = grouped[day]!;
          for (final p in list) {
            final data = p['data'] as Map<String, dynamic>;
            final pedidoId = p['id'] as String;

            children.add(
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PedidoRutaMapPage(
                        pedidoId: pedidoId,
                        repartidorUid: uid,
                      ),
                    ),
                  );
                },
                child: _PedidoCard(
                  data: data,
                  distanciaKm: p['dist'] as double,
                ),
              ),
            );
          }
        }

        if (sinFecha.isNotEmpty) {
          children.add(const _SectionHeader(title: 'Sin fecha'));
          for (final p in sinFecha) {
            final data = p['data'] as Map<String, dynamic>;
            final pedidoId = p['id'] as String;

            children.add(
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PedidoRutaMapPage(
                        pedidoId: pedidoId,
                        repartidorUid: uid,
                      ),
                    ),
                  );
                },
                child: _PedidoCard(
                  data: data,
                  distanciaKm: p['dist'] as double,
                ),
              ),
            );
          }
        }

        return ListView(padding: const EdgeInsets.all(12), children: children);
      },
    );
  }
}

/// =======================================================
/// ✅ HEADER DE SECCIÓN (Hoy, Mañana, etc.)
/// =======================================================
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Palette.primary.withOpacity(0.85),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$title:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Palette.ink.withOpacity(0.88),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// ✅ CHIP BONITO PARA ESTADO
/// =======================================================
class _EstadoChip extends StatelessWidget {
  final String estado;
  const _EstadoChip({required this.estado});

  Color _bg(String s) {
    final x = s.trim().toLowerCase();
    if (x.contains('entreg')) return Palette.statsSuccess.withOpacity(0.18);
    if (x.contains('cancel') || x.contains('rechaz')) {
      return Palette.statsDanger.withOpacity(0.18);
    }
    if (x.contains('camino') || x.contains('ruta') || x.contains('proceso')) {
      return Colors.orange.withOpacity(0.18);
    }
    if (x.contains('acept')) return Palette.primary.withOpacity(0.14);
    if (x.contains('pend')) return Colors.orange.withOpacity(0.14);
    return Palette.primary.withOpacity(0.12);
  }

  Color _fg(String s) {
    final x = s.trim().toLowerCase();
    if (x.contains('entreg')) return Palette.statsSuccess;
    if (x.contains('cancel') || x.contains('rechaz'))
      return Palette.statsDanger;
    if (x.contains('camino') || x.contains('ruta') || x.contains('proceso')) {
      return Colors.orange.shade800;
    }
    if (x.contains('acept')) return Palette.primary;
    if (x.contains('pend')) return Colors.orange.shade800;
    return Palette.primary;
  }

  IconData _icon(String s) {
    final x = s.trim().toLowerCase();
    if (x.contains('entreg')) return Icons.check_circle_rounded;
    if (x.contains('cancel') || x.contains('rechaz'))
      return Icons.cancel_rounded;
    if (x.contains('camino') || x.contains('ruta')) {
      return Icons.local_shipping_rounded;
    }
    if (x.contains('acept')) return Icons.thumb_up_alt_rounded;
    if (x.contains('pend')) return Icons.hourglass_top_rounded;
    return Icons.info_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _bg(estado),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(estado), size: 16, color: _fg(estado)),
          const SizedBox(width: 6),
          Text(
            estado,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _fg(estado),
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================================================
/// 🧾 UI ANTIGUA (CONSERVADA) + ✅ Estado agregado
/// =======================================================
class _PedidoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final double distanciaKm;

  const _PedidoCard({required this.data, required this.distanciaKm});

  @override
  Widget build(BuildContext context) {
    final ubicacion = (data['ubicacion'] as Map<String, dynamic>?) ?? {};
    final direccion = (ubicacion['direccion'] ?? '').toString();

    final estado = (data['estado'] ?? 'Pendiente').toString();

    final items = (data['items'] is List)
        ? List<Map<String, dynamic>>.from(data['items'])
        : [];

    final clienteFoto = data['clientePhoto'];
    final total = (data['total'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          /// HEADER
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: clienteFoto != null
                      ? NetworkImage(clienteFoto)
                      : null,
                  child: clienteFoto == null ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        direccion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Palette.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _EstadoChip(estado: estado),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${distanciaKm.toStringAsFixed(1)} km',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.primary,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Palette.ink.withOpacity(0.06)),

          /// PRODUCTOS
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: items.map((i) {
                final qty = (i['qty'] ?? 1) as num;
                final price = (i['price'] ?? 0) as num;
                final subtotal = qty * price;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          i['imageUrl'],
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (i['name'] ?? '').toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Palette.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cantidad: $qty',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Palette.ink.withOpacity(0.65),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Precio unitario: Bs ${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Palette.ink.withOpacity(0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Bs ${subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          Divider(height: 1, color: Palette.ink.withOpacity(0.06)),

          /// TOTAL
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  'Bs ${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Palette.primary,
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
