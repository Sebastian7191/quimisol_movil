import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'package:quimisol_movil/core/theme/palette.dart';

class PedidoEnCursoPage extends StatefulWidget {
  final String pedidoId;
  final String repartidorUid;

  const PedidoEnCursoPage({
    super.key,
    required this.pedidoId,
    required this.repartidorUid,
  });

  @override
  State<PedidoEnCursoPage> createState() => _PedidoEnCursoPageState();
}

class _PedidoEnCursoPageState extends State<PedidoEnCursoPage> {
  // ✅ Token SOLO para Directions HTTP
  static const String _mapboxToken =
      'pk.eyJ1Ijoic2ViYXMxMjciLCJhIjoiY21mMGhhdDRiMG5mbTJscHlnMGUweGlicSJ9.SVeyu-4RTAybmgRxhPxSWw';

  mb.MapboxMap? _map;
  mb.PolylineAnnotationManager? _polylineManager;
  mb.PointAnnotationManager? _pointManager;

  mb.Point? _pedidoPoint;
  mb.Point? _repartidorPoint;

  String _direccion = '';
  String _codigoPedido = '';
  String _estado = ''; // ← Aceptado / En camino / Completado
  double _distanciaKm = 0;
  int _etaMin = 0;

  late final DatabaseReference _repartidorRef;
  StreamSubscription<DatabaseEvent>? _rtdbSub;

  bool _mapReady = false;

  // ✅ Para centrar cada 20s SOLO si está "En camino"
  Timer? _recenterTimer;
  mb.CoordinateBounds? _lastRouteBounds;

