import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/services/kilometraje_service.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/services/pedidos_repartidor_service.dart';

/// Encabezado del repartidor: saludo según la hora + resumen en vivo del
/// día ("3 por entregar · 1 en camino · 12.4 km hoy").
///
/// Lee lo mismo que ya usa la app: su perfil (`usuarios/{uid}`), sus
/// pedidos activos (`pedidos` con repartidorUid) y los km del día
/// (`repartidores_km_diario/{uid}_{yyyy-MM-dd}`).
class ResumenDiaHeader extends StatefulWidget {
  const ResumenDiaHeader({super.key});

  @override
  State<ResumenDiaHeader> createState() => _ResumenDiaHeaderState();
}

class _ResumenDiaHeaderState extends State<ResumenDiaHeader> {
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  final _db = FirebaseFirestore.instance;

  // Streams creados una vez: los redibujos no vuelven a suscribirse.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _perfil$ = _db
      .collection('usuarios')
      .doc(_uid)
      .snapshots();

  // Mismos pedidos que la lista (resuelve el repartidor actual).
  late final Stream<List<PedidoDoc>> _pedidos$ = PedidosRepartidor.stream(
    _uid,
  );

  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _kmHoy$ = _db
      .collection(KilometrajeService.coleccionDiaria)
      .doc('${_uid}_${KilometrajeService.fechaKey(DateTime.now())}')
      .snapshots();

  static const _enCamino = {
    'en camino',
    'en_camino',
    'encamino',
    'en curso',
    'en_curso',
    'encurso',
  };

  String _saludo() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    if (_uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _perfil$,
      builder: (context, perfilSnap) {
        final nombreCompleto =
            (perfilSnap.data?.data()?['name'] ??
                    perfilSnap.data?.data()?['nombre'] ??
                    '')
                .toString()
                .trim();
        final nombre = nombreCompleto.split(RegExp(r'\s+')).first;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              nombre.isEmpty ? '${_saludo()} 👋' : '${_saludo()}, $nombre 👋',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Palette.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            StreamBuilder<List<PedidoDoc>>(
              stream: _pedidos$,
              builder: (context, pedSnap) {
                int porEntregar = 0;
                int enCamino = 0;
                for (final d in pedSnap.data ?? const <PedidoDoc>[]) {
                  final e = (d.data()['estado'] ?? '')
                      .toString()
                      .trim()
                      .toLowerCase();
                  if (_enCamino.contains(e)) {
                    enCamino++;
                  } else if (e == 'aceptado' || e == 'aceptada') {
                    porEntregar++;
                  }
                }

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _kmHoy$,
                  builder: (context, kmSnap) {
                    final raw = kmSnap.data?.data()?['kmTotal'];
                    final km = raw is num ? raw.toDouble() : 0.0;

                    final partes = <String>[
                      if (porEntregar == 0 && enCamino == 0)
                        'Sin pedidos pendientes',
                      if (porEntregar > 0) '$porEntregar por entregar',
                      if (enCamino > 0) '$enCamino en camino',
                      if (km > 0) '${km.toStringAsFixed(1)} km hoy',
                    ];

                    return Text(
                      pedSnap.hasData ? partes.join(' · ') : 'Cargando…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Palette.ink.withValues(alpha: 0.72),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}
