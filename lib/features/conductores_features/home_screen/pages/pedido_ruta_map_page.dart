// lib/features/conductores_features/home_screen/pages/pedido_ruta_map_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/services/repartidor_servicio_localizacion.dart';

class PedidoRutaMapPage extends StatefulWidget {
  final String pedidoId;
  final String repartidorUid;

  const PedidoRutaMapPage({
    super.key,
    required this.pedidoId,
    required this.repartidorUid,
  });

  @override
  State<PedidoRutaMapPage> createState() => _PedidoRutaMapPageState();
}

class _PedidoRutaMapPageState extends State<PedidoRutaMapPage> {
  static const String _mapboxToken = 'TOKEN_MAPBOX';
  static const String _styleUri = "mapbox://styles/mapbox/streets-v12";

  // tamaños burbuja
  static const double _pngSize = 160;
  static const double _bubbleRadius = 55;
  static const double _iconFontSize = 70;

  // tamaño en mapa + “flotante”
  static const double _mapIconSize = 1.55;
  static const double _floatOffsetPx = 16.0;
  static const double _floatInsidePngPx = 10.0;

  // Ruta
  static const double _routeWidth = 7.0;

  // reglas de actualización de ruta
  static const double _routeUpdateMinMoveMeters = 50.0;
  static const Duration _routeUpdateMinInterval = Duration(seconds: 6);

  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();

  // Servicio que ESCRIBE en RTDB
  final RepartidorLocationService _locationService = RepartidorLocationService();

  // RTDB solo se activa cuando esté "En camino"
  bool _rtdbActive = false;

  mb.MapboxMap? _map;
  mb.PointAnnotationManager? _pointManager;

  StreamSubscription<DatabaseEvent>? _repartidorSub;

  double? _aLat;
  double? _aLng;
  double? _bLat;
  double? _bLng;

  String? _pedidoCodigo;
  String? _pedidoDireccion;
  String? _pedidoEstado;

  bool _loading = true;
  String? _error;

  bool _changingEstado = false;
  bool _fetchingRoute = false;

  // no mover cámara cada update
  bool _didInitialCameraFit = false;

  static const String _routeSourceId = 'route-source';
  static const String _routePinkLayerId = 'route-pink-layer';

  mb.PointAnnotation? _aMarker;
  mb.PointAnnotation? _bMarker;

  // PNGs
  Uint8List? _truckMarkerPng;
  Uint8List? _bagMarkerPng;

  // si tu versión no soporta iconOffset
  bool _supportsIconOffset = true;

  // control de actualización ruta
  DateTime _lastRouteUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  double? _lastRouteALat, _lastRouteALng;
  double? _lastRouteBLat, _lastRouteBLng;

  @override
  void initState() {
    super.initState();
    _prepareMarkerImages();
    _loadPedidoData();
  }

