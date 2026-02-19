import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

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
  // ✅ Token SOLO para Directions HTTP (el SDK del mapa ya está en main.dart)
  static const String _mapboxToken =
      'TOKEN_MAPBOX';

  final http.Client _http = http.Client();

  mb.MapboxMap? _map;
  mb.PolylineAnnotationManager? _polylineManager;
  mb.PointAnnotationManager? _pointManager;

  // Se crean 1 vez, luego update
  mb.PointAnnotation? _pedidoAnn;
  mb.PointAnnotation? _repartidorAnn;
  mb.PolylineAnnotation? _routeAnn;

  // puntos
  mb.Point? _pedidoPoint;
  mb.Point? _repartidorPoint;

  // UI
  String _direccion = '';
  String _codigoPedido = '';
  String _estado = '';
  double _distanciaKm = 0;
  int _etaMin = 0;

  // listeners
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pedidoSub;
  late final DatabaseReference _repartidorRef;
  StreamSubscription<DatabaseEvent>? _rtdbSub;

  // map ready
  bool _styleLoaded = false;

  // fit/recenter
  Timer? _recenterTimer;
  mb.CoordinateBounds? _lastRouteBounds;
  bool _didInitialFit = false;

  // Directions control
  DateTime _lastDirectionsAt = DateTime.fromMillisecondsSinceEpoch(0);
  mb.Position? _lastDirectionsOrigin;
  Timer? _directionsDebounce;

  bool get _isEnCamino => _estado.trim().toLowerCase() == 'en camino';

  @override
  void initState() {
    super.initState();
    _listenPedidoRealtime();
    _listenRTDB();
  }

  @override
  void dispose() {
    _directionsDebounce?.cancel();
    _recenterTimer?.cancel();
    _rtdbSub?.cancel();
    _pedidoSub?.cancel();
    _http.close();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 📍 Pedido realtime (Firestore)
  // ─────────────────────────────────────────────
  void _listenPedidoRealtime() {
    _pedidoSub = FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId)
        .snapshots()
        .listen((doc) {
      final data = doc.data();
      if (data == null) return;

      final u = (data['ubicacion'] as Map?)?.cast<String, dynamic>() ?? {};
      final lat = (u['lat'] as num?)?.toDouble();
      final lng = (u['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      _pedidoPoint = mb.Point(coordinates: mb.Position(lng, lat));

      if (mounted) {
        setState(() {
          _direccion = (u['direccion'] ?? '').toString();
          _codigoPedido = (data['codigo'] ?? '').toString();
          _estado = (data['estado'] ?? '').toString();
        });
      }

      _syncRecenterTimer();

      // marker pedido (si el estilo ya cargó)
      _updatePedidoMarker();

      // ruta si ya hay repartidor
      _scheduleDirections(force: true);
    });
  }

  // ─────────────────────────────────────────────
  // 📡 Repartidor realtime (RTDB)
  // ─────────────────────────────────────────────
  void _listenRTDB() {
    _repartidorRef =
        FirebaseDatabase.instance.ref('repartidores/${widget.repartidorUid}');

    _rtdbSub = _repartidorRef.onValue.listen((event) {
      if (!event.snapshot.exists) return;

      final raw = event.snapshot.value;
      if (raw is! Map) return;
      final data = raw.cast<dynamic, dynamic>();

      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      _repartidorPoint = mb.Point(coordinates: mb.Position(lng, lat));

      // ✅ rápido: solo mueve el marker
      _updateRepartidorMarker();

      // ✅ ruta: debounce + threshold + throttle
      _scheduleDirections();
    });
  }

  // ─────────────────────────────────────────────
  // 🗺️ Style loaded (viene desde MapWidget)
  // OJO: lo pongo con dynamic para que compile en tu versión sí o sí
  // ─────────────────────────────────────────────
  Future<void> _onStyleLoaded(dynamic _) async {
    if (_map == null) return;

    _styleLoaded = true;

    // managers solo 1 vez
    _polylineManager ??=
        await _map!.annotations.createPolylineAnnotationManager();
    _pointManager ??= await _map!.annotations.createPointAnnotationManager();

    // crea/actualiza lo que ya exista
    await _updatePedidoMarker();
    await _updateRepartidorMarker();

    // intenta ruta
    _scheduleDirections(force: true);

    // recenter si aplica
    _syncRecenterTimer();
  }

  // ─────────────────────────────────────────────
  // 📌 Markers (crear una vez, luego update)
  // ─────────────────────────────────────────────
  Future<void> _updatePedidoMarker() async {
    if (!_styleLoaded || _pointManager == null || _pedidoPoint == null) return;

    if (_pedidoAnn == null) {
      _pedidoAnn = await _pointManager!.create(
        mb.PointAnnotationOptions(
          geometry: _pedidoPoint!,
          iconImage: "marker-15",
          iconSize: 1.5,
        ),
      );
    } else {
      _pedidoAnn!.geometry = _pedidoPoint!;
      await _pointManager!.update(_pedidoAnn!);
    }
  }

  Future<void> _updateRepartidorMarker() async {
    if (!_styleLoaded ||
        _pointManager == null ||
        _repartidorPoint == null) return;

    if (_repartidorAnn == null) {
      _repartidorAnn = await _pointManager!.create(
        mb.PointAnnotationOptions(
          geometry: _repartidorPoint!,
          iconImage: "car-15",
          iconSize: 1.6,
        ),
      );
    } else {
      _repartidorAnn!.geometry = _repartidorPoint!;
      await _pointManager!.update(_repartidorAnn!);
    }
  }

  // ─────────────────────────────────────────────
  // 🚗 Directions: threshold + debounce + throttle
  // ─────────────────────────────────────────────
  void _scheduleDirections({bool force = false}) {
    if (!_styleLoaded || _map == null) return;
    if (_pedidoPoint == null || _repartidorPoint == null) return;

    final o = _repartidorPoint!.coordinates;

    // threshold: si se movió poco, no recalcular ruta
    if (!force && _lastDirectionsOrigin != null) {
      final movedM = _haversineMeters(
        (_lastDirectionsOrigin!.lat).toDouble(),
        (_lastDirectionsOrigin!.lng).toDouble(),
        (o.lat).toDouble(),
        (o.lng).toDouble(),
      );
      if (movedM < 35) return;
    }

    _directionsDebounce?.cancel();
    _directionsDebounce = Timer(const Duration(milliseconds: 650), () {
      _drawRoute(force: force);
    });
  }

  Future<void> _drawRoute({bool force = false}) async {
    if (!_styleLoaded ||
        _map == null ||
        _polylineManager == null ||
        _pedidoPoint == null ||
        _repartidorPoint == null) return;

    // throttle: no pegarle a directions cada ratito
    final now = DateTime.now();
    if (!force && now.difference(_lastDirectionsAt).inSeconds < 10) return;
    _lastDirectionsAt = now;

    final o = _repartidorPoint!.coordinates;
    final d = _pedidoPoint!.coordinates;
    _lastDirectionsOrigin = o;

    final uri = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/driving/'
      '${o.lng},${o.lat};${d.lng},${d.lat}'
      '?geometries=geojson&overview=full&alternatives=false'
      '&access_token=$_mapboxToken',
    );

    http.Response res;
    try {
      res = await _http.get(uri).timeout(const Duration(seconds: 8));
    } catch (_) {
      return;
    }
    if (res.statusCode != 200) return;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = (json['routes'] as List?) ?? [];
    if (routes.isEmpty) return;

    final mainRoute = routes.first as Map<String, dynamic>;
    final mainGeo = (mainRoute['geometry'] as Map<String, dynamic>?) ?? {};
    final coordsRaw = (mainGeo['coordinates'] as List?) ?? [];

    final positions = coordsRaw
        .whereType<List>()
        .where((c) => c.length >= 2)
        .map((c) => mb.Position(
              (c[0] as num).toDouble(),
              (c[1] as num).toDouble(),
            ))
        .toList();

    if (positions.length < 2) return;

    // stats
    final distMeters = (mainRoute['distance'] as num?)?.toDouble() ?? 0.0;
    final durSeconds = (mainRoute['duration'] as num?)?.toDouble() ?? 0.0;

    if (mounted) {
      setState(() {
        _distanciaKm = distMeters / 1000.0;
        _etaMin = (durSeconds / 60.0).round();
      });
    }

    // bounds
    _lastRouteBounds = _boundsFromPositions(positions);

    // polyline: crear 1 vez, luego update (sin deleteAll)
    if (_routeAnn == null) {
      _routeAnn = await _polylineManager!.create(
        mb.PolylineAnnotationOptions(
          geometry: mb.LineString(coordinates: positions),
          lineColor: Palette.button.value,
          lineWidth: 7,
          lineOpacity: 0.95,
        ),
      );
    } else {
      _routeAnn!.geometry = mb.LineString(coordinates: positions);
      await _polylineManager!.update(_routeAnn!);
    }

    // Fit 1 sola vez si NO está en camino
    if (!_isEnCamino && !_didInitialFit) {
      _didInitialFit = true;
      await _fitToRouteBounds();
    }
  }

  // ─────────────────────────────────────────────
  // 🎯 Fit / Recenter
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

    final padding = mb.MbxEdgeInsets(
      top: 110,
      left: 40,
      bottom: 320,
      right: 40,
    );

    final cam = await _map!.cameraForCoordinateBounds(
      _lastRouteBounds!,
      padding,
      0.0,
      0.0,
      null,
      null,
    );

    await _map!.easeTo(cam, mb.MapAnimationOptions(duration: 700));
  }

  mb.CoordinateBounds _boundsFromPositions(List<mb.Position> coords) {
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

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180.0);

  // ─────────────────────────────────────────────
  // 🔘 Botón
  // ─────────────────────────────────────────────
  Future<void> _marcarEnCurso() async {
    await FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId)
        .update({'estado': 'En camino'});

    setState(() => _estado = 'En camino');
    _syncRecenterTimer();
  }

  @override
  Widget build(BuildContext context) {
    final titleCode =
        _codigoPedido.isNotEmpty ? _codigoPedido : widget.pedidoId;

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
        actions: [
          IconButton(
            tooltip: 'Centrar ruta',
            onPressed: _fitToRouteBounds,
            icon: const Icon(Icons.center_focus_strong_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          mb.MapWidget(
            styleUri: 'mapbox://styles/mapbox/streets-v12',
            cameraOptions: mb.CameraOptions(zoom: 15),
            onMapCreated: (map) {
              _map = map;
              // no dibujar aquí; espera style loaded
            },
            // ✅ aquí va el listener (no en _map)
            onStyleLoadedListener: _onStyleLoaded,
          ),

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
                      _direccion.isEmpty ? 'Sin dirección' : _direccion,
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
