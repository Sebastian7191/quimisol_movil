import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';

class RepartidorViajesPage extends StatelessWidget {
  const RepartidorViajesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final String uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      return const Center(child: Text('Usuario no autenticado'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('repartidorUid', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Center(child: Text('No tienes pedidos asignados'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final data = docs[index].data();

            final ubicacion =
                (data['ubicacion'] as Map<String, dynamic>?) ?? {};
            final direccion =
                (ubicacion['direccion'] ?? 'Sin dirección').toString();

            final estado = (data['estado'] ?? '').toString();
            final total = (data['total'] is num)
                ? (data['total'] as num).toDouble()
                : 0.0;

            final items = (data['items'] is List)
                ? List<Map<String, dynamic>>.from(data['items'])
                : <Map<String, dynamic>>[];

            final clienteFoto =
                (data['clientePhoto'] ?? data['userPhoto'])?.toString();

            return _PedidoCard(
              direccion: direccion,
              estado: estado,
              total: total,
              items: items,
              clienteFoto: clienteFoto,
            );
          },
        );
      },
    );
  }
}

/// =======================================================
/// 🧾 CARD DEL PEDIDO — UX DELIVERY REAL
/// =======================================================
class _PedidoCard extends StatelessWidget {
  final String direccion;
  final String estado;
  final double total;
  final List<Map<String, dynamic>> items;
  final String? clienteFoto;

  const _PedidoCard({
    required this.direccion,
    required this.estado,
    required this.total,
    required this.items,
    required this.clienteFoto,
  });

  Color get _estadoColor {
    switch (estado) {
      case 'Aceptado':
        return Palette.statsWarning;
      case 'En camino':
        return Palette.primary;
      case 'Entregado':
        return Palette.statsSuccess;
      default:
        return Palette.ink.withOpacity(0.6);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          /// ───────── HEADER (CLIENTE) ─────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Palette.fieldBg,
                  backgroundImage:
                      clienteFoto != null ? NetworkImage(clienteFoto!) : null,
                  child: clienteFoto == null
                      ? const Icon(Icons.person_outline)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    direccion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Palette.ink,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _estadoColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: _estadoColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: Palette.ink.withOpacity(0.06)),

          /// ───────── PRODUCTOS ─────────
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
                              i['name'] ?? 'Producto',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Palette.ink,
                              ),
                            ),
                            Text(
                              '$qty × Bs ${price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Palette.ink.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Bs ${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Palette.ink,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          Divider(height: 1, color: Palette.ink.withOpacity(0.06)),

          /// ───────── TOTAL ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Palette.ink.withOpacity(0.6),
                  ),
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