  // ✅ Anti-spam de requests Directions
  DateTime _lastDirectionsAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _loadPedido();
    _listenRTDB();
  }

  @override
  void dispose() {
    _rtdbSub?.cancel();
    _recenterTimer?.cancel();
    super.dispose();
  }

  bool get _isEnCamino => _estado.trim().toLowerCase() == 'en camino';

  // ─────────────────────────────────────────────
  // 📍 PEDIDO (FIRESTORE)
  // ─────────────────────────────────────────────
  Future<void> _loadPedido() async {
    final doc = await FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId)
        .get();

    final data = doc.data();
    if (data == null) return;

    final u = (data['ubicacion'] as Map?)?.cast<String, dynamic>() ?? {};
    final lat = (u['lat'] as num?)?.toDouble();
    final lng = (u['lng'] as num?)?.toDouble();

    if (lat == null || lng == null) return;

    _pedidoPoint = mb.Point(coordinates: mb.Position(lng, lat));

    setState(() {
      _direccion = (u['direccion'] ?? '').toString();
      _codigoPedido = (data['codigo'] ?? '').toString();
      _estado = (data['estado'] ?? '').toString();
    });

    _syncRecenterTimer();
    _drawRoute(); // por si ya hay RTDB
  }

  // ─────────────────────────────────────────────
  // 📡 REPARTIDOR (RTDB – SOLO LECTURA)
  // ─────────────────────────────────────────────
  void _listenRTDB() {
    _repartidorRef = FirebaseDatabase.instance.ref(
      'repartidores/${widget.repartidorUid}',
    );

    _rtdbSub = _repartidorRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final raw = event.snapshot.value;
      if (raw is! Map) return;

      final data = raw.cast<dynamic, dynamic>();

      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) return;

      _repartidorPoint = mb.Point(coordinates: mb.Position(lng, lat));

      _drawRoute(); // ← se recalcula ruta con cada update RTDB
    });
  }

  // ─────────────────────────────────────────────
  // 🚗 RUTA DE AUTO (MAPBOX DIRECTIONS)
  // ─────────────────────────────────────────────
  Future<void> _drawRoute() async {
    if (!_mapReady || _pedidoPoint == null || _repartidorPoint == null) return;

    // ✅ throttle (evita pegarle a Directions cada 3s)
    final now = DateTime.now();
    if (now.difference(_lastDirectionsAt).inSeconds < 6) return;
    _lastDirectionsAt = now;

    final o = _repartidorPoint!.coordinates;
    final d = _pedidoPoint!.coordinates;

    // pedimos 2 rutas (principal + alternativa)
    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${o.lng},${o.lat};${d.lng},${d.lat}'
      '?geometries=geojson&overview=full&alternatives=true'
      '&access_token=$_mapboxToken',
    );

    final res = await http.get(uri);
    if (res.statusCode != 200) return;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? [];
    if (routes.isEmpty) return;

    final mainRoute = routes.first as Map<String, dynamic>;
    final altRoute = routes.length > 1
        ? routes[1] as Map<String, dynamic>
        : null;

    final mainGeo = (mainRoute['geometry'] as Map<String, dynamic>?) ?? {};
    final mainCoordsRaw = (mainGeo['coordinates'] as List?) ?? [];

    final mainPositions = mainCoordsRaw
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map(
          (c) =>
              mb.Position((c[0] as num).toDouble(), (c[1] as num).toDouble()),
        )
        .toList();

    if (mainPositions.length < 2) return;

    // stats
    final distMeters = (mainRoute['distance'] as num?)?.toDouble() ?? 0.0;
    final durSeconds = (mainRoute['duration'] as num?)?.toDouble() ?? 0.0;

    setState(() {
      _distanciaKm = distMeters / 1000.0;
      _etaMin = (durSeconds / 60.0).round();
    });

    // bounds de la ruta para recenter cada 20s
    _lastRouteBounds = _boundsFromPositions(mainPositions);

    // draw
    await _polylineManager?.deleteAll();

    // principal (rosa suave)
    await _polylineManager?.create(
      mb.PolylineAnnotationOptions(
        geometry: mb.LineString(coordinates: mainPositions),
        lineColor: Palette.button.value,
        lineWidth: 7,
        lineOpacity: 0.95,
      ),
    );

    // alternativa (morado suave)
    if (altRoute != null) {
      final altGeo = (altRoute['geometry'] as Map<String, dynamic>?) ?? {};
      final altCoordsRaw = (altGeo['coordinates'] as List?) ?? [];

      final altPositions = altCoordsRaw
          .whereType<List>()
          .where((c) => c.length >= 2)
          .map(
            (c) =>
                mb.Position((c[0] as num).toDouble(), (c[1] as num).toDouble()),
          )
          .toList();

      if (altPositions.length >= 2) {
        await _polylineManager?.create(
          mb.PolylineAnnotationOptions(
            geometry: mb.LineString(coordinates: altPositions),
            lineColor: Palette.secondary.value,
            lineWidth: 5,
            lineOpacity: 0.60,
          ),
        );
      }
    }

    // markers (puntos)
    await _pointManager?.deleteAll();

    // 📍 Pedido (rojo)
    await _pointManager?.create(
      mb.PointAnnotationOptions(
        geometry: _pedidoPoint!,
        iconImage: "marker-15",
        iconSize: 1.5,
      ),
    );

    // 🚚 Repartidor (morado)
    await _pointManager?.create(
      mb.PointAnnotationOptions(
        geometry: _repartidorPoint!,
        iconImage: "car-15",
        iconSize: 1.6,
      ),
    );

    // si está en camino, el recenter lo hace el timer cada 20s.
    // si NO está en camino, hacemos un fit una sola vez para que se vea bien al entrar.
    if (!_isEnCamino) {
      await _fitToRouteBounds();
    }
  }

  // ─────────────────────────────────────────────
  // 🎯 FIT A TODA LA RUTA (cada 20s)
  // ─────────────────────────────────────────────
  void _syncRecenterTimer() {
    _recenterTimer?.cancel();

    if (_isEnCamino) {
      _recenterTimer = Timer.periodic(
        const Duration(seconds: 20),
        (_) => _fitToRouteBounds(),
      );
    }
  }

  Future<void> _fitToRouteBounds() async {
    if (_map == null || _lastRouteBounds == null) return;

    // padding: arriba un poco (appbar) y abajo bastante (modal)
    final padding = mb.MbxEdgeInsets(
      top: 110,
      left: 40,
      bottom: 320,
      right: 40,
    );

    // ✅ OJO: en v2.x pide 6 args posicionales (ponemos null en los que no usamos)
    final cam = await _map!.cameraForCoordinateBounds(
      _lastRouteBounds!,
      padding,
      0.0, // bearing
      0.0, // pitch
      null, // maxZoom
      null, // offset o minZoom (según plataforma)
    );

    await _map!.easeTo(cam, mb.MapAnimationOptions(duration: 850));
  }

  mb.CoordinateBounds _boundsFromPositions(List<mb.Position> coords) {
    if (coords.isEmpty) {
      // Evita StateError por coords.first
      return mb.CoordinateBounds(
        southwest: mb.Point(coordinates: mb.Position(0.0, 0.0)),
        northeast: mb.Point(coordinates: mb.Position(0.0, 0.0)),
        infiniteBounds: false,
      );
    }

    double minLng = coords.first.lng.toDouble();
    double maxLng = coords.first.lng.toDouble();
    double minLat = coords.first.lat.toDouble();
    double maxLat = coords.first.lat.toDouble();

    for (final p in coords) {
      final lng = p.lng.toDouble();
      final lat = p.lat.toDouble();

      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
    }

    return mb.CoordinateBounds(
      southwest: mb.Point(coordinates: mb.Position(minLng, minLat)),
      northeast: mb.Point(coordinates: mb.Position(maxLng, maxLat)),
      infiniteBounds: false,
    );
  }

  // ─────────────────────────────────────────────
  // 🔘 BOTÓN (lo dejé igual que tu versión actual)
  // ─────────────────────────────────────────────
  Future<void> _marcarEnCurso() async {
    await FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId)
        .update({'estado': 'En camino'});

    // refresca estado local
    setState(() => _estado = 'En camino');
    _syncRecenterTimer();
  }

  @override
  Widget build(BuildContext context) {
    final titleCode = _codigoPedido.isNotEmpty
        ? _codigoPedido
        : widget.pedidoId;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      appBar: AppBar(
        backgroundColor: Palette.button,
        foregroundColor: Palette.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Pedido: $titleCode',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Stack(
        children: [
          mb.MapWidget(
            styleUri: 'mapbox://styles/mapbox/streets-v12',
            cameraOptions: mb.CameraOptions(zoom: 15),
            onMapCreated: (map) async {
              _map = map;
              _polylineManager = await map.annotations
                  .createPolylineAnnotationManager();
              _pointManager = await map.annotations
                  .createPointAnnotationManager();
              _mapReady = true;

              // si ya tenemos puntos, dibuja
              _drawRoute();

              // si ya estaba en camino al entrar, activa recenter
              _syncRecenterTimer();
            },
          ),

          // ⬇️ MODAL INFERIOR
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, -10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Palette.ink.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Text(
                      _direccion,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$_etaMin min · ${_distanciaKm.toStringAsFixed(2)} km',
                      style: TextStyle(
                        fontSize: 13,
                        color: Palette.ink.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _marcarEnCurso,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.button,
                          foregroundColor: Palette.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Marcar en curso',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
