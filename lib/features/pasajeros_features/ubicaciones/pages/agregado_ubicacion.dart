// lib/features/perfil/agregado_ubicacion.dart
//
// ✅ flutter_map ^8.2.2 + OSM tiles
// ✅ Inicia en ubicación actual (Geolocator)
// ✅ Pin fijo al centro
// ✅ Reverse geocoding con debounce 1.5s (Mapbox REST)
// ✅ Buscador avanzado tipo Google Maps:
//    - Mapbox Search Box API (suggest + retrieve) con session_token
//    - fallback a Geocoding clásico si SearchBox no está disponible
// ✅ UI muestra SOLO dirección (sin "Departamento...")
// ✅ Departamento interno (SIN "Departamento de ...", guardado como "Cochabamba", "La paz", etc.)
// ✅ Panel inferior pegado abajo; SOLO sube al enfocar "Nombre"
// ✅ Botón deshabilitado hasta terminar de cargar
// ✅ AppBar rosa profesional (Palette.button)
// ✅ GUARDA EN FIRESTORE (Base de datos) al presionar "Guardar mi Ubicación"
//
// Requiere:
// cloud_firestore: ^5.x
// firebase_auth: ^5.x

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'package:quimisol_movil/core/theme/palette.dart';

class AgregadoUbicacionPage extends StatefulWidget {
  const AgregadoUbicacionPage({super.key});

  @override
  State<AgregadoUbicacionPage> createState() => _AgregadoUbicacionPageState();
}

class _AgregadoUbicacionPageState extends State<AgregadoUbicacionPage> {
  static const String _kMapboxToken =
      'pk.eyJ1Ijoic2ViYXMxMjciLCJhIjoiY21mMGhhdDRiMG5mbTJscHlnMGUweGlicSJ9.SVeyu-4RTAybmgRxhPxSWw';
  String get _mapboxToken => _kMapboxToken;

  final MapController _mapCtrl = MapController();

  LatLng? _center;
  Timer? _debounce;

  bool _loadingLocation = true;
  bool _loadingGeocode = false;
  bool _waitingDebounce = false;
  bool _saving = false;

  String? _error;

  String _address = 'Mové el mapa para obtener la dirección...';
  String _department = '';

  final _nameCtrl = TextEditingController(text: 'Casa');
  final FocusNode _nameFocus = FocusNode();

  // 🔎 Buscador avanzado
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;

  bool _searching = false;
  List<_SuggestHit> _hits = [];

  // session token (importante para Search Box API)
  String _sessionToken = _newSessionToken();

  // filtros “tipo Maps” (opcional)
  static const String _countryFilter = 'BO';
  static const String _types =
      'poi,address,place,locality,neighborhood,street,region';

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _ubicacionesRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw Exception('Usuario no autenticado');
    }
    return _db.collection('usuarios').doc(uid).collection('ubicaciones');
  }

  bool get _isNameFocused => _nameFocus.hasFocus;

  bool get _canUseLocation {
    final n = _nameCtrl.text.trim();
    return _center != null &&
        !_loadingGeocode &&
        !_waitingDebounce &&
        !_loadingLocation &&
        !_saving &&
        _error == null &&
        n.isNotEmpty &&
        _address.trim().isNotEmpty &&
        _address != 'Mové el mapa para obtener la dirección...';
  }

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();

    _searchCtrl.addListener(_onSearchChanged);

    // ✅ para que el botón se habilite/deshabilite al escribir el nombre
    _nameCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    _searchFocus.addListener(() {
      if (_searchFocus.hasFocus) {
        _nameFocus.unfocus();
        _sessionToken = _newSessionToken();
      }
    });

    _nameFocus.addListener(() {
      if (mounted) setState(() {});
      if (_nameFocus.hasFocus) {
        setState(() => _hits = []);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchDebounce?.cancel();

    _nameCtrl.dispose();
    _nameFocus.dispose();

    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    _searchFocus.dispose();

    super.dispose();
  }

  // ---------------------------
  // Ubicación inicial + reverse
  // ---------------------------
  Future<void> _initCurrentLocation() async {
    setState(() {
      _loadingLocation = true;
      _error = null;
    });

    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() {
          _error = 'Activa el GPS / ubicación del dispositivo.';
          _loadingLocation = false;
        });
        return;
      }

      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }

      if (perm == geo.LocationPermission.denied) {
        setState(() {
          _error = 'Permiso de ubicación denegado.';
          _loadingLocation = false;
        });
        return;
      }

      if (perm == geo.LocationPermission.deniedForever) {
        setState(() {
          _error =
              'Permiso de ubicación bloqueado. Habilítalo desde Ajustes del sistema.';
          _loadingLocation = false;
        });
        return;
      }

      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );

      final start = LatLng(pos.latitude, pos.longitude);
      _center = start;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapCtrl.move(start, 15.5);
      });

      setState(() => _waitingDebounce = true);
      await _reverseGeocode(start);

      setState(() => _loadingLocation = false);
    } catch (e) {
      setState(() {
        _error = 'No se pudo obtener la ubicación: $e';
        _loadingLocation = false;
      });
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (!hasGesture) return;

    final c = camera.center;
    _center = c;

    setState(() => _waitingDebounce = true);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;
      await _reverseGeocode(c);
    });
  }

  String _stripDepartmentFromPlaceName(String placeName) {
    final tokens = placeName.split(',').map((e) => e.trim()).toList();
    final filtered = tokens.where((p) {
      final low = p.toLowerCase();
      return !(low.startsWith('departamento') ||
          low.contains('departamento de') ||
          low.startsWith('region') ||
          low.contains('región'));
    }).toList();
    return filtered.join(', ');
  }

  // ✅ Normaliza departamento sin "Departamento de ..." y en minúsculas
  String _normalizeDepartment(String dep) {
    var d = dep.trim();
    if (d.isEmpty) return '';

    final low = d.toLowerCase();

    if (low.startsWith('departamento de ')) {
      d = d.substring('departamento de '.length).trim();
    } else if (low.startsWith('departamento ')) {
      d = d.substring('departamento '.length).trim();
    } else if (low.startsWith('depto. ')) {
      d = d.substring('depto. '.length).trim();
    } else if (low.startsWith('depto ')) {
      d = d.substring('depto '.length).trim();
    } else if (low.startsWith('región de ')) {
      d = d.substring('región de '.length).trim();
    } else if (low.startsWith('region de ')) {
      d = d.substring('region de '.length).trim();
    } else if (low.startsWith('región ')) {
      d = d.substring('región '.length).trim();
    } else if (low.startsWith('region ')) {
      d = d.substring('region '.length).trim();
    }

    d = d.replaceAll(RegExp(r'\s+'), ' ').trim();
    return d.toLowerCase();
  }

  // ✅ Capitaliza SOLO la primera letra: "cochabamba" -> "Cochabamba"
  String _capitalizeFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<void> _reverseGeocode(LatLng c) async {
    if (_mapboxToken.isEmpty) {
      setState(() {
        _address = 'Falta token Mapbox.';
        _department = '';
        _waitingDebounce = false;
      });
      return;
    }

    setState(() => _loadingGeocode = true);

    try {
      final lng = c.longitude;
      final lat = c.latitude;

      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json'
        '?access_token=$_mapboxToken&language=es&limit=1',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        setState(() {
          _address = 'No se pudo obtener dirección (HTTP ${res.statusCode}).';
          _department = '';
        });
        return;
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? [];
      if (features.isEmpty) {
        setState(() {
          _address = 'No se encontró una dirección para este punto.';
          _department = '';
        });
        return;
      }

      final f0 = features.first as Map<String, dynamic>;
      final context = (f0['context'] as List?) ?? [];

      // departamento interno (region.*)
      String dep = '';
      for (final c in context) {
        final item = c as Map<String, dynamic>;
        final id = (item['id'] as String?) ?? '';
        if (id.startsWith('region.')) {
          dep = (item['text'] as String?)?.trim() ?? '';
          break;
        }
      }

      // ✅ normalizar (minúsculas, sin prefijos)
      final depNorm = _normalizeDepartment(dep);

      // dirección limpia
      final street = (f0['text'] as String?)?.trim() ?? '';
      final number = (f0['address'] as String?)?.trim();
      String streetLine = street;
      if (streetLine.isNotEmpty && number != null && number.isNotEmpty) {
        streetLine = '$streetLine $number';
      }

      String city = '';
      String country = '';
      for (final c in context) {
        final item = c as Map<String, dynamic>;
        final id = (item['id'] as String?) ?? '';
        final text = (item['text'] as String?)?.trim() ?? '';
        if (city.isEmpty && id.startsWith('place.')) city = text;
        if (country.isEmpty && id.startsWith('country.')) country = text;
      }

      final fallbackPlaceName = (f0['place_name'] as String?)?.trim() ?? '';
      final parts = <String>[];

      if (streetLine.isNotEmpty) {
        parts.add(streetLine);
      } else if (fallbackPlaceName.isNotEmpty) {
        parts.add(_stripDepartmentFromPlaceName(fallbackPlaceName));
      }

      if (city.isNotEmpty) parts.add(city);
      if (country.isNotEmpty) parts.add(country);

      final niceAddress = parts.where((e) => e.trim().isNotEmpty).join(', ');

      setState(() {
        _address =
            niceAddress.isNotEmpty ? niceAddress : 'Dirección no disponible';
        _department = depNorm; // ✅ guardado interno normalizado (minúsculas)
      });
    } catch (e) {
      setState(() {
        _address = 'Error al obtener dirección: $e';
        _department = '';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingGeocode = false;
          _waitingDebounce = false;
        });
      }
    }
  }

  // ---------------------------
  // 🔎 BUSCADOR AVANZADO (Maps-like)
  // ---------------------------
  void _onSearchChanged() {
    final q = _searchCtrl.text.trim();
    _searchDebounce?.cancel();

    if (q.isEmpty) {
      setState(() {
        _hits = [];
        _searching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 220), () async {
      await _searchSuggest(q);
    });
  }

  String _proximityParam() {
    final c = _center;
    if (c == null) return '';
    return '&proximity=${c.longitude},${c.latitude}';
  }

  Future<void> _searchSuggest(String query) async {
    if (_mapboxToken.isEmpty) return;

    setState(() => _searching = true);

    final ok = await _trySearchBoxSuggest(query);
    if (!ok) {
      await _fallbackGeocodingSuggest(query);
    }

    if (mounted) setState(() => _searching = false);
  }

  Future<bool> _trySearchBoxSuggest(String query) async {
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/search/searchbox/v1/suggest'
        '?q=${Uri.encodeComponent(query)}'
        '&access_token=$_mapboxToken'
        '&session_token=$_sessionToken'
        '&language=es'
        '&limit=7'
        '&country=$_countryFilter'
        '&types=$_types'
        '${_proximityParam()}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return false;

      final data = json.decode(res.body) as Map<String, dynamic>;
      final suggestions = (data['suggestions'] as List?) ?? [];

      final parsed = <_SuggestHit>[];
      for (final s in suggestions) {
        final m = s as Map<String, dynamic>;
        final mapboxId = (m['mapbox_id'] as String?)?.trim() ?? '';
        if (mapboxId.isEmpty) continue;

        final name = (m['name'] as String?)?.trim() ?? '';
        final fullAddress = (m['full_address'] as String?)?.trim() ?? '';
        final placeFormatted = (m['place_formatted'] as String?)?.trim() ?? '';
        final type = (m['feature_type'] as String?)?.trim() ?? '';

        final title = name.isNotEmpty ? name : placeFormatted;
        final subtitle = _stripDepartmentFromPlaceName(
          fullAddress.isNotEmpty ? fullAddress : placeFormatted,
        );

        parsed.add(
          _SuggestHit(
            title: title.isNotEmpty ? title : 'Resultado',
            subtitle: subtitle,
            mapboxId: mapboxId,
            sourceType: type,
            point: null,
          ),
        );
      }

      if (!mounted) return true;
      setState(() => _hits = parsed);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fallbackGeocodingSuggest(String query) async {
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/geocoding/v5/mapbox.places/${Uri.encodeComponent(query)}.json'
        '?access_token=$_mapboxToken'
        '&language=es'
        '&limit=7'
        '&autocomplete=true'
        '&country=$_countryFilter'
        '&types=$_types'
        '${_proximityParam()}',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) {
        if (!mounted) return;
        setState(() => _hits = []);
        return;
      }

      final data = json.decode(res.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? [];

      final parsed = <_SuggestHit>[];
      for (final f in features) {
        final m = f as Map<String, dynamic>;
        final name = (m['text'] as String?)?.trim() ?? '';
        final placeName = (m['place_name'] as String?)?.trim() ?? '';
        final center = (m['center'] as List?) ?? [];
        if (center.length < 2) continue;

        final lng = (center[0] as num).toDouble();
        final lat = (center[1] as num).toDouble();

        final subtitle = _stripDepartmentFromPlaceName(placeName);

        parsed.add(
          _SuggestHit(
            title: name.isNotEmpty ? name : subtitle,
            subtitle: subtitle,
            mapboxId: null,
            sourceType: (m['place_type'] is List &&
                    (m['place_type'] as List).isNotEmpty)
                ? ((m['place_type'] as List).first as String?) ?? ''
                : '',
            point: LatLng(lat, lng),
          ),
        );
      }

      if (!mounted) return;
      setState(() => _hits = parsed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hits = []);
    }
  }

  Future<void> _selectHit(_SuggestHit hit) async {
    _searchFocus.unfocus();
    setState(() => _hits = []);

    LatLng? p = hit.point;
    if (p == null && hit.mapboxId != null) {
      p = await _searchBoxRetrieve(hit.mapboxId!);
    }

    if (p == null) return;

    _center = p;
    _mapCtrl.move(p, 16.5);

    setState(() {
      _searchCtrl.text = hit.subtitle.isNotEmpty ? hit.subtitle : hit.title;
    });

    setState(() => _waitingDebounce = true);
    _debounce?.cancel();
    await _reverseGeocode(p);
  }

  Future<LatLng?> _searchBoxRetrieve(String mapboxId) async {
    try {
      final uri = Uri.parse(
        'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
        '?access_token=$_mapboxToken'
        '&session_token=$_sessionToken',
      );

      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final data = json.decode(res.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? [];
      if (features.isEmpty) return null;

      final f0 = features.first as Map<String, dynamic>;
      final geometry = f0['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'] as List?;
      if (coords == null || coords.length < 2) return null;

      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() {
      _hits = [];
      _searching = false;
    });
  }

  // ---------------------------
  // ✅ GUARDAR EN BASE DE DATOS (Firestore)
  // ---------------------------
  Future<void> _saveThisLocation() async {
    if (!_canUseLocation) return;

    final c = _center!;
    final nombre =
        _nameCtrl.text.trim().isEmpty ? 'Ubicación' : _nameCtrl.text.trim();

    setState(() => _saving = true);

    try {
      final uid = _auth.currentUser?.uid;

      // ✅ normaliza a minúsculas + quita "departamento de ..."
      final depRaw = _normalizeDepartment(_department); // "cochabamba"
      // ✅ muestra/guarda con inicial mayúscula
      final depFinal = _capitalizeFirst(depRaw); // "Cochabamba"

      final payload = <String, dynamic>{
        'nombre': nombre,
        'direccion': _address,
        'departamento': depFinal, // ✅ "Cochabamba", "La paz", etc.
        'lat': c.latitude,
        'lng': c.longitude,
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final doc = await _ubicacionesRef.add(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación guardada ✅')),
      );

      Navigator.pop(
        context,
        UbicDraft(
          id: doc.id,
          nombre: nombre,
          direccion: _address,
          departamento: depFinal,
          lat: c.latitude,
          lng: c.longitude,
          uid: uid,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo guardar la ubicación.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kb = MediaQuery.of(context).viewInsets.bottom;
    final panelBottom = _isNameFocused ? kb : 0.0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Palette.fieldBg,
      appBar: _ProAppBar(
        title: 'Seleccionar ubicación',
        onBack: () => Navigator.pop(context),
        onMyLocation: _initCurrentLocation,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap()),
          Positioned(
            left: 14,
            right: 14,
            top: 12,
            child: _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              searching: _searching,
              onClear: _clearSearch,
            ),
          ),
          if (_hits.isNotEmpty)
            Positioned(
              left: 14,
              right: 14,
              top: 66,
              child: _SearchResults(hits: _hits, onTap: _selectHit),
            ),
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_pin, size: 46, color: Palette.button),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Palette.button.withOpacity(0.18),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: panelBottom,
            child: _BottomPanel(
              nameCtrl: _nameCtrl,
              nameFocus: _nameFocus,
              address: _address,
              isBusy: _waitingDebounce || _loadingGeocode,
              canUse: _canUseLocation,
              saving: _saving,
              onUse: _saveThisLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_loadingLocation) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black.withOpacity(0.75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Palette.button,
                  foregroundColor: Colors.white,
                ),
                onPressed: _initCurrentLocation,
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final start = _center ?? const LatLng(-16.4897, -68.1193);

    return FlutterMap(
      mapController: _mapCtrl,
      options: MapOptions(
        initialCenter: start,
        initialZoom: 15.5,
        onPositionChanged: _onPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.quimisol.quimisol_movil',
        ),
      ],
    );
  }
}

// ------------------ UI widgets ------------------

class _ProAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onMyLocation;

  const _ProAppBar({
    required this.title,
    required this.onBack,
    required this.onMyLocation,
  });

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_rounded, color: Palette.button),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Palette.button,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mi ubicación',
                onPressed: onMyLocation,
                icon: Icon(Icons.my_location_rounded, color: Palette.button),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool searching;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.searching,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Palette.button.withOpacity(0.20)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: Palette.button),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  hintText: 'Buscar lugar, calle, zona...',
                  border: InputBorder.none,
                ),
              ),
            ),
            if (searching)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (controller.text.trim().isNotEmpty)
              IconButton(
                onPressed: onClear,
                icon: Icon(
                  Icons.close_rounded,
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<_SuggestHit> hits;
  final Future<void> Function(_SuggestHit) onTap;

  const _SearchResults({required this.hits, required this.onTap});

  IconData _iconForType(String t) {
    final low = t.toLowerCase();
    if (low.contains('poi')) return Icons.store_mall_directory_rounded;
    if (low.contains('address')) return Icons.home_rounded;
    if (low.contains('street')) return Icons.signpost_rounded;
    if (low.contains('place') || low.contains('locality')) {
      return Icons.location_city_rounded;
    }
    if (low.contains('region')) return Icons.map_rounded;
    return Icons.place_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: hits.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: Colors.black.withOpacity(0.06)),
          itemBuilder: (context, i) {
            final h = hits[i];
            return ListTile(
              onTap: () => onTap(h),
              leading: Icon(_iconForType(h.sourceType), color: Palette.button),
              title: Text(
                h.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: h.subtitle.isEmpty
                  ? null
                  : Text(
                      h.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
            );
          },
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  final TextEditingController nameCtrl;
  final FocusNode nameFocus;
  final String address;
  final bool isBusy;
  final bool canUse;
  final bool saving;
  final VoidCallback onUse;

  const _BottomPanel({
    required this.nameCtrl,
    required this.nameFocus,
    required this.address,
    required this.isBusy,
    required this.canUse,
    required this.saving,
    required this.onUse,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          border: Border.all(color: Palette.button.withOpacity(0.20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Palette.button.withOpacity(0.35),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            TextField(
              controller: nameCtrl,
              focusNode: nameFocus,
              decoration: InputDecoration(
                labelText: 'Nombre',
                labelStyle: TextStyle(
                  color: Palette.button,
                  fontWeight: FontWeight.w700,
                ),
                filled: true,
                fillColor: Palette.fieldBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_rounded, color: Palette.button),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: isBusy
                        ? Row(
                            key: const ValueKey('busy'),
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Actualizando dirección...',
                                  style: TextStyle(
                                    color: Colors.black.withOpacity(0.75),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Text(
                            key: const ValueKey('address'),
                            address,
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: canUse
                      ? Palette.button
                      : Palette.button.withOpacity(0.45),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: canUse ? onUse : null,
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Guardar mi Ubicación',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------ Model ------------------

class _SuggestHit {
  final String title;
  final String subtitle;
  final String sourceType;

  // SearchBox:
  final String? mapboxId;

  // Fallback geocoding:
  final LatLng? point;

  _SuggestHit({
    required this.title,
    required this.subtitle,
    required this.sourceType,
    required this.mapboxId,
    required this.point,
  });
}

class UbicDraft {
  final String id;
  final String nombre;
  final String direccion;
  final String departamento;
  final double lat;
  final double lng;
  final String? uid;

  UbicDraft({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.departamento,
    required this.lat,
    required this.lng,
    required this.uid,
  });

  double get latitud => lat;
  double get longitud => lng;

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'direccion': direccion,
        'departamento': departamento,
        'lat': lat,
        'lng': lng,
        'uid': uid,
      };
}

// ------------------ Utils ------------------

String _newSessionToken() {
  final r = Random();
  final a = List<int>.generate(16, (_) => r.nextInt(256));
  return a.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
