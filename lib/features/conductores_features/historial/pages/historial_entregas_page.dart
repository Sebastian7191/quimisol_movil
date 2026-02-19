import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/historial/pages/detalle_pedido_cliente.dart';
import '../data/models/entrega_item.dart';
import '../data/services/historial_entregas_service.dart';
import '../widgets/empty_historial.dart';
import '../widgets/entrega_tile.dart';

class HistorialEntregasPage extends StatefulWidget {
  const HistorialEntregasPage({super.key});

  @override
  State<HistorialEntregasPage> createState() => _HistorialEntregasPageState();
}

class _HistorialEntregasPageState extends State<HistorialEntregasPage> {
  final _service = HistorialEntregasService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} d';

    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final yy = dt.year.toString();
    return '$dd/$mm/$yy';
  }

  double _avgRating(List<EntregaItem> items) {
    final rated = items.where((e) => (e.rating ?? 0) > 0).toList();
    if (rated.isEmpty) return 0;
    final sum = rated.fold<double>(0, (acc, e) => acc + (e.rating ?? 0));
    return sum / rated.length;
  }

  int _ratedCount(List<EntregaItem> items) =>
      items.where((e) => (e.rating ?? 0) > 0).length;

  Future<void> _openDetalle(EntregaItem e) async {
    final pedidoId = e.id; // ✅ este es el doc.id del historial
    final pedidoCode = (e.pedidoCodigo ?? '').toString().trim();

    // Si tu historial guarda el mismo ID que /pedidos/{pedidoId}, esto funciona directo.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetallePedidoClientePage(
          pedidoId: pedidoId,
          pedidoCode: pedidoCode.isEmpty ? '—' : pedidoCode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Palette.button, // ✅ ROSA
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
        title: const Text('Historial'),
      ),

      body: uid == null
          ? const Center(child: Text('No hay sesión activa'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.streamEntregas(uid),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = snap.data!.docs.map(EntregaItem.fromDoc).toList();
                if (items.isEmpty) return const EmptyHistorial();

                final avg = _avgRating(items);
                final ratedCount = _ratedCount(items);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                  children: [
                    // Header resumen (bonito)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Palette.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Palette.button.withOpacity(0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.star_rounded,
                              color: Palette.primary.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resumen',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Palette.ink.withOpacity(0.9),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  avg > 0
                                      ? 'Promedio: ${avg.toStringAsFixed(1)} ⭐ • Calificados: $ratedCount'
                                      : 'Aún no tienes calificaciones',
                                  style: TextStyle(
                                    color: Palette.ink.withOpacity(0.65),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Entregas: ${items.length}',
                                  style: TextStyle(
                                    color: Palette.ink.withOpacity(0.55),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Lista
                    ...List.generate(items.length, (i) {
                      final e = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: EntregaTile(
                          item: e,
                          timeText: _formatTime(e.deliveredAt),
                          onTap: () => _openDetalle(e),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}
