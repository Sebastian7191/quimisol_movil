// lib/features/conductores_features/home_screen/pages/pedido_ruta_map_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _mapboxToken =
      'MAPBOX_TOKEN';
  static const String _styleUri = "mapbox://styles/mapbox/streets-v12";
  static const String _prefSkipStartConfirm = 'skip_start_pedido_confirm';

  static const double _pngSize = 160;
  static const double _bubbleRadius = 55;
  static const double _iconFontSize = 70;

  static const double _mapIconSize = 1.55;
  static const double _floatOffsetPx = 16.0;
  static const double _floatInsidePngPx = 10.0;

  static const double _routeWidth = 7.0;

  static const double _routeUpdateMinMoveMeters = 50.0;
  static const Duration _routeUpdateMinInterval = Duration(seconds: 6);

  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref();
  final RepartidorLocationService _locationService = RepartidorLocationService();

  bool _rtdbActive = false;

  mb.MapboxMap? _map;
  mb.PointAnnotationManager? _pointManager;

  StreamSubscription<DatabaseEvent>? _repartidorSub;
  StreamSubscription<Position>? _previewPositionSub;

  double? _aLat;
  double? _aLng;
  double? _bLat;
  double? _bLng;

  String? _pedidoCodigo;
  String? _pedidoDireccion;
  String? _pedidoEstado;
  String? _pedidoEstadoPago;
  double? _pedidoMontoTotal;

  List<Map<String, dynamic>> _pedidoItems = [];

  bool _loading = true;
  String? _error;

  bool _changingEstado = false;
  bool _fetchingRoute = false;
  bool _skipStartConfirm = false;

  bool _didInitialCameraFit = false;

  static const String _routeSourceId = 'route-source';
  static const String _routePinkLayerId = 'route-pink-layer';

  mb.PointAnnotation? _aMarker;
  mb.PointAnnotation? _bMarker;

  Uint8List? _truckMarkerPng;
  Uint8List? _bagMarkerPng;

  bool _supportsIconOffset = true;

  DateTime _lastRouteUpdateAt = DateTime.fromMillisecondsSinceEpoch(0);
  double? _lastRouteALat, _lastRouteALng;
  double? _lastRouteBLat, _lastRouteBLng;

  double? _ultimaDistanciaKm;
  double? _ultimaDuracionMin;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _prepareMarkerImages();
    _initPreviewLocation();
    _loadPedidoData();
  }

  @override
  void dispose() {
    _previewPositionSub?.cancel();
    _stopRealtime();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _skipStartConfirm = prefs.getBool(_prefSkipStartConfirm) ?? false;
  }

  Future<void> _setSkipStartConfirm(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefSkipStartConfirm, value);
    _skipStartConfirm = value;
  }

  Future<void> _initPreviewLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _error = 'Permiso de ubicación denegado';
          });
        }
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _error = 'Activa la ubicación del dispositivo para ver la ruta';
          });
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _aLat = pos.latitude;
      _aLng = pos.longitude;
      _updateMarkersAndRoute();

      _previewPositionSub?.cancel();
      _previewPositionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((pos) {
        _aLat = pos.latitude;
        _aLng = pos.longitude;
        _updateMarkersAndRoute();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo obtener tu ubicación actual';
      });
    }
  }

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

      _pedidoEstadoPago = (data['estado_pago'] ?? data['estadoPago'] ?? '')
          .toString()
          .trim();
      if (_pedidoEstadoPago!.isEmpty) _pedidoEstadoPago = null;

      final totalRaw = data['total'];
      if (totalRaw is num) {
        _pedidoMontoTotal = totalRaw.toDouble();
      } else {
        _pedidoMontoTotal = double.tryParse((totalRaw ?? '').toString());
      }

      final ubicacion = (data['ubicacion'] as Map?) ?? {};
      final u = Map<String, dynamic>.from(ubicacion as Map);

      _pedidoDireccion =
          (u['direccion'] ?? data['direccion'] ?? '').toString().trim();
      if (_pedidoDireccion!.isEmpty) _pedidoDireccion = null;

      final rawItems = (data['items'] is List)
          ? List<Map<String, dynamic>>.from(data['items'] as List)
          : <Map<String, dynamic>>[];
      _pedidoItems = rawItems;

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

  Future<void> _onMapCreated(mb.MapboxMap map) async {
    _map = map;

    await _map!.loadStyleURI(_styleUri);
    _pointManager = await _map!.annotations.createPointAnnotationManager();

    await _hideScaleBar();
    await _ensureRouteStyle();
    _updateMarkersAndRoute();
  }

  Future<void> _hideScaleBar() async {
    if (_map == null) return;
    try {
      await _map!.scaleBar.updateSettings(
        mb.ScaleBarSettings(
          enabled: false,
        ),
      );
    } catch (_) {}
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

      final firstRoute = routes.first as Map<String, dynamic>;
      final geometry = firstRoute['geometry'];
      final coords = (geometry?['coordinates'] as List?) ?? [];

      final distanceMeters = _toDouble(firstRoute['distance']);
      final durationSeconds = _toDouble(firstRoute['duration']);

      if (distanceMeters != null) {
        _ultimaDistanciaKm = distanceMeters / 1000.0;
      }

      if (durationSeconds != null) {
        _ultimaDuracionMin = durationSeconds / 60.0;
      }

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

      if (mounted) setState(() {});
    } catch (_) {
      //
    } finally {
      _fetchingRoute = false;
    }
  }

  Future<bool> _showStartConfirmSheet() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Palette.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Palette.ink.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Palette.button.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: Palette.button,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '¿Deseas iniciar este pedido?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Palette.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se marcará como En camino y comenzará el seguimiento activo del pedido.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Palette.ink.withOpacity(0.68),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await _setSkipStartConfirm(true);
                          if (!mounted) return;
                          Navigator.pop(ctx, true);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.button,
                          side: const BorderSide(color: Palette.button),
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'No mostrar más',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.button,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Sí, iniciar',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );

    return result == true;
  }

  Future<void> _toggleEstadoPedido() async {
    if (_changingEstado) return;

    final current = (_pedidoEstado ?? '').trim().toLowerCase();
    if (current == 'entregado') return;

    final next = current == 'en camino' ? 'Entregado' : 'En camino';
    final nextLower = next.trim().toLowerCase();

    if (nextLower == 'en camino' && !_skipStartConfirm) {
      final confirmed = await _showStartConfirmSheet();
      if (!confirmed) return;
    }

    setState(() => _changingEstado = true);

    try {
      if (nextLower == 'en camino' &&
          _aLat != null &&
          _aLng != null &&
          _bLat != null &&
          _bLng != null) {
        await _drawRoute();
      }

      final updateData = <String, dynamic>{
        'estado': next,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (nextLower == 'en camino' && _ultimaDistanciaKm != null) {
        updateData['kilometraje'] = {
          'distanciaKm': double.parse(_ultimaDistanciaKm!.toStringAsFixed(2)),
          'fechaEnCamino': FieldValue.serverTimestamp(),
          'repartidorUid': widget.repartidorUid,
          if (_ultimaDuracionMin != null)
            'duracionEstimadaMin':
                double.parse(_ultimaDuracionMin!.toStringAsFixed(1)),
        };
      }

      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId)
          .update(updateData);

      if (!mounted) return;
      setState(() => _pedidoEstado = next);

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
          DraggableScrollableSheet(
            initialChildSize: 0.27,
            minChildSize: 0.14,
            maxChildSize: 0.68,
            snap: true,
            snapSizes: const [0.14, 0.27, 0.48, 0.68],
            builder: (context, scrollController) {
              return _BottomInfoPanel(
                scrollController: scrollController,
                aOk: _aLat != null && _aLng != null,
                bOk: _bLat != null && _bLng != null,
                loading: _loading,
                error: _error,
                pedidoDireccion: _pedidoDireccion,
                estado: _pedidoEstado,
                estadoPago: _pedidoEstadoPago,
                montoTotal: _pedidoMontoTotal,
                changingEstado: _changingEstado,
                onToggleEstado: _toggleEstadoPedido,
                distanciaKm: _ultimaDistanciaKm,
                duracionMin: _ultimaDuracionMin,
                items: _pedidoItems,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BottomInfoPanel extends StatefulWidget {
  final ScrollController scrollController;
  final bool aOk;
  final bool bOk;
  final bool loading;
  final String? error;
  final String? pedidoDireccion;
  final String? estado;
  final String? estadoPago;
  final double? montoTotal;
  final bool changingEstado;
  final VoidCallback onToggleEstado;
  final double? distanciaKm;
  final double? duracionMin;
  final List<Map<String, dynamic>> items;

  const _BottomInfoPanel({
    required this.scrollController,
    required this.aOk,
    required this.bOk,
    required this.loading,
    required this.error,
    required this.pedidoDireccion,
    required this.estado,
    required this.estadoPago,
    required this.montoTotal,
    required this.changingEstado,
    required this.onToggleEstado,
    required this.distanciaKm,
    required this.duracionMin,
    required this.items,
  });

  @override
  State<_BottomInfoPanel> createState() => _BottomInfoPanelState();
}

class _BottomInfoPanelState extends State<_BottomInfoPanel> {
  bool _showLista = false;

  String _itemName(Map<String, dynamic> item) {
    final a = (item['name'] ?? '').toString().trim();
    if (a.isNotEmpty) return a;
    final b = (item['nombre'] ?? '').toString().trim();
    if (b.isNotEmpty) return b;
    return 'Producto';
  }

  String _itemImage(Map<String, dynamic> item) {
    return (item['imageUrl'] ?? '').toString().trim();
  }

  int _itemQty(Map<String, dynamic> item) {
    final q = item['qty'] ?? item['cantidad'] ?? 1;
    if (q is num) return q.toInt();
    return int.tryParse(q.toString()) ?? 1;
  }

  double _itemPrice(Map<String, dynamic> item) {
    final p = item['price'] ?? item['precio'] ?? 0;
    if (p is num) return p.toDouble();
    return double.tryParse(p.toString()) ?? 0;
  }

  String _estadoPagoBonito(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.contains('pag')) return 'Pagado';
    if (s.contains('rech')) return 'Rechazado';
    return 'Pendiente';
  }

  Color _estadoPagoColor(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s.contains('pag')) return Palette.statsSuccess;
    if (s.contains('rech')) return Palette.statsDanger;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final mainText =
        (widget.pedidoDireccion != null && widget.pedidoDireccion!.isNotEmpty)
        ? widget.pedidoDireccion!
        : 'Dirección no disponible';

    final statusText = widget.error != null
        ? widget.error!
        : widget.loading
            ? 'Cargando pedido...'
            : (!widget.aOk)
                ? 'Esperando tu ubicación actual...'
                : (!widget.bOk)
                    ? 'Esperando ubicación del pedido...'
                    : 'Mostrando ruta';

    final st = (widget.estado ?? '').trim().toLowerCase();
    final isEntregado = st == 'entregado';
    final isEnCamino = st == 'en camino';

    final buttonText = isEntregado
        ? 'Entregado'
        : isEnCamino
            ? 'Marcar como Entregado'
            : 'Marcar En Camino';

    final kmText = widget.distanciaKm != null
        ? '${widget.distanciaKm!.toStringAsFixed(2)} km'
        : '— km';

    final minText = widget.duracionMin != null
        ? '${widget.duracionMin!.toStringAsFixed(0)} min'
        : '— min';

    final totalText = widget.montoTotal != null
        ? 'Bs ${widget.montoTotal!.toStringAsFixed(2)}'
        : '—';

    final firstItem = widget.items.isNotEmpty ? widget.items.first : null;
    final hasMoreItems = widget.items.length > 1;
    final pagoColor = _estadoPagoColor(widget.estadoPago);

    return Container(
      decoration: BoxDecoration(
        color: Palette.white.withOpacity(0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 22,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border.all(color: Palette.primary.withOpacity(0.08)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: widget.scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Palette.ink.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (widget.error != null
                              ? Palette.statsDanger
                              : Palette.primary)
                          .withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.error != null
                          ? Icons.error_rounded
                          : (widget.aOk && widget.bOk)
                              ? Icons.route_rounded
                              : Icons.gps_fixed_rounded,
                      color: widget.error != null
                          ? Palette.statsDanger
                          : Palette.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mainText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Palette.ink.withOpacity(0.88),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          statusText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.2,
                            color: Palette.ink.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MiniInfoChip(
                      icon: Icons.straighten_rounded,
                      label: 'Distancia',
                      value: kmText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniInfoChip(
                      icon: Icons.schedule_rounded,
                      label: 'Tiempo',
                      value: minText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniInfoChip(
                      icon: Icons.payments_rounded,
                      label: 'Monto',
                      value: totalText,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.fieldBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Palette.primary.withOpacity(0.07),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 18,
                            color: pagoColor,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pago',
                                  style: TextStyle(
                                    color: Palette.ink.withOpacity(0.58),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _estadoPagoBonito(widget.estadoPago),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: pagoColor,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (firstItem != null) ...[
                const SizedBox(height: 12),
                _PedidoMiniItemCard(
                  name: _itemName(firstItem),
                  imageUrl: _itemImage(firstItem),
                  qty: _itemQty(firstItem),
                  price: _itemPrice(firstItem),
                ),
              ],
              if (hasMoreItems) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => setState(() => _showLista = !_showLista),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.fieldBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Palette.primary.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_rounded,
                          size: 18,
                          color: Palette.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lista del pedido (${widget.items.length})',
                            style: const TextStyle(
                              color: Palette.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          _showLista
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: Palette.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_showLista && widget.items.length > 1) ...[
                const SizedBox(height: 10),
                Column(
                  children: widget.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _PedidoMiniItemCard(
                        name: _itemName(item),
                        imageUrl: _itemImage(item),
                        qty: _itemQty(item),
                        price: _itemPrice(item),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed:
                      (widget.changingEstado || isEntregado)
                          ? null
                          : widget.onToggleEstado,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Palette.button,
                    disabledBackgroundColor: Palette.ink.withOpacity(0.15),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: widget.changingEstado
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
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Palette.primary.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Palette.primary),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Palette.ink.withOpacity(0.58),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.8,
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

class _PedidoMiniItemCard extends StatelessWidget {
  final String name;
  final String imageUrl;
  final int qty;
  final double price;

  const _PedidoMiniItemCard({
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Palette.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Palette.primary.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isEmpty
                ? Container(
                    width: 52,
                    height: 52,
                    color: Colors.white,
                    child: const Icon(Icons.image_outlined),
                  )
                : Image.network(
                    imageUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        width: 52,
                        height: 52,
                        color: Colors.white,
                        child: const Icon(Icons.broken_image_outlined),
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
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Palette.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 12.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cant: $qty • Bs ${price.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Palette.ink.withOpacity(0.66),
                    fontWeight: FontWeight.w700,
                    fontSize: 11.8,
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