  @override
  void dispose() {
    _stopRealtime();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Activar/Desactivar RTDB
  // ─────────────────────────────────────────────
  Future<void> _startRealtimeIfNeeded() async {
    if (_rtdbActive) return;

    _rtdbActive = true;

    await _locationService.start(uid: widget.repartidorUid);
    _listenRepartidorLocation();
  }

  Future<void> _stopRealtime() async {
    await _repartidorSub?.cancel();
    _repartidorSub = null;

    if (!_rtdbActive) return;

    _rtdbActive = false;
    _locationService.stop();

    try {
      await _locationService.clear(widget.repartidorUid);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // MARKERS
  // ─────────────────────────────────────────────
  Future<void> _prepareMarkerImages() async {
    final truck = await _materialIconBubblePng(
      icon: Icons.local_shipping_rounded,
      iconColor: Palette.primary,
      borderColor: Palette.button,
    );

    final bag = await _materialIconBubblePng(
      icon: Icons.shopping_bag_rounded,
      iconColor: Palette.secButton,
      borderColor: Palette.button,
    );

    if (!mounted) return;
    setState(() {
      _truckMarkerPng = truck;
      _bagMarkerPng = bag;
    });

    _updateMarkersAndRoute();
  }

  Future<Uint8List> _materialIconBubblePng({
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final center = Offset(_pngSize / 2, _pngSize / 2 - _floatInsidePngPx);

    final shadowPath = ui.Path()
      ..addOval(Rect.fromCircle(center: center, radius: _bubbleRadius));
    canvas.drawShadow(shadowPath, Colors.black.withOpacity(0.30), 14, true);

    final fillPaint = ui.Paint()
      ..color = Palette.white
      ..style = ui.PaintingStyle.fill;
    canvas.drawCircle(center, _bubbleRadius, fillPaint);

    final strokePaint = ui.Paint()
      ..color = borderColor
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 7;
    canvas.drawCircle(center, _bubbleRadius, strokePaint);

    final iconChar = String.fromCharCode(icon.codePoint);
    final tp = TextPainter(
      text: TextSpan(
        text: iconChar,
        style: TextStyle(
          fontSize: _iconFontSize,
          color: iconColor,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2 - 2),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(_pngSize.toInt(), _pngSize.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  // ─────────────────────────────────────────────
  // RTDB repartidor
  // ─────────────────────────────────────────────
  void _listenRepartidorLocation() {
    _repartidorSub?.cancel();
    _repartidorSub = null;

    final ref = _rtdb.child('repartidores/${widget.repartidorUid}');

    _repartidorSub = ref.onValue.listen(
      (event) {
        final v = event.snapshot.value;

        if (v is Map) {
          final map = Map<String, dynamic>.from(v as Map);

          final lat = _toDouble(map['lat'] ?? map['latitude']);
          final lng = _toDouble(map['lng'] ?? map['longitude']);

          if (lat != null && lng != null) {
            _aLat = lat;
            _aLng = lng;
            _updateMarkersAndRoute();
          }
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() => _error = 'Error RTDB: $e');
      },
    );
  }

  // ─────────────────────────────────────────────
  // Cargar pedido
  // ─────────────────────────────────────────────
  Future<void> _loadPedidoData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId)
          .get();

      final data = doc.data();
      if (data == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Pedido no encontrado';
          _loading = false;
        });
        return;
      }

      _pedidoCodigo = (data['codigo'] ?? '').toString().trim();
      if (_pedidoCodigo!.isEmpty) _pedidoCodigo = null;

      _pedidoEstado = (data['estado'] ?? '').toString().trim();
      if (_pedidoEstado!.isEmpty) _pedidoEstado = null;

      final ubicacion = (data['ubicacion'] as Map?) ?? {};
      final u = Map<String, dynamic>.from(ubicacion as Map);

      _pedidoDireccion =
          (u['direccion'] ?? data['direccion'] ?? '').toString().trim();
      if (_pedidoDireccion!.isEmpty) _pedidoDireccion = null;

      final lat = _toDouble(u['lat']);
      final lng = _toDouble(u['lng']);

      if (lat == null || lng == null) {
        if (!mounted) return;
        setState(() {
          _error = 'El pedido no tiene ubicacion.lat / ubicacion.lng';
          _loading = false;
        });
        return;
      }

      _bLat = lat;
      _bLng = lng;

      final st = (_pedidoEstado ?? '').trim().toLowerCase();
      if (st == 'en camino') {
        await _startRealtimeIfNeeded();
      }

      if (!mounted) return;
      setState(() => _loading = false);

      _updateMarkersAndRoute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error cargando pedido: $e';
        _loading = false;
      });
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // ─────────────────────────────────────────────
  // Mapbox
  // ─────────────────────────────────────────────
  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _map = map;

    await _map!.loadStyleURI(_styleUri);

    _pointManager = await _map!.annotations.createPointAnnotationManager();

    await _ensureRouteStyle();
    _updateMarkersAndRoute();
  }

  Future<void> _ensureRouteStyle() async {
    final style = _map!.style;

    final hasSource = await style.styleSourceExists(_routeSourceId);
    if (!hasSource) {
      await style.addSource(
        mb.GeoJsonSource(
          id: _routeSourceId,
          data: jsonEncode({"type": "FeatureCollection", "features": []}),
        ),
      );
    }

    final hasLayer = await style.styleLayerExists(_routePinkLayerId);
    if (!hasLayer) {
      await style.addLayer(
        mb.LineLayer(
          id: _routePinkLayerId,
          sourceId: _routeSourceId,
          lineJoin: mb.LineJoin.ROUND,
          lineCap: mb.LineCap.ROUND,
          lineWidth: _routeWidth,
          lineColor: Palette.button.value,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Marcadores + ruta + cámara
  // ─────────────────────────────────────────────
  Future<void> _updateMarkersAndRoute() async {
    if (_map == null) return;

    await _updateMarkers();

    if (!_didInitialCameraFit) {
      final did = await _fitCameraIfPossible();
      if (did) _didInitialCameraFit = true;
    }

    if (_shouldUpdateRouteNow()) {
      await _drawRoute();
    }
  }

  Future<void> _updateMarkers() async {
    if (_pointManager == null) return;

    if (_aLat != null && _aLng != null) {
      final aPoint = mb.Point(coordinates: mb.Position(_aLng!, _aLat!));

      if (_aMarker == null) {
        _aMarker = await _createFloatingPoint(
          geometry: aPoint,
          png: _truckMarkerPng,
        );
      } else {
        _aMarker!.geometry = aPoint;
        if (_aMarker!.image == null && _truckMarkerPng != null) {
          _aMarker!.image = _truckMarkerPng;
        }
        await _safeUpdatePoint(_aMarker!);
      }
    }

    if (_bLat != null && _bLng != null) {
      final bPoint = mb.Point(coordinates: mb.Position(_bLng!, _bLat!));

      if (_bMarker == null) {
        _bMarker = await _createFloatingPoint(
          geometry: bPoint,
          png: _bagMarkerPng,
        );
      } else {
        _bMarker!.geometry = bPoint;
        if (_bMarker!.image == null && _bagMarkerPng != null) {
          _bMarker!.image = _bagMarkerPng;
        }
        await _safeUpdatePoint(_bMarker!);
      }
    }
  }

  Future<mb.PointAnnotation?> _createFloatingPoint({
    required mb.Point geometry,
    required Uint8List? png,
  }) async {
    if (_pointManager == null) return null;

    if (_supportsIconOffset) {
      try {
        return await _pointManager!.create(
          mb.PointAnnotationOptions(
            geometry: geometry,
            image: png,
            iconSize: _mapIconSize,
            iconOffset: [0.0, -_floatOffsetPx],
          ),
        );
      } catch (_) {
        _supportsIconOffset = false;
      }
    }

    return await _pointManager!.create(
      mb.PointAnnotationOptions(
        geometry: geometry,
        image: png,
        iconSize: _mapIconSize,
      ),
    );
  }

  Future<void> _safeUpdatePoint(mb.PointAnnotation ann) async {
    if (_pointManager == null) return;
    try {
      await _pointManager!.update(ann);
    } catch (_) {}
  }

  Future<bool> _fitCameraIfPossible() async {
    if (_map == null) return false;

    if (_aLat != null && _aLng != null && _bLat != null && _bLng != null) {
      final midLat = (_aLat! + _bLat!) / 2;
      final midLng = (_aLng! + _bLng!) / 2;

      await _map!.setCamera(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position(midLng, midLat)),
          zoom: 12.4,
        ),
      );
      return true;
    }

    if (_aLat != null && _aLng != null) {
      await _map!.setCamera(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position(_aLng!, _aLat!)),
          zoom: 14.0,
        ),
      );
      return true;
    }

    if (_bLat != null && _bLng != null) {
      await _map!.setCamera(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position(_bLng!, _bLat!)),
          zoom: 14.0,
        ),
      );
      return true;
    }

    return false;
  }

