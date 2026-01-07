import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/pages/pedidos_en_curso.dart';

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
          .where('estado', whereIn: ['Aceptado', 'En camino'])
          .snapshots(),

      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;

        final pedidos =
            docs.map((doc) {
              final data = doc.data();
              final ubicacion =
                  (data['ubicacion'] as Map<String, dynamic>?) ?? {};

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

              return {'id': doc.id, 'data': data, 'dist': dist};
            }).toList()..sort(
              (a, b) => (a['dist'] as double).compareTo(b['dist'] as double),
            );

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

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pedidos.length,
          itemBuilder: (_, i) {
            final data = pedidos[i]['data'] as Map<String, dynamic>;
            final pedidoId = pedidos[i]['id'] as String;

            return InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PedidoEnCursoPage(
                      pedidoId: pedidoId,
                      repartidorUid: uid,
                    ),
                  ),
                );
              },
              child: _PedidoCard(
                data: data,
                distanciaKm: pedidos[i]['dist'] as double,
              ),
            );
          },
        );
      },
    );
  }
}

/// =======================================================
/// 🧾 UI ANTIGUA (CONSERVADA)
/// =======================================================
class _PedidoCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final double distanciaKm;

  const _PedidoCard({required this.data, required this.distanciaKm});

  @override
  Widget build(BuildContext context) {
    final ubicacion = (data['ubicacion'] as Map<String, dynamic>?) ?? {};
    final direccion = ubicacion['direccion'] ?? '';

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
                  child: Text(
                    direccion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Palette.ink,
                    ),
                  ),
                ),
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
                              i['name'],
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
                        style: TextStyle(fontWeight: FontWeight.w800),
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
