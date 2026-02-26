import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'package:quimisol_movil/core/theme/palette.dart';

class PedidosMapaPage extends StatefulWidget {
  const PedidosMapaPage({super.key});

  @override
  State<PedidosMapaPage> createState() => _PedidosMapaPageState();
}

class _PedidosMapaPageState extends State<PedidosMapaPage> {
  mb.MapboxMap? _map;
  mb.PointAnnotationManager? _pointManager;
  bool _mapReady = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // pedidoId -> item
  final Map<String, _PedidoMapaItem> _items = {};

  // annotationId -> pedidoId
  final Map<String, String> _annToPedido = {};

  // cache: pedidoId -> marker png bytes
  final Map<String, Uint8List> _markerCache = {};

  // cache: pedidoId -> key "codigo|fotoUrl" para saber si regenerar
  final Map<String, String> _markerKeyCache = {};

  // cache: uid -> photoUrl (o null)
  final Map<String, String?> _userPhotoCache = {};

  Timer? _debounce;

  _PedidoMapaItem? _selected;

  @override
  void initState() {
    super.initState();
    _listenPedidos();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 🔥 LISTEN: /pedidos (TODOS)
  // ─────────────────────────────────────────────
  void _listenPedidos() {
    final pedidosRef = FirebaseFirestore.instance.collection('pedidos');

    _sub = pedidosRef.snapshots().listen((snap) async {
      _items.clear();

      // 1) Construir items base (sin foto aún)
      for (final doc in snap.docs) {
        final data = doc.data();

        final u = (data['ubicacion'] as Map?)?.cast<String, dynamic>() ?? {};
        final lat = (u['lat'] as num?)?.toDouble();
        final lng = (u['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final codigo = (data['codigo'] ?? '').toString().trim().isNotEmpty
            ? (data['codigo'] ?? '').toString()
            : doc.id;

        final estado = (data['estado'] ?? '').toString();
        final direccion = (u['direccion'] ?? data['direccion'] ?? '')
            .toString();
        final uid = (u['uid'] ?? '').toString();

        _items[doc.id] = _PedidoMapaItem(
          id: doc.id,
          codigo: codigo,
          estado: estado,
          direccion: direccion,
          lat: lat,
          lng: lng,
          usuarioUid: uid,
          fotoUrl: null,
        );
      }

      // 2) Cargar fotos de usuarios faltantes
      final uids = _items.values
          .map((e) => e.usuarioUid)
          .where((e) => e.trim().isNotEmpty)
          .toSet()
          .toList();

      final missingUids = uids
          .where((uid) => !_userPhotoCache.containsKey(uid))
          .toList();

      if (missingUids.isNotEmpty) {
        await Future.wait(missingUids.map(_fetchAndCacheUserPhoto));
      }

      // 3) Asignar fotoUrl a cada pedido desde cache
      for (final entry in _items.entries.toList()) {
        final it = entry.value;
        final photo = it.usuarioUid.trim().isEmpty
            ? null
            : _userPhotoCache[it.usuarioUid];
        _items[entry.key] = it.copyWith(fotoUrl: photo);
      }

      // 4) Render con debounce
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 180), () async {
        if (!_mapReady) return;
        await _renderMarkers();
        await _fitToAllPedidos();
      });
    });
  }

  // ─────────────────────────────────────────────
  // 👤 Trae foto del usuario (uid) desde Firestore
  // ─────────────────────────────────────────────
  Future<void> _fetchAndCacheUserPhoto(String uid) async {
    try {
      // ✅ intento 1: /usuarios/{uid}
      final usuariosDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(uid)
          .get();

      if (usuariosDoc.exists) {
        final data = usuariosDoc.data(); //as Map<String, dynamic>?;
        _userPhotoCache[uid] = _pickPhotoUrl(data);
        return;
      }

      // ✅ intento 2: /users/{uid}
      final usersDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (usersDoc.exists) {
        final data = usersDoc.data(); //as Map<String, dynamic>?;
        _userPhotoCache[uid] = _pickPhotoUrl(data);
        return;
      }

      _userPhotoCache[uid] = null;
    } catch (_) {
      _userPhotoCache[uid] = null;
    }
  }

  String? _pickPhotoUrl(Map<String, dynamic>? data) {
    if (data == null) return null;

    const keys = [
      'photoUrl',
      'fotoUrl',
      'photoURL',
      'profilePhoto',
      'profilePhotoUrl',
      'imagenUrl',
      'imageUrl',
      'avatarUrl',
      'avatar',
    ];

    for (final k in keys) {
      final v = data[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // 🗺️ RENDER MARKERS
  // ─────────────────────────────────────────────
  Future<void> _renderMarkers() async {
    if (!_mapReady || _pointManager == null) return;

    await _pointManager!.deleteAll();
    _annToPedido.clear();

    // limpia cache de markers que ya no existen
    _markerCache.removeWhere((pedidoId, _) => !_items.containsKey(pedidoId));
    _markerKeyCache.removeWhere((pedidoId, _) => !_items.containsKey(pedidoId));

    for (final item in _items.values) {
      final key = '${item.codigo}|${item.fotoUrl ?? ''}';

      Uint8List bytes;
      final cached = _markerCache[item.id];
      final cachedKey = _markerKeyCache[item.id];

      if (cached != null && cachedKey == key) {
        bytes = cached;
      } else {
        bytes = await _buildMarkerBytes(
          codigo: item.codigo,
          fotoUrl: item.fotoUrl,
        );
        _markerCache[item.id] = bytes;
        _markerKeyCache[item.id] = key;
      }

      final ann = await _pointManager!.create(
        mb.PointAnnotationOptions(
          geometry: mb.Point(coordinates: mb.Position(item.lng, item.lat)),
          image: bytes,
          iconSize: 1.0,
        ),
      );

      _annToPedido[ann.id] = item.id;
    }

    // listener tap
    _pointManager!.addOnPointAnnotationClickListener(
      _PointTapListener(
        onTap: (annotation) {
          final pedidoId = _annToPedido[annotation.id];
          if (pedidoId == null) return;
          final it = _items[pedidoId];
          if (it == null) return;

          setState(() => _selected = it);

          _map?.easeTo(
            mb.CameraOptions(
              center: mb.Point(coordinates: mb.Position(it.lng, it.lat)),
              zoom: 15.5,
            ),
            mb.MapAnimationOptions(duration: 500),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 🎯 FIT: encuadrar todos
  // ─────────────────────────────────────────────
  Future<void> _fitToAllPedidos() async {
    if (_map == null || _items.isEmpty) return;

    double minLng = _items.values.first.lng;
    double maxLng = _items.values.first.lng;
    double minLat = _items.values.first.lat;
    double maxLat = _items.values.first.lat;

    for (final p in _items.values) {
      if (p.lng < minLng) minLng = p.lng;
      if (p.lng > maxLng) maxLng = p.lng;
      if (p.lat < minLat) minLat = p.lat;
      if (p.lat > maxLat) maxLat = p.lat;
    }

    final bounds = mb.CoordinateBounds(
      southwest: mb.Point(coordinates: mb.Position(minLng, minLat)),
      northeast: mb.Point(coordinates: mb.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );

    final padding = mb.MbxEdgeInsets(
      top: 120,
      left: 40,
      bottom: 260,
      right: 40,
    );

    final cam = await _map!.cameraForCoordinateBounds(
      bounds,
      padding,
      0.0,
      0.0,
      null,
      null,
    );

    await _map!.easeTo(cam, mb.MapAnimationOptions(duration: 650));
  }

  // ─────────────────────────────────────────────
  // 🧩 Marker PNG: foto circular + badge codigo
  // (SIN const donde hay toDouble)
  // ─────────────────────────────────────────────
  Future<Uint8List> _buildMarkerBytes({
    required String codigo,
    String? fotoUrl,
  }) async {
    const int w = 220;
    const int h = 260;

    final double wd = w.toDouble();
    final double hd = h.toDouble();

    const double circleR = 78;
    const double cx = 110; // w/2 = 110
    const double cy = 95;

    const double badgeW = 180;
    const double badgeH = 56;
    const double badgeY = 185;

    ui.Image? avatar;

    if (fotoUrl != null && fotoUrl.trim().isNotEmpty) {
      try {
        avatar = await _loadNetworkImage(fotoUrl);
      } catch (_) {
        avatar = null;
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, wd, hd));

    // transparente
    canvas.drawRect(
      Rect.fromLTWH(0, 0, wd, hd),
      Paint()..color = const Color(0x00000000),
    );

    // sombra círculo
    canvas.drawCircle(
      const Offset(cx, cy + 6),
      circleR + 6,
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    // borde blanco
    canvas.drawCircle(
      const Offset(cx, cy),
      circleR + 6,
      Paint()..color = Colors.white,
    );

    // clip círculo
    final clipPath = Path()
      ..addOval(Rect.fromCircle(center: const Offset(cx, cy), radius: circleR));

    canvas.save();
    canvas.clipPath(clipPath);

    if (avatar != null) {
      final src = Rect.fromLTWH(
        0,
        0,
        avatar.width.toDouble(),
        avatar.height.toDouble(),
      );
      final dst = Rect.fromCircle(
        center: const Offset(cx, cy),
        radius: circleR,
      );
      canvas.drawImageRect(avatar, src, dst, Paint());
    } else {
      canvas.drawRect(
        Rect.fromCircle(center: const Offset(cx, cy), radius: circleR),
        Paint()..color = Palette.primary.withValues(alpha: 0.95),
      );

      final initial = codigo.trim().isNotEmpty
          ? codigo.trim()[0].toUpperCase()
          : '?';

      final tp = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    }

    canvas.restore();

    // badge pill
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(cx, badgeY),
        width: badgeW,
        height: badgeH,
      ),
      const Radius.circular(999),
    );

    // sombra badge
    canvas.drawRRect(
      rrect.shift(const Offset(0, 5)),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );

    canvas.drawRRect(rrect, Paint()..color = Palette.button);

    // texto codigo
    final codePainter = TextPainter(
      text: TextSpan(
        text: codigo,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: badgeW - 22);

    codePainter.paint(
      canvas,
      Offset(cx - codePainter.width / 2, badgeY - codePainter.height / 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(w, h);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<ui.Image> _loadNetworkImage(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('No image');
    final bytes = res.bodyBytes;

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.fieldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Palette.gradientStart.withValues(alpha: 0.45),
                Palette.gradientEnd.withValues(alpha: 0.65),
              ],
            ),
          ),
        ),
        title: Text(
          'Mapa de pedidos (${_items.length})',
          style: TextStyle(color: Palette.ink, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Centrar todos',
            icon: Icon(Icons.center_focus_strong_rounded, color: Palette.ink),
            onPressed: _fitToAllPedidos,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        children: [
          mb.MapWidget(
            styleUri: 'mapbox://styles/mapbox/streets-v12',
            cameraOptions: mb.CameraOptions(zoom: 12),
            onMapCreated: (map) async {
              _map = map;
              _pointManager = await map.annotations
                  .createPointAnnotationManager();
              _mapReady = true;

              await _renderMarkers();
              await _fitToAllPedidos();
            },
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _selected == null
                    ? _buildHintPanel()
                    : _buildSelectedPanel(_selected!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintPanel() {
    return Container(
      key: const ValueKey('hint'),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Text(
        _items.isEmpty
            ? 'No hay pedidos con ubicación.'
            : 'Toca un pedido en el mapa para ver detalle.',
        style: TextStyle(
          color: Palette.ink.withValues(alpha: 0.75),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildSelectedPanel(_PedidoMapaItem it) {
    return Container(
      key: const ValueKey('selected'),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Palette.button.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  it.codigo,
                  style: TextStyle(
                    color: Palette.button,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  it.estado,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Palette.ink.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            it.direccion.isEmpty ? 'Sin dirección' : it.direccion,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'UID: ${it.usuarioUid.isEmpty ? "N/A" : it.usuarioUid}',
            style: TextStyle(
              color: Palette.ink.withValues(alpha: 0.6),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _selected = null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Palette.ink,
                    side: BorderSide(
                      color: Palette.ink.withValues(alpha: 0.18),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Cerrar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Modular.to.pushNamed('/pedido', arguments: it.id);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.button,
                    foregroundColor: Palette.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'Ver pedido',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────
class _PedidoMapaItem {
  final String id;
  final String codigo;
  final String estado;
  final String direccion;
  final double lat;
  final double lng;
  final String usuarioUid;
  final String? fotoUrl;

  _PedidoMapaItem({
    required this.id,
    required this.codigo,
    required this.estado,
    required this.direccion,
    required this.lat,
    required this.lng,
    required this.usuarioUid,
    required this.fotoUrl,
  });

  _PedidoMapaItem copyWith({String? fotoUrl}) {
    return _PedidoMapaItem(
      id: id,
      codigo: codigo,
      estado: estado,
      direccion: direccion,
      lat: lat,
      lng: lng,
      usuarioUid: usuarioUid,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }
}

// ─────────────────────────────────────────────
// TAP LISTENER
// ─────────────────────────────────────────────
class _PointTapListener extends mb.OnPointAnnotationClickListener {
  final void Function(mb.PointAnnotation annotation) onTap;
  _PointTapListener({required this.onTap});

  @override
  bool onPointAnnotationClick(mb.PointAnnotation annotation) {
    onTap(annotation);
    return true;
  }
}
