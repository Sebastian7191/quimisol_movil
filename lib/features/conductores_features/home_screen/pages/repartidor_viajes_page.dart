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
import 'package:quimisol_movil/shared/widgets/pill_pagination_bar.dart';

class RepartidorViajesPage extends StatefulWidget {
  const RepartidorViajesPage({super.key});

  @override
  State<RepartidorViajesPage> createState() => _RepartidorViajesPageState();
}

class _RepartidorViajesPageState extends State<RepartidorViajesPage> {
  Position? _currentPosition;
  Timer? _timer;

  // 📄 Paginación
  static const int _pageSize = 6;
  int _page = 0;

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

  String _normalizeText(dynamic value) {
    return (value ?? '').toString().trim().toLowerCase();
  }

  bool _isEstadoActivo(dynamic estadoRaw) {
    final estado = _normalizeText(estadoRaw);

    return estado == 'aceptado' ||
        estado == 'en camino' ||
        estado == 'en_camino' ||
        estado == 'encamino' ||
        estado == 'en curso' ||
        estado == 'en_curso' ||
        estado == 'encurso';
  }

  String _estadoBonito(dynamic estadoRaw) {
    final estado = _normalizeText(estadoRaw);

    if (estado == 'aceptado') return 'Aceptado';
    if (estado == 'en camino' ||
        estado == 'en_camino' ||
        estado == 'encamino') {
      return 'En camino';
    }
    if (estado == 'en curso' ||
        estado == 'en_curso' ||
        estado == 'encurso') {
      return 'En curso';
    }
    if (estado == 'entregado') return 'Entregado';
    if (estado == 'cancelado') return 'Cancelado';
    if (estado == 'pendiente') return 'Pendiente';

    final raw = (estadoRaw ?? '').toString().trim();
    if (raw.isEmpty) return 'Pendiente';
    return raw;
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
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error al cargar pedidos',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Palette.ink.withOpacity(0.6),
              ),
            ),
          );
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          return _isEstadoActivo(data['estado']);
        }).toList();

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

          final fechaEnvio = _tsToDate(data['fecha_envio']);
          final day = fechaEnvio == null ? null : _dayKey(fechaEnvio);

          return {
            'id': doc.id,
            'data': {
              ...data,
              'estado': _estadoBonito(data['estado']),
            },
            'dist': dist,
            'fecha_envio': fechaEnvio,
            'day': day,
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

        // ✅ Prioridad: los que ya están en camino van primero.
        bool esEnCamino(Map<String, dynamic> p) {
          final e = ((p['data'] as Map<String, dynamic>)['estado'] ?? '')
              .toString();
          return e == 'En camino' || e == 'En curso';
        }

        final enCamino = pedidos.where(esEnCamino).toList();

        // ✅ el resto: agrupamos por día (según fecha_envio)
        final Map<DateTime, List<Map<String, dynamic>>> grouped = {};
        final List<Map<String, dynamic>> sinFecha = [];

        for (final p in pedidos.where((p) => !esEnCamino(p))) {
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
        // En camino: el más cercano primero.
        enCamino.sort(
          (a, b) => (a['dist'] as double).compareTo(b['dist'] as double),
        );

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

        // ✅ lista ordenada (sección + pedido): En camino, luego por día,
        // luego sin fecha.
        final entradas = <(String, Map<String, dynamic>)>[
          for (final p in enCamino) ('En camino', p),
          for (final day in dayKeys)
            for (final p in grouped[day]!) (_labelForDay(day, todayKey), p),
          for (final p in sinFecha) ('Sin fecha', p),
        ];

        // 📄 Paginación de 6 en 6.
        final totalPages = (entradas.length / _pageSize).ceil();
        final safePage = _page.clamp(0, totalPages - 1);
        if (safePage != _page) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _page = safePage);
          });
        }
        final pagina = entradas.skip(safePage * _pageSize).take(_pageSize);

        // ✅ render: headers + cards (el encabezado se repite si una
        // sección continúa en la página siguiente).
        final children = <Widget>[];
        String? seccionActual;

        for (final (seccion, p) in pagina) {
          if (seccion != seccionActual) {
            seccionActual = seccion;
            children.add(_SectionHeader(title: seccion));
          }

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
              child: _PedidoCard(data: data, distanciaKm: p['dist'] as double),
            ),
          );
        }

        if (totalPages > 1) {
          children.add(
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: PillPaginationBar(
                currentPage: safePage,
                totalPages: totalPages,
                totalItems: entradas.length,
                pageSize: _pageSize,
                itemLabel: 'pedidos',
                onChanged: (p) => setState(() => _page = p),
              ),
            ),
          );
        }

        return ListView(
          // Nueva página → vuelve arriba.
          key: ValueKey('viajes-$safePage'),
          // La barra de navegación flota sobre el contenido (extendBody):
          // se deja su espacio al final para que no tape la paginación.
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          children: children,
        );
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
    if (x.contains('camino') || x.contains('ruta') || x.contains('curso') || x.contains('proceso')) {
      return Colors.orange.withOpacity(0.18);
    }
    if (x.contains('acept')) return Palette.primary.withOpacity(0.14);
    if (x.contains('pend')) return Colors.orange.withOpacity(0.14);
    return Palette.primary.withOpacity(0.12);
  }

  Color _fg(String s) {
    final x = s.trim().toLowerCase();
    if (x.contains('entreg')) return Palette.statsSuccess;
    if (x.contains('cancel') || x.contains('rechaz')) {
      return Palette.statsDanger;
    }
    if (x.contains('camino') || x.contains('ruta') || x.contains('curso') || x.contains('proceso')) {
      return Colors.orange.shade800;
    }
    if (x.contains('acept')) return Palette.primary;
    if (x.contains('pend')) return Colors.orange.shade800;
    return Palette.primary;
  }

  IconData _icon(String s) {
    final x = s.trim().toLowerCase();
    if (x.contains('entreg')) return Icons.check_circle_rounded;
    if (x.contains('cancel') || x.contains('rechaz')) {
      return Icons.cancel_rounded;
    }
    if (x.contains('camino') || x.contains('ruta') || x.contains('curso')) {
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
/// 👤 DATOS DEL CLIENTE (usuarios/{uid})
/// =======================================================
class _Cliente {
  final String nombre;
  final String email;
  final String foto;

  const _Cliente({this.nombre = '', this.email = '', this.foto = ''});
}

/// Una consulta por cliente mientras la app está abierta: los redibujos
/// de la lista (cada minuto por la ubicación) no vuelven a leer Firestore.
class _ClienteCache {
  static final Map<String, Future<_Cliente>> _cache = {};

  static Future<_Cliente> get(String uid) {
    if (uid.isEmpty) return Future.value(const _Cliente());
    return _cache.putIfAbsent(uid, () => _fetch(uid));
  }

  static Future<_Cliente> _fetch(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();
      final d = doc.data() ?? const <String, dynamic>{};
      String s(dynamic v) => (v ?? '').toString().trim();
      return _Cliente(
        nombre: s(d['name'] ?? d['nombre']),
        email: s(d['email']),
        foto: s(d['photo'] ?? d['photoUrl']),
      );
    } catch (_) {
      // Sin permiso o sin conexión: se reintenta la próxima vez.
      _cache.remove(uid);
      return const _Cliente();
    }
  }
}

class _ClienteAvatar extends StatelessWidget {
  const _ClienteAvatar({required this.cliente});

  final _Cliente cliente;

  @override
  Widget build(BuildContext context) {
    final inicial = cliente.nombre.isNotEmpty
        ? cliente.nombre.characters.first.toUpperCase()
        : '';

    final sinFoto = CircleAvatar(
      radius: 26,
      backgroundColor: Palette.button.withOpacity(0.18),
      child: inicial.isEmpty
          ? Icon(Icons.person, color: Palette.primary)
          : Text(
              inicial,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                color: Palette.primary,
              ),
            ),
    );

    if (cliente.foto.isEmpty) return sinFoto;

    return ClipOval(
      child: Image.network(
        cliente.foto,
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => sinFoto,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : sinFoto,
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

    final clienteUid = (data['uid'] ?? data['clienteUid'] ?? '')
        .toString()
        .trim();
    final total = ((data['total'] as num?) ?? 0).toDouble();

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
          /// HEADER: cliente (avatar, nombre, correo) + ubicación + estado
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<_Cliente>(
                  future: _ClienteCache.get(clienteUid),
                  builder: (context, snap) {
                    final c = snap.data ?? const _Cliente();
                    final cargando =
                        snap.connectionState == ConnectionState.waiting;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ClienteAvatar(cliente: c),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.nombre.isNotEmpty
                                    ? c.nombre
                                    : (cargando ? 'Cargando…' : 'Cliente'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: Palette.ink,
                                ),
                              ),
                              if (c.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  c.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Palette.ink.withOpacity(0.7),
                                  ),
                                ),
                              ],
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
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Ubicación debajo del cliente (mismo tamaño de letra).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 20,
                      color: Palette.primary.withOpacity(0.85),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        direccion.isEmpty ? 'Sin dirección' : direccion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _EstadoChip(estado: estado),
              ],
            ),
          ),

          Divider(height: 1, color: Palette.ink.withOpacity(0.06)),

          /// PRODUCTOS
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: items.map((i) {
                final qty = ((i['qty'] ?? i['cantidad'] ?? 1) as num).toDouble();
                final price = ((i['price'] ?? i['precio'] ?? 0) as num).toDouble();
                final subtotal = qty * price;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          (i['imageUrl'] ?? '').toString(),
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return Container(
                              width: 52,
                              height: 52,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported_outlined),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (i['name'] ?? i['nombre'] ?? '').toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Palette.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Cantidad: ${qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2)}',
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