  // ─────────────────────────────────────────────
  // Lógica de actualización de ruta
  // ─────────────────────────────────────────────
  bool _coordsChanged(double? lat1, double? lng1, double? lat2, double? lng2) {
    if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
      return true;
    }
    return (lat1 - lat2).abs() > 1e-6 || (lng1 - lng2).abs() > 1e-6;
  }

  double _deg2rad(double deg) => deg * (Math.pi / 180.0);

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);

    final a = (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
        Math.cos(_deg2rad(lat1)) *
            Math.cos(_deg2rad(lat2)) *
            (Math.sin(dLon / 2) * Math.sin(dLon / 2));

    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  bool _shouldUpdateRouteNow() {
    if (_aLat == null || _aLng == null || _bLat == null || _bLng == null) {
      return false;
    }

    final noPrevious = _lastRouteALat == null || _lastRouteALng == null;
    if (noPrevious) return true;

    if (_coordsChanged(_bLat, _bLng, _lastRouteBLat, _lastRouteBLng)) {
      return true;
    }

    final now = DateTime.now();
    if (now.difference(_lastRouteUpdateAt) >= _routeUpdateMinInterval) {
      return true;
    }

    final moved =
        _haversineMeters(_aLat!, _aLng!, _lastRouteALat!, _lastRouteALng!);
    return moved >= _routeUpdateMinMoveMeters;
  }

  // ─────────────────────────────────────────────
  // Directions
  // ─────────────────────────────────────────────
  Future<void> _drawRoute() async {
    if (_fetchingRoute) return;
    if (_aLat == null || _aLng == null || _bLat == null || _bLng == null) {
      return;
    }

    _fetchingRoute = true;

    try {
      final aLng = _aLng!;
      final aLat = _aLat!;
      final bLng = _bLng!;
      final bLat = _bLat!;

      final url =
          'https://api.mapbox.com/directions/v5/mapbox/driving/'
          '$aLng,$aLat;$bLng,$bLat'
          '?geometries=geojson&overview=full&access_token=$_mapboxToken';

      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return;

      final json = jsonDecode(res.body);
      final routes = (json['routes'] as List?) ?? [];
      if (routes.isEmpty) return;

      final geometry = routes.first['geometry'];
      final coords = (geometry?['coordinates'] as List?) ?? [];

      final featureCollection = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {},
            "geometry": {
              "type": "LineString",
              "coordinates": coords,
            },
          },
        ],
      };

      final style = _map!.style;
      final source = await style.getSource(_routeSourceId);
      if (source is mb.GeoJsonSource) {
        await source.updateGeoJSON(jsonEncode(featureCollection));
      }

      _lastRouteUpdateAt = DateTime.now();
      _lastRouteALat = aLat;
      _lastRouteALng = aLng;
      _lastRouteBLat = bLat;
      _lastRouteBLng = bLng;
    } catch (_) {
      //
    } finally {
      _fetchingRoute = false;
    }
  }

  // ─────────────────────────────────────────────
  // BOTÓN ESTADO
  // ─────────────────────────────────────────────
  Future<void> _toggleEstadoPedido() async {
    if (_changingEstado) return;

    final current = (_pedidoEstado ?? '').trim().toLowerCase();
    if (current == 'entregado') return;

    final next = current == 'en camino' ? 'Entregado' : 'En camino';

    setState(() => _changingEstado = true);

    try {
      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId)
          .update({
        'estado': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _pedidoEstado = next);

      final nextLower = next.trim().toLowerCase();
      if (nextLower == 'en camino') {
        await _startRealtimeIfNeeded();
      } else if (nextLower == 'entregado') {
        await _stopRealtime();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextLower == 'entregado'
                ? 'Pedido marcado como entregado. Se notificará al cliente.'
                : 'Estado actualizado: $next',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error actualizando estado: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _changingEstado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _pedidoCodigo != null ? 'Pedido $_pedidoCodigo' : 'Pedido';

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Palette.ink,
          ),
        ),
        iconTheme: IconThemeData(color: Palette.ink),
      ),
      body: Stack(
        children: [
          mb.MapWidget(
            key: const ValueKey('mapbox-pedido-ruta'),
            onMapCreated: _onMapCreated,
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _InfoBar(
              aOk: _aLat != null && _aLng != null,
              bOk: _bLat != null && _bLng != null,
              loading: _loading,
              error: _error,
              pedidoDireccion: _pedidoDireccion,
              estado: _pedidoEstado,
              changingEstado: _changingEstado,
              onToggleEstado: _toggleEstadoPedido,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBar extends StatelessWidget {
  final bool aOk;
  final bool bOk;
  final bool loading;
  final String? error;
  final String? pedidoDireccion;

  final String? estado;
  final bool changingEstado;
  final VoidCallback onToggleEstado;

  const _InfoBar({
    required this.aOk,
    required this.bOk,
    required this.loading,
    required this.error,
    required this.pedidoDireccion,
    required this.estado,
    required this.changingEstado,
    required this.onToggleEstado,
  });

  @override
  Widget build(BuildContext context) {
    final mainText = (pedidoDireccion != null && pedidoDireccion!.isNotEmpty)
        ? pedidoDireccion!
        : 'Dirección no disponible';

    final statusText = error != null
        ? error!
        : loading
            ? 'Cargando pedido...'
            : (!aOk)
                ? 'Esperando ubicación del repartidor...'
                : (!bOk)
                    ? 'Esperando ubicación del pedido...'
                    : 'Mostrando ruta';

    final st = (estado ?? '').trim().toLowerCase();
    final isEntregado = st == 'entregado';
    final isEnCamino = st == 'en camino';

    final buttonText = isEntregado
        ? 'Entregado'
        : isEnCamino
            ? 'Marcar como Entregado'
            : 'Marcar En Camino';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Palette.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Palette.primary.withOpacity(0.10)),
      ),
      child: Row(
        children: [
          Icon(
            error != null
                ? Icons.error_rounded
                : (aOk && bOk)
                    ? Icons.route_rounded
                    : Icons.gps_fixed_rounded,
            color: error != null ? Palette.statsDanger : Palette.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mainText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Palette.ink.withOpacity(0.88),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Palette.ink.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: (changingEstado || isEntregado) ? null : onToggleEstado,
              style: ElevatedButton.styleFrom(
                backgroundColor: Palette.button,
                disabledBackgroundColor: Palette.ink.withOpacity(0.15),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: changingEstado
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      buttonText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}