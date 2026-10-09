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
import 'package:quimisol_movil/core/config/mapbox_config.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/shared/widgets/producto_imagen.dart';
import 'package:quimisol_movil/features/conductores_features/home_screen/services/kilometraje_service.dart';
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
  static const String _mapboxToken = MapboxConfig.accessToken;
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
  final RepartidorLocationService _locationService =
      RepartidorLocationService();

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
  String? _tipoPago;
  String? _clienteUid;
  double? _pedidoMontoTotal;

  List<Map<String, dynamic>> _pedidoItems = [];

  bool _loading = true;
  String? _error;

  bool _changingEstado = false;
  bool _marcandoPagado = false;
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

  // ── Kilometraje (ruta inicial + desvíos) ──
  final KilometrajeService _kmService = KilometrajeService();

  /// Ya se guardó la ruta inicial de este viaje.
  bool _kmIniciado = false;
  bool _kmIniciando = false;

  /// Día ("yyyy-MM-dd") al que se suman los km de este viaje.
  String? _kmFecha;

  /// Lo que faltaba según el recálculo anterior. Si el nuevo recálculo
  /// marca más, la diferencia es un desvío.
  double? _restantePrevKm;
  double? _restantePrevMin;

  String? _repartidorNombre;
  String? _departamento;

  /// Por debajo de esto se considera ruido del GPS / recálculo.
  static const double _umbralDesvioKm = 0.05;
  static const double _umbralDesvioMin = 0.25;

  /// Escucha el pago en vivo: si el admin confirma un QR (o se marca pagado
  /// desde otro lado) el botón de entregar se habilita sin reabrir el mapa.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pagoSub;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _prepareMarkerImages();
    _initPreviewLocation();
    _loadPedidoData();

    _pagoSub = FirebaseFirestore.instance
        .collection('pedidos')
        .doc(widget.pedidoId)
        .snapshots()
        .listen((snap) {
          final data = snap.data();
          if (data == null || !mounted) return;
          final pago = (data['estado_pago'] ?? data['estadoPago'] ?? '')
              .toString()
              .trim();
          if (pago.isNotEmpty && pago != _pedidoEstadoPago) {
            setState(() => _pedidoEstadoPago = pago);
          }
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _pagoSub?.cancel();
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
      _previewPositionSub =
          Geolocator.getPositionStream(
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

      _tipoPago =
          (data['tipo_pago'] ?? data['tipoPago'] ?? data['metodoPago'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
      if (_tipoPago!.isEmpty) _tipoPago = null;

      _clienteUid =
          (data['uid'] ?? data['clienteUid'] ?? data['uidCliente'] ?? '')
              .toString()
              .trim();
      if (_clienteUid!.isEmpty) _clienteUid = null;

      final totalRaw = data['total'];
      if (totalRaw is num) {
        _pedidoMontoTotal = totalRaw.toDouble();
      } else {
        _pedidoMontoTotal = double.tryParse((totalRaw ?? '').toString());
      }

      final ubicacion = (data['ubicacion'] as Map?) ?? {};
      final u = Map<String, dynamic>.from(ubicacion as Map);

      _pedidoDireccion = (u['direccion'] ?? data['direccion'] ?? '')
          .toString()
          .trim();
      if (_pedidoDireccion!.isEmpty) _pedidoDireccion = null;

      _repartidorNombre =
          (data['repartidorNombre'] ?? data['repartidor_nombre'] ?? '')
              .toString()
              .trim();
      _departamento = (data['departamento'] ?? '').toString().trim();

      // Si el viaje ya había empezado (se volvió a abrir el mapa), se sigue
      // sumando al mismo día sin volver a contar la ruta inicial.
      final km = data['kilometraje'];
      if (km is Map &&
          (km['distanciaInicialKm'] != null || km['distanciaKm'] != null)) {
        _kmIniciado = true;
        final f = (km['fecha'] ?? '').toString().trim();
        final ts = km['fechaEnCamino'];
        _kmFecha = f.isNotEmpty
            ? f
            : KilometrajeService.fechaKey(
                ts is Timestamp ? ts.toDate() : DateTime.now(),
              );
      }

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
      await _map!.scaleBar.updateSettings(mb.ScaleBarSettings(enabled: false));
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

    final a =
        (Math.sin(dLat / 2) * Math.sin(dLat / 2)) +
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

    final moved = _haversineMeters(
      _aLat!,
      _aLng!,
      _lastRouteALat!,
      _lastRouteALng!,
    );
    return moved >= _routeUpdateMinMoveMeters;
  }

  bool get _enCamino =>
      (_pedidoEstado ?? '').trim().toLowerCase() == 'en camino';

  /// Cada recálculo de ruta durante el viaje: si lo que falta (km o min)
  /// subió respecto al recálculo anterior, el repartidor se desvió y esa
  /// diferencia se suma. Ej.: faltaban 4 min y ahora marca 5 → +1 min.
  Future<void> _procesarRecalculo(double restanteKm, double restanteMin) async {
    if (!_enCamino) return;

    // La ruta inicial no se pudo calcular al marcar "En camino": se toma
    // el primer cálculo que sí funcione.
    if (!_kmIniciado) {
      await _iniciarKilometraje(restanteKm, restanteMin);
      return;
    }

    final prevKm = _restantePrevKm;
    final prevMin = _restantePrevMin;
    _restantePrevKm = restanteKm;
    _restantePrevMin = restanteMin;
    // Primer recálculo tras abrir el mapa: solo sirve de referencia.
    if (prevKm == null || prevMin == null) return;

    final extraKm = restanteKm - prevKm;
    final extraMin = restanteMin - prevMin;
    final sumaKm = extraKm >= _umbralDesvioKm ? extraKm : 0.0;
    final sumaMin = extraMin >= _umbralDesvioMin ? extraMin : 0.0;
    if (sumaKm == 0 && sumaMin == 0) return;

    await _kmService.registrarDesvio(
      pedidoId: widget.pedidoId,
      repartidorUid: widget.repartidorUid,
      fecha: _kmFecha ?? KilometrajeService.fechaKey(DateTime.now()),
      extraKm: sumaKm,
      extraMin: sumaMin,
      repartidorNombre: _repartidorNombre,
      departamento: _departamento,
    );
  }

  /// Guarda la ruta inicial cuando no se pudo al marcar "En camino".
  Future<void> _iniciarKilometraje(double km, double min) async {
    if (_kmIniciando || _kmIniciado) return;
    _kmIniciando = true;
    try {
      final fecha = KilometrajeService.fechaKey(DateTime.now());
      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId)
          .update({
            'kilometraje': KilometrajeService.datosIniciales(
              km: km,
              min: min,
              fecha: fecha,
              repartidorUid: widget.repartidorUid,
              repartidorNombre: _repartidorNombre,
            ),
          });
      _kmIniciado = true;
      _kmFecha = fecha;
      _restantePrevKm = km;
      _restantePrevMin = min;
      await _kmService.sumarViajeAlDia(
        repartidorUid: widget.repartidorUid,
        fecha: fecha,
        km: km,
        min: min,
        repartidorNombre: _repartidorNombre,
        departamento: _departamento,
      );
    } catch (e) {
      debugPrint('No se pudo guardar el kilometraje inicial: $e');
    } finally {
      _kmIniciando = false;
    }
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

      if (distanceMeters != null && durationSeconds != null) {
        await _procesarRecalculo(_ultimaDistanciaKm!, _ultimaDuracionMin!);
      }

      final featureCollection = {
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": {},
            "geometry": {"type": "LineString", "coordinates": coords},
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

    // Sin cobrar no se puede entregar (el QR ya llega pagado: no aplica).
    final pagado = (_pedidoEstadoPago ?? '').trim().toLowerCase() == 'pagado';
    final esQr = (_tipoPago ?? '').contains('qr');
    if (nextLower == 'entregado' && !esQr && !pagado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primero toca "Pago" y márcalo como pagado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

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

      // Ruta inicial del viaje (si no se pudo calcular ahora, se toma en el
      // primer recálculo que funcione: ver _procesarRecalculo).
      final kmInicial = _ultimaDistanciaKm;
      final minInicial = _ultimaDuracionMin;
      final guardaKm =
          nextLower == 'en camino' &&
          !_kmIniciado &&
          kmInicial != null &&
          minInicial != null;
      final fechaKm = KilometrajeService.fechaKey(DateTime.now());

      if (guardaKm) {
        updateData['kilometraje'] = KilometrajeService.datosIniciales(
          km: kmInicial,
          min: minInicial,
          fecha: fechaKm,
          repartidorUid: widget.repartidorUid,
          repartidorNombre: _repartidorNombre,
        );
      }

      await FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId)
          .update(updateData);

      if (guardaKm) {
        _kmIniciado = true;
        _kmFecha = fechaKm;
        _restantePrevKm = kmInicial;
        _restantePrevMin = minInicial;
        // No bloquea: si falla solo queda en el log.
        unawaited(
          _kmService.sumarViajeAlDia(
            repartidorUid: widget.repartidorUid,
            fecha: fechaKm,
            km: kmInicial,
            min: minInicial,
            repartidorNombre: _repartidorNombre,
            departamento: _departamento,
          ),
        );
      }

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

  Future<void> _marcarComoPagado() async {
    if (_marcandoPagado) return;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConfirmarCobroSheet(
        monto: _pedidoMontoTotal,
        codigoPedido: _pedidoCodigo,
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _marcandoPagado = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final pedidoRef = FirebaseFirestore.instance
          .collection('pedidos')
          .doc(widget.pedidoId);
      batch.update(pedidoRef, {
        'estado_pago': 'pagado',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (_clienteUid != null && _clienteUid!.isNotEmpty) {
        final userPedidoRef = FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_clienteUid)
            .collection('pedidos')
            .doc(widget.pedidoId);
        batch.update(userPedidoRef, {
          'estado_pago': 'pagado',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      if (!mounted) return;
      setState(() => _pedidoEstadoPago = 'pagado');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pago marcado como recibido.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error actualizando pago: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _marcandoPagado = false);
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
          style: TextStyle(fontWeight: FontWeight.w900, color: Palette.ink),
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
                tipoPago: _tipoPago,
                montoTotal: _pedidoMontoTotal,
                changingEstado: _changingEstado,
                onToggleEstado: _toggleEstadoPedido,
                marcandoPagado: _marcandoPagado,
                onMarcarPagado: _marcarComoPagado,
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
  final String? tipoPago;
  final double? montoTotal;
  final bool changingEstado;
  final VoidCallback onToggleEstado;
  final bool marcandoPagado;
  final VoidCallback onMarcarPagado;
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
    required this.tipoPago,
    required this.montoTotal,
    required this.changingEstado,
    required this.onToggleEstado,
    required this.marcandoPagado,
    required this.onMarcarPagado,
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

    // El repartidor cobra todo lo que no sea QR (efectivo): toca "Pago" para
    // marcarlo como pagado y recién puede entregar. Los pedidos con QR ya
    // llegan pagados (los valida el admin) y el repartidor no toca su pago.
    final pagado = (widget.estadoPago ?? '').trim().toLowerCase() == 'pagado';
    final esQr = (widget.tipoPago ?? '').toLowerCase().contains('qr');
    final faltaCobrar = isEnCamino && !esQr && !pagado;

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
                      color:
                          (widget.error != null
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
                    // Tocar "Pago" (pendiente) lo marca como pagado.
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: (faltaCobrar && !widget.marcandoPagado)
                            ? widget.onMarcarPagado
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: faltaCobrar
                                ? Colors.orange.withValues(alpha: 0.08)
                                : Palette.fieldBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: faltaCobrar
                                  ? Colors.orange.withValues(alpha: 0.55)
                                  : Palette.primary.withOpacity(0.07),
                              width: faltaCobrar ? 1.4 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              widget.marcandoPagado
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
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
                              if (faltaCobrar)
                                const Icon(
                                  Icons.touch_app_rounded,
                                  size: 20,
                                  color: Colors.orange,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (hasMoreItems || firstItem != null) ...[
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
                        productId: (item['productId'] ?? '').toString(),
                        imageUrl: _itemImage(item),
                        qty: _itemQty(item),
                        price: _itemPrice(item),
                      ),
                    );
                  }).toList(),
                ),
              ],
              // ── Aviso: cobrar antes de entregar ──
              if (faltaCobrar) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Toca "Pago" para marcarlo como pagado y poder entregar.',
                        style: TextStyle(
                          color: Palette.ink.withOpacity(0.75),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  // En efectivo, no se puede entregar sin cobrar.
                  onPressed:
                      (widget.changingEstado || isEntregado || faltaCobrar)
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

/// Hoja para confirmar que el repartidor recibió el pago en efectivo.
class _ConfirmarCobroSheet extends StatelessWidget {
  const _ConfirmarCobroSheet({required this.monto, this.codigoPedido});

  final double? monto;
  final String? codigoPedido;

  @override
  Widget build(BuildContext context) {
    final montoTxt = monto != null ? 'Bs ${monto!.toStringAsFixed(2)}' : '—';
    final codigo = (codigoPedido ?? '').trim();

    return Container(
      decoration: const BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: Palette.ink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),

              // Ícono
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Palette.statsSuccess.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Palette.statsSuccess.withValues(alpha: 0.35),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 34,
                  color: Palette.statsSuccess,
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Confirmar cobro',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                codigo.isEmpty
                    ? 'Pago en efectivo'
                    : 'Pedido #$codigo · Pago en efectivo',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Palette.ink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 18),

              // Monto destacado
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Palette.statsSuccess.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Palette.statsSuccess.withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'Monto a cobrar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        montoTxt,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Palette.ink,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Nota
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Palette.ink.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirma solo si ya recibiste el dinero del cliente. '
                      'Después podrás marcar el pedido como entregado.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        color: Palette.ink.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Botones
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Palette.ink,
                          side: BorderSide(
                            color: Palette.ink.withValues(alpha: 0.18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Todavía no',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          'Sí, lo recibí',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.statsSuccess,
                          foregroundColor: Palette.ink,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
  final String productId;
  final String imageUrl;
  final int qty;
  final double price;

  const _PedidoMiniItemCard({
    required this.name,
    this.productId = '',
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
        border: Border.all(color: Palette.primary.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          // Si la foto guardada ya no existe, usa la actual del producto.
          ProductoImagen(
            productId: productId,
            imageUrl: imageUrl,
            radius: 12,
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
