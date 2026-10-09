// lib/features/home/home_cliente.dart
//
// ✅ HomePage (HomeCliente) COMPLETA + FILTRO POR DEPARTAMENTO
// ✅ Categorías desde Firestore (collection: categorias)
// ✅ Wishlist (Like) con animación SUAVE (sin flash) + sincronizado con WishlistPage
// ✅ Mostrar DESCUENTO en card (precio final + precio tachado + badge + texto)
// ✅ La imagen NO se achica por el descuento (AspectRatio fijo)
// ✅ Banners desde Firestore (collection: banners) SOLO estado ACTIVO
// ✅ FIX: ya NO parpadea al tocar categorías (streams cacheados)
// ✅ NUEVO: Banner "Ver más" abre DetalleProductoPage del producto del banner
// ✅ NUEVO: Arranca en depto detectado por ubicación (con match inteligente)
// ✅ NUEVO: Card muestra promedio real + total de reseñas
// ✅ NUEVO: Buscador funcional por nombre, descripción, categoría, departamento, stock y precio

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:geocoding/geocoding.dart' as geo;
import 'package:geolocator/geolocator.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/conductores_features/notificaciones/pages/notificaciones_page.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';
import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist_store.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/shared/stores/guest_store.dart';
import 'package:quimisol_movil/shared/widgets/cart_count_badge.dart';
import 'package:quimisol_movil/shared/widgets/guest_lock_view.dart';
import 'package:quimisol_movil/shared/widgets/pill_pagination_bar.dart';
import 'package:quimisol_movil/shared/widgets/zoomable_image.dart';

import 'detalle_producto.dart';

class HomeCliente extends StatefulWidget {
  const HomeCliente({super.key});

  @override
  State<HomeCliente> createState() => _HomeClienteState();
}

class _HomeClienteState extends State<HomeCliente> {
  late final AuthService _authService;

  bool get _isGuest {
    try {
      return Modular.get<GuestStore>().value;
    } catch (_) {
      return false;
    }
  }

  String _selectedDepto = '';
  String _detectedDepto = '';
  bool _autoDeptoApplied = false;

  String _selectedCategoriaId = 'Todos';

  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // 🔃 Orden / filtro de la lista de productos
  _ProductSort _sort = _ProductSort.populares;

  // Descuento activo de cada producto (productos/{id}/descuentos/activo).
  // Se necesita a nivel de lista para filtrar "con descuento" y ordenar por
  // el precio final que ve el cliente.
  final Map<String, Map<String, dynamic>> _descuentos = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _descuentoSubs = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productosIdsSub;

  // 📄 Paginación
  static const int _pageSize = 8;
  int _currentPage = 0;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _almacenes$;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productos$;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categorias$;

  final WishlistStore _wishlist = WishlistStore.I;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
    _wishlist.bind();
    // Escucha el carrito desde el inicio para la burbuja del ícono.
    CartStore.I.init();

    _almacenes$ = FirebaseFirestore.instance
        .collection('almacenes')
        .snapshots();
    _productos$ = FirebaseFirestore.instance
        .collection('productos')
        .snapshots();
    _categorias$ = FirebaseFirestore.instance
        .collection('categorias')
        .orderBy('nombre')
        .snapshots();

    _productosIdsSub = FirebaseFirestore.instance
        .collection('productos')
        .snapshots()
        .listen((qs) => _syncDescuentos(qs.docs.map((d) => d.id).toSet()));

    _searchCtrl.addListener(() {
      final value = _searchCtrl.text.trim();
      if (value == _searchQuery) return;
      setState(() {
        _searchQuery = value;
        _currentPage = 0;
      });
    });

    _initUserDeptoFromLocation();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _productosIdsSub?.cancel();
    for (final sub in _descuentoSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  /* ---------------- Orden / filtro ---------------- */

  /// Escucha el descuento de cada producto existente y suelta los que ya no
  /// están.
  void _syncDescuentos(Set<String> ids) {
    for (final id in _descuentoSubs.keys.toList()) {
      if (ids.contains(id)) continue;
      _descuentoSubs.remove(id)?.cancel();
      _descuentos.remove(id);
    }

    for (final id in ids) {
      if (_descuentoSubs.containsKey(id)) continue;
      _descuentoSubs[id] = FirebaseFirestore.instance
          .collection('productos')
          .doc(id)
          .collection('descuentos')
          .doc('activo')
          .snapshots()
          .listen((snap) {
            if (!mounted) return;
            setState(() {
              final data = snap.data();
              if (data == null) {
                _descuentos.remove(id);
              } else {
                _descuentos[id] = data;
              }
            });
          }, onError: (_) {});
    }
  }

  bool _tieneDescuento(ProductModel p) {
    final d = _descuentos[p.id];
    return d != null && d['activo'] == true && _toDouble(d['valor']) > 0;
  }

  /// Precio que ve el cliente (mismo cálculo que la card).
  double _precioFinal(ProductModel p) {
    if (!_tieneDescuento(p)) return p.price;
    final d = _descuentos[p.id]!;
    final tipo = _s(d['tipo']).isEmpty ? 'PORCENTAJE' : _s(d['tipo']);
    final valor = _toDouble(d['valor']);
    if (tipo == 'PORCENTAJE') {
      return math.max(0, p.price * (1 - valor.clamp(0.0, 100.0) / 100));
    }
    return math.max(0, p.price - valor);
  }

  /// Fracción ahorrada (0..1) para ordenar "Con descuento".
  double _ahorro(ProductModel p) {
    if (p.price <= 0) return 0;
    return (p.price - _precioFinal(p)) / p.price;
  }

  List<ProductModel> _aplicarOrden(List<ProductModel> items) {
    int porNombre(ProductModel a, ProductModel b) =>
        _normalizeText(a.name).compareTo(_normalizeText(b.name));

    switch (_sort) {
      case _ProductSort.populares:
        return items;
      case _ProductSort.nuevos:
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        return [...items]..sort(
          (a, b) => (b.createdAt ?? epoch).compareTo(a.createdAt ?? epoch),
        );
      case _ProductSort.descuento:
        return items.where(_tieneDescuento).toList()
          ..sort((a, b) => _ahorro(b).compareTo(_ahorro(a)));
      case _ProductSort.precioAsc:
        return [...items]
          ..sort((a, b) => _precioFinal(a).compareTo(_precioFinal(b)));
      case _ProductSort.precioDesc:
        return [...items]
          ..sort((a, b) => _precioFinal(b).compareTo(_precioFinal(a)));
      case _ProductSort.az:
        return [...items]..sort(porNombre);
      case _ProductSort.za:
        return [...items]..sort((a, b) => porNombre(b, a));
    }
  }

  Future<void> _abrirOrden() async {
    final chosen = await showModalBottomSheet<_ProductSort>(
      context: context,
      backgroundColor: Palette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _SortPickerSheet(selected: _sort),
    );

    if (chosen == null || chosen == _sort) return;
    setState(() {
      _sort = chosen;
      _currentPage = 0;
    });
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  Future<void> _initUserDeptoFromLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _detectedDepto = '';
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _detectedDepto = '';
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final placemarks = await geo.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) {
        _detectedDepto = '';
        return;
      }

      final p = placemarks.first;

      final raw = (p.administrativeArea?.trim().isNotEmpty ?? false)
          ? p.administrativeArea!.trim()
          : (p.subAdministrativeArea?.trim().isNotEmpty ?? false)
          ? p.subAdministrativeArea!.trim()
          : (p.locality?.trim().isNotEmpty ?? false)
          ? p.locality!.trim()
          : '';

      _detectedDepto = raw;

      if (!mounted) return;
      setState(() {});
    } catch (_) {
      _detectedDepto = '';
    }
  }

  String _normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  String _findBestDeptoMatch({
    required String detected,
    required List<String> deptosDisponibles,
  }) {
    if (detected.trim().isEmpty) return '';

    final d = _normalizeText(detected);

    for (final dep in deptosDisponibles) {
      if (_normalizeText(dep) == d) return dep;
    }

    for (final dep in deptosDisponibles) {
      final x = _normalizeText(dep);
      if (d.contains(x) || x.contains(d)) return dep;
    }

    final aliases = <String, List<String>>{
      'La Paz': ['la paz', 'lp', 'l.p.', 'el alto'],
      'Cochabamba': [
        'cochabamba',
        'cbba',
        'cbb',
        'cocha',
        'quillacollo',
        'sacaba',
      ],
      'Santa Cruz': [
        'santa cruz',
        'scz',
        'santa cruz de la sierra',
        'Santa Cruz de la Sierra',
      ],
      'Oruro': ['oruro', 'oru'],
      'Potosí': ['potosi', 'pts'],
      'Chuquisaca': ['chuquisaca', 'sucre', 'chq'],
      'Tarija': ['tarija', 'tja'],
      'Beni': ['beni', 'trinidad'],
      'Pando': ['pando', 'cobija'],
    };

    for (final entry in aliases.entries) {
      final canonical = entry.key;
      final keys = entry.value.map(_normalizeText).toList();

      if (keys.any((k) => d.contains(k))) {
        for (final dep in deptosDisponibles) {
          final depNorm = _normalizeText(dep);

          if (depNorm == _normalizeText(canonical)) return dep;
          if (keys.any((k) => depNorm.contains(k) || k.contains(depNorm))) {
            return dep;
          }
        }
      }
    }

    return '';
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Palette.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Palette.card,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout_rounded,
                  color: Palette.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cerrar sesión',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '¿Estás seguro que deseas salir de tu cuenta?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Palette.ink.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Palette.primary,
                        side: BorderSide(
                          color: Palette.primary.withOpacity(0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Palette.button,
                        foregroundColor: Palette.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Salir',
                        style: TextStyle(fontWeight: FontWeight.w900),
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

    if (ok != true) return;

    await _authService.logout();
    Modular.to.navigate('/auth/login');
  }

  Widget _productTile(ProductModel prod) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetalleProductoPage(product: prod)),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: _ProductCard(product: prod, wishlist: _wishlist),
    );
  }

  void _openDeptoPicker(List<String> deptos) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Palette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) =>
          _DeptoPickerSheet(deptos: deptos, selected: _selectedDepto),
    );

    if (chosen == null) return;
    setState(() {
      _selectedDepto = chosen;
      _currentPage = 0;
    });
  }

  void _openNotificaciones() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificacionesPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _almacenes$,
        builder: (context, almacenesSnap) {
          if (almacenesSnap.hasError) {
            return Center(
              child: Text(
                'Error cargando almacenes: ${almacenesSnap.error}',
                style: const TextStyle(color: Palette.ink),
              ),
            );
          }

          if (almacenesSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final almacenesDocs = almacenesSnap.data?.docs ?? [];

          final Map<String, String> almacenDeptoById = {};
          final Set<String> deptosSet = {'Todos'};

          for (final d in almacenesDocs) {
            final data = d.data();
            final dep = _s(data['departamento']);
            if (dep.isNotEmpty) deptosSet.add(dep);
            almacenDeptoById[d.id] = dep;
          }

          final deptos = deptosSet.toList()
            ..sort((a, b) {
              if (a == 'Todos') return -1;
              if (b == 'Todos') return 1;
              return a.compareTo(b);
            });

          final deptosDisponibles = deptos.where((d) => d != 'Todos').toList();

          if (!_autoDeptoApplied) {
            final best = _findBestDeptoMatch(
              detected: _detectedDepto,
              deptosDisponibles: deptosDisponibles,
            );

            if (best.isNotEmpty) {
              _selectedDepto = best;
            } else {
              _selectedDepto = deptosDisponibles.isNotEmpty
                  ? deptosDisponibles.first
                  : 'Todos';
            }

            _autoDeptoApplied = true;
          } else {
            if (_selectedDepto.isEmpty || !deptos.contains(_selectedDepto)) {
              _selectedDepto = deptosDisponibles.isNotEmpty
                  ? deptosDisponibles.first
                  : 'Todos';
            }
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _PinkPedidosHeader(
                  deptos: deptos,
                  selectedDepto: _selectedDepto,
                  almacenDeptoById: almacenDeptoById,
                  onPickDepto: () => _openDeptoPicker(deptos),
                  onLogout: _logout,
                  isGuest: _isGuest,
                  onBell: () {
                    if (_isGuest) {
                      showGuestLockSheet(
                        context,
                        icon: Icons.notifications_none_rounded,
                        title: 'Tus notificaciones',
                        message:
                            'Inicia sesión para ver tus notificaciones de pedidos y promociones.',
                      );
                      return;
                    }
                    _openNotificaciones();
                  },
                  onCart: () {
                    if (_isGuest) {
                      showGuestLockSheet(
                        context,
                        icon: Icons.shopping_cart_outlined,
                        title: 'Tu carrito está vacío',
                        message:
                            'Inicia sesión para agregar productos al carrito y realizar tus compras.',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CarritoPage()),
                    );
                  },
                  searchCtrl: _searchCtrl,
                  onSearchChanged: (_) {},
                  onClearSearch: () {
                    _searchCtrl.clear();
                    FocusScope.of(context).unfocus();
                  },
                  onSearch: () {
                    FocusScope.of(context).unfocus();
                  },
                ),
                SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      18,
                      18,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _sort.titulo,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.ink,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            _SortButton(
                              active: _sort != _ProductSort.populares,
                              onTap: _abrirOrden,
                            ),
                          ],
                        ),
                        if (_sort != _ProductSort.populares) ...[
                          const SizedBox(height: 8),
                          _ActiveSortChip(
                            sort: _sort,
                            onClear: () => setState(() {
                              _sort = _ProductSort.populares;
                              _currentPage = 0;
                            }),
                          ),
                        ],
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _categorias$,
                          builder: (context, catSnap) {
                            if (catSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(height: 42);
                            }

                            final docs = catSnap.data?.docs ?? [];

                            final categorias = <CategoryModel>[
                              const CategoryModel(id: 'Todos', nombre: 'Todos'),
                              ...docs.map((d) {
                                final data = d.data();
                                final nombre = _s(data['nombre']);
                                return CategoryModel(
                                  id: d.id,
                                  nombre: nombre.isEmpty ? 'Categoría' : nombre,
                                );
                              }),
                            ];

                            final exists = categorias.any(
                              (c) => c.id == _selectedCategoriaId,
                            );
                            if (!exists) _selectedCategoriaId = 'Todos';

                            return Center(
                              child: Wrap(
                                alignment: WrapAlignment.center,
                                runAlignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(categorias.length, (
                                  index,
                                ) {
                                  final cat = categorias[index];
                                  final selected =
                                      cat.id == _selectedCategoriaId;

                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedCategoriaId = cat.id;
                                      _currentPage = 0;
                                    }),
                                    child: _CategoryPill(
                                      label: cat.nombre,
                                      selected: selected,
                                    ),
                                  );
                                }),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _productos$,
                          builder: (context, productosSnap) {
                            if (productosSnap.hasError) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 18),
                                child: Text(
                                  'Error cargando productos: ${productosSnap.error}',
                                  style: const TextStyle(color: Palette.ink),
                                ),
                              );
                            }

                            if (productosSnap.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.only(top: 18),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            final prodDocs = productosSnap.data?.docs ?? [];

                            final allProducts = prodDocs.map((p) {
                              final data = p.data();

                              final nombre = _s(data['nombre'] ?? data['name']);
                              final description = _s(
                                data['description'] ?? data['descripcion'],
                              );
                              final imagenUrl = _s(
                                data['imagenUrl'] ?? data['imageUrl'],
                              );

                              final precio = _toDouble(data['precio']);
                              final rating = _toDouble(data['rating']);
                              final almacenId = _s(data['almacenId']);

                              final stockRaw = data['stock'];
                              final stock = (stockRaw is num)
                                  ? stockRaw.toInt()
                                  : int.tryParse(stockRaw?.toString() ?? '') ??
                                        0;

                              final categoriaId = _s(data['categoriaId']);
                              final categoriaNombre = _s(
                                data['categoriaNombre'],
                              );
                              final createdAtRaw = data['createdAt'];

                              return ProductModel(
                                createdAt: createdAtRaw is Timestamp
                                    ? createdAtRaw.toDate()
                                    : null,
                                id: p.id,
                                name: nombre,
                                description: description,
                                price: precio,
                                rating: rating,
                                imageUrl: imagenUrl,
                                almacenId: almacenId,
                                stock: stock,
                                categoriaId: categoriaId,
                                categoriaNombre: categoriaNombre,
                              );
                            }).toList();

                            // Sin stock: no se muestran (solo se ocultan en
                            // la lista; el producto sigue en la base y
                            // vuelve a aparecer al reponer stock).
                            final conStock = allProducts
                                .where((p) => p.stock > 0)
                                .toList();

                            final filteredByDepto = (_selectedDepto == 'Todos')
                                ? conStock
                                : conStock.where((prod) {
                                    final dep =
                                        almacenDeptoById[prod.almacenId] ?? '';
                                    return dep == _selectedDepto;
                                  }).toList();

                            final filteredByCategoria =
                                (_selectedCategoriaId == 'Todos')
                                ? filteredByDepto
                                : filteredByDepto.where((p) {
                                    if (p.categoriaId.isNotEmpty &&
                                        p.categoriaId == _selectedCategoriaId) {
                                      return true;
                                    }
                                    return p.categoriaNombre.isNotEmpty &&
                                        p.categoriaNombre.toLowerCase() ==
                                            _selectedCategoriaId.toLowerCase();
                                  }).toList();

                            final query = _normalizeText(_searchQuery);

                            final buscados = query.isEmpty
                                ? filteredByCategoria
                                : filteredByCategoria.where((p) {
                                    final dep =
                                        almacenDeptoById[p.almacenId] ?? '';

                                    final searchable = _normalizeText(
                                      [
                                        p.name,
                                        p.description,
                                        p.categoriaNombre,
                                        dep,
                                        p.stock.toString(),
                                        p.price.toStringAsFixed(2),
                                      ].join(' '),
                                    );

                                    return searchable.contains(query);
                                  }).toList();

                            final filtered = _aplicarOrden(buscados);

                            if (filtered.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Palette.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: Palette.button.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No se encontraron productos para "$_searchQuery".'
                                        : _sort == _ProductSort.descuento
                                        ? 'Por ahora no hay productos con descuento aquí.'
                                        : _selectedDepto == 'Todos'
                                        ? 'No hay productos para esta categoría.'
                                        : 'No hay productos para "$_selectedDepto" en esta categoría.',
                                    style: TextStyle(
                                      color: Palette.ink.withOpacity(0.75),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // 📄 Paginación: corta `filtered` a la página actual.
                            final totalPages = (filtered.length / _pageSize)
                                .ceil();
                            if (totalPages > 0 && _currentPage >= totalPages) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() => _currentPage = totalPages - 1);
                              });
                            }
                            final safePage = totalPages == 0
                                ? 0
                                : _currentPage.clamp(0, totalPages - 1);
                            final startIdx = safePage * _pageSize;
                            final endIdx = math.min(
                              startIdx + _pageSize,
                              filtered.length,
                            );
                            final pageItems = filtered.sublist(
                              startIdx,
                              endIdx,
                            );

                            return Column(
                              children: [
                                // Grilla de 2 columnas armada por filas: cada
                                // fila mide lo que su card más alta (nombre
                                // largo, descuento), en vez de un alto fijo
                                // que desborda o deja cards vacías.
                                for (
                                  var r = 0;
                                  r < pageItems.length;
                                  r += 2
                                ) ...[
                                  if (r > 0) const SizedBox(height: 14),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: _productTile(pageItems[r]),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: r + 1 < pageItems.length
                                              ? _productTile(pageItems[r + 1])
                                              : const SizedBox.shrink(),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                if (totalPages > 1) ...[
                                  const SizedBox(height: 18),
                                  PillPaginationBar(
                                    currentPage: safePage,
                                    totalPages: totalPages,
                                    totalItems: filtered.length,
                                    pageSize: _pageSize,
                                    onChanged: (p) =>
                                        setState(() => _currentPage = p),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/* ---------------- MODELS ---------------- */

class CategoryModel {
  final String id;
  final String nombre;
  const CategoryModel({required this.id, required this.nombre});
}

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final double rating;
  final String imageUrl;
  final String almacenId;
  final int stock;
  final String categoriaId;
  final String categoriaNombre;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.almacenId,
    required this.stock,
    this.categoriaId = '',
    this.categoriaNombre = '',
    this.createdAt,
  });

  /// Fecha de alta del producto (para "Más nuevos").
  final DateTime? createdAt;

  /// Arma el modelo desde `productos/{id}` (mismos campos que la lista).
  factory ProductModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? {};
    String s(dynamic v) => (v ?? '').toString().trim();
    double d(dynamic v) =>
        v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;

    final stockRaw = data['stock'];
    final stock = (stockRaw is num)
        ? stockRaw.toInt()
        : int.tryParse(stockRaw?.toString() ?? '') ?? 0;

    return ProductModel(
      id: snap.id,
      name: s(data['nombre'] ?? data['name']),
      description: s(data['description'] ?? data['descripcion']),
      price: d(data['precio']),
      rating: d(data['rating']),
      imageUrl: s(data['imagenUrl'] ?? data['imageUrl']),
      almacenId: s(data['almacenId']),
      stock: stock,
      categoriaId: s(data['categoriaId']),
      categoriaNombre: s(data['categoriaNombre']),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

/* ---------------- ORDEN / FILTRO ---------------- */

enum _ProductSort {
  populares(
    'Productos populares',
    'Populares',
    Icons.local_fire_department_rounded,
  ),
  nuevos('Lo más nuevo', 'Más nuevos', Icons.fiber_new_rounded),
  descuento('En descuento', 'Con descuento', Icons.local_offer_rounded),
  precioAsc(
    'Menor precio',
    'Precio: más barato a más caro',
    Icons.trending_up_rounded,
  ),
  precioDesc(
    'Mayor precio',
    'Precio: más caro a más barato',
    Icons.trending_down_rounded,
  ),
  az('De la A a la Z', 'Nombre: A – Z', Icons.sort_by_alpha_rounded),
  za('De la Z a la A', 'Nombre: Z – A', Icons.sort_by_alpha_rounded);

  const _ProductSort(this.titulo, this.opcion, this.icon);

  /// Título grande de la sección.
  final String titulo;

  /// Texto en la hoja de opciones y en el chip activo.
  final String opcion;
  final IconData icon;
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Palette.primary : Palette.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Palette.primary.withOpacity(0.35)),
          ),
          child: Icon(
            Icons.tune_rounded,
            color: active ? Palette.white : Palette.primary,
            semanticLabel: 'Ordenar y filtrar productos',
          ),
        ),
      ),
    );
  }
}

class _ActiveSortChip extends StatelessWidget {
  const _ActiveSortChip({required this.sort, required this.onClear});

  final _ProductSort sort;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onClear,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
        decoration: BoxDecoration(
          color: Palette.button.withOpacity(0.12),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.button.withOpacity(0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(sort.icon, size: 15, color: Palette.primary),
            const SizedBox(width: 6),
            Text(
              sort.opcion,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Palette.ink,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.close_rounded,
              size: 16,
              color: Palette.ink.withOpacity(0.6),
              semanticLabel: 'Quitar filtro',
            ),
          ],
        ),
      ),
    );
  }
}

class _SortPickerSheet extends StatelessWidget {
  const _SortPickerSheet({required this.selected});

  final _ProductSort selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ordenar y filtrar',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ..._ProductSort.values.map((s) {
              final isSelected = s == selected;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.icon,
                  color: isSelected
                      ? Palette.primary
                      : Palette.ink.withOpacity(0.55),
                ),
                title: Text(
                  s.opcion,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: Palette.ink,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: Palette.primary)
                    : Icon(
                        Icons.circle_outlined,
                        color: Palette.ink.withOpacity(0.25),
                      ),
                onTap: () => Navigator.pop(context, s),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _BannerModel {
  final String productId;
  final String title;
  final String subtitle;
  final String buttonText;
  final String imageUrl;

  const _BannerModel({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    this.buttonText = 'Ver más',
  });
}

/* ---------------- HEADER ROSA + CARRUSEL ---------------- */

class _PinkPedidosHeader extends StatefulWidget {
  const _PinkPedidosHeader({
    required this.deptos,
    required this.selectedDepto,
    required this.almacenDeptoById,
    required this.onPickDepto,
    required this.onLogout,
    required this.onBell,
    required this.onCart,
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSearch,
    this.isGuest = false,
  });

  final List<String> deptos;
  final String selectedDepto;
  final VoidCallback onPickDepto;

  /// almacenId -> departamento, para mostrar solo los banners cuyo producto
  /// está en un almacén del departamento elegido.
  final Map<String, String> almacenDeptoById;

  final Future<void> Function() onLogout;
  final VoidCallback onBell;
  final VoidCallback onCart;

  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onSearch;

  final bool isGuest;

  @override
  State<_PinkPedidosHeader> createState() => _PinkPedidosHeaderState();
}

class _PinkPedidosHeaderState extends State<_PinkPedidosHeader> {
  late final PageController _pageController;
  int _page = 0;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _banners$;

  // productoId -> almacenId, para saber de qué departamento es cada banner.
  final Map<String, String> _almacenByProducto = {};

  // productoId -> stock: los banners de productos agotados no se muestran.
  final Map<String, int> _stockByProducto = {};
  bool _productosCargados = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productosSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);

    _banners$ = FirebaseFirestore.instance
        .collection('banners')
        .where('estado', isEqualTo: 'ACTIVO')
        .snapshots();

    _productosSub = FirebaseFirestore.instance
        .collection('productos')
        .snapshots()
        .listen((snap) {
          if (!mounted) return;
          setState(() {
            _productosCargados = true;
            _almacenByProducto
              ..clear()
              ..addEntries(
                snap.docs.map((d) => MapEntry(d.id, _s(d.data()['almacenId']))),
              );
            _stockByProducto
              ..clear()
              ..addEntries(
                snap.docs.map((d) {
                  final raw = d.data()['stock'];
                  final stock = raw is num
                      ? raw.toInt()
                      : int.tryParse('${raw ?? ''}') ?? 0;
                  return MapEntry(d.id, stock);
                }),
              );
          });
        });
  }

  @override
  void didUpdateWidget(covariant _PinkPedidosHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Al cambiar de departamento el carrusel vuelve al primer banner.
    if (oldWidget.selectedDepto != widget.selectedDepto && _page != 0) {
      _page = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _productosSub?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// El producto del banner tiene stock (solo se oculta, no se borra).
  bool _bannerConStock(String productId) {
    if (!_productosCargados) return true;
    return (_stockByProducto[productId] ?? 0) > 0;
  }

  bool _bannerEnDepto(String productId) {
    final depto = widget.selectedDepto;
    if (depto.isEmpty || depto == 'Todos') return true;
    final almacenId = _almacenByProducto[productId] ?? '';
    return (widget.almacenDeptoById[almacenId] ?? '') == depto;
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  Future<void> _openBannerProduct(_BannerModel banner) async {
    if (banner.productId.trim().isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('productos')
          .doc(banner.productId)
          .get();

      if (!snap.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este producto ya no está disponible')),
        );
        return;
      }

      final product = ProductModel.fromFirestore(snap);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleProductoPage(product: product),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el producto: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kPinkA = Palette.button;
    final kPinkB = Palette.gradientEnd;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kPinkA, kPinkB],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: widget.onPickDepto,
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.selectedDepto,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _TopIconButton(
                    icon: Icons.notifications_none_rounded,
                    onTap: widget.onBell,
                  ),
                  const SizedBox(width: 8),
                  // Burbuja = productos distintos en el carrito.
                  CartCountBadge(
                    child: _TopIconButton(
                      icon: Icons.shopping_cart_outlined,
                      onTap: widget.onCart,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (widget.isGuest)
                    InkWell(
                      onTap: () {
                        try {
                          Modular.get<GuestStore>().exitGuest();
                        } catch (_) {}
                        Modular.to.navigate('/auth/login');
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.login_rounded,
                              color: Palette.primary,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Ingresar',
                              style: TextStyle(
                                color: Palette.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    PopupMenuButton<String>(
                      onSelected: (_) => widget.onLogout(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'logout',
                          child: Text('Cerrar sesión'),
                        ),
                      ],
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('usuarios')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .snapshots(),
                            builder: (context, snap) {
                              final photoUrl =
                                  snap.data?.data()?['photo'] as String?;

                              return Container(
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white70,
                                    width: 2,
                                  ),
                                  color: Colors.white.withOpacity(0.15),
                                  image: photoUrl != null && photoUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(photoUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: photoUrl == null || photoUrl.isEmpty
                                    ? Icon(
                                        Icons.person_rounded,
                                        color: Colors.white.withOpacity(0.9),
                                        size: 20,
                                      )
                                    : null,
                              );
                            },
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.only(left: 14, right: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: widget.searchCtrl,
                        onChanged: widget.onSearchChanged,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                          color: Palette.ink,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Buscar productos',
                          hintStyle: TextStyle(
                            color: Palette.ink.withOpacity(0.45),
                            fontWeight: FontWeight.w700,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.searchCtrl,
                      builder: (_, value, __) {
                        final hasText = value.text.trim().isNotEmpty;

                        return InkWell(
                          onTap: hasText
                              ? widget.onClearSearch
                              : widget.onSearch,
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: Palette.button,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              hasText
                                  ? Icons.close_rounded
                                  : Icons.search_rounded,
                              color: Palette.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 170,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _banners$,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }

                    if (snap.hasError) {
                      return Center(
                        child: Text(
                          'Error cargando banners: ${snap.error}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    final docs = snap.data?.docs ?? [];

                    final banners = docs
                        .map((d) {
                          final data = d.data();
                          final productId = _s(data['idproducto']);
                          final title = _s(data['titulo']);
                          final subtitle = _s(data['subtitulo']);
                          final image = _s(data['imagen']);

                          return _BannerModel(
                            productId: productId,
                            title: title.isEmpty ? 'New Collection' : title,
                            subtitle: subtitle.isEmpty
                                ? 'Discount 50% for\nthe first transaction'
                                : subtitle,
                            imageUrl: image,
                            buttonText: 'Ver más',
                          );
                        })
                        .where(
                          (b) =>
                              b.imageUrl.isNotEmpty &&
                              b.productId.isNotEmpty &&
                              _bannerConStock(b.productId) &&
                              _bannerEnDepto(b.productId),
                        )
                        .toList();

                    if (banners.isEmpty) return const SizedBox.shrink();

                    if (_page >= banners.length) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _page = 0);
                        try {
                          _pageController.jumpToPage(0);
                        } catch (_) {}
                      });
                    }

                    return Stack(
                      children: [
                        PageView.builder(
                          controller: _pageController,
                          itemCount: banners.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) => _FurnitureBannerCard(
                            banner: banners[i],
                            onTap: () => _openBannerProduct(banners[i]),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(banners.length, (i) {
                              final active = i == _page;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: _Dot(active: active),
                              );
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeptoPickerSheet extends StatelessWidget {
  final List<String> deptos;
  final String selected;

  const _DeptoPickerSheet({required this.deptos, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 4,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Selecciona un departamento',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Palette.ink,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 10),
            ...deptos.map((d) {
              final isSelected = d == selected;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  d,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                    color: Palette.ink,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: Palette.primary)
                    : Icon(
                        Icons.circle_outlined,
                        color: Palette.ink.withOpacity(0.25),
                      ),
                onTap: () => Navigator.pop(context, d),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FurnitureBannerCard extends StatelessWidget {
  const _FurnitureBannerCard({required this.banner, required this.onTap});

  final _BannerModel banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardBg = Palette.white.withOpacity(0.92);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Stack(
          children: [
            Positioned(
              right: 8,
              bottom: 8,
              top: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 140,
                  child: Image.network(
                    banner.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 140,
                      color: Palette.fieldBg,
                      child: Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Palette.ink.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              top: 18,
              right: 160,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    banner.title,
                    style: TextStyle(
                      color: Palette.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle,
                    style: TextStyle(
                      color: Palette.ink.withOpacity(0.55),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Palette.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        banner.buttonText,
                        style: TextStyle(
                          color: Palette.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- UI helpers ---------------- */

class _TopIconButton extends StatelessWidget {
  const _TopIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 6,
      width: active ? 20 : 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(active ? 0.95 : 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/* ---------------- RESTO (chips + cards) ---------------- */

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? Palette.primary : Colors.transparent,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? Palette.ink : Palette.ink.withOpacity(0.65),
        ),
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  const _ProductCard({required this.product, required this.wishlist});

  final ProductModel product;
  final WishlistStore wishlist;

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      // Lo que dura la animación de "me gusta" (pop + ráfaga).
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tapLike(bool isLiked) {
    bool isGuest = false;
    try {
      isGuest = Modular.get<GuestStore>().value;
    } catch (_) {}

    if (isGuest) {
      showGuestLockSheet(
        context,
        icon: Icons.favorite_rounded,
        title: 'Guarda tus favoritos',
        message:
            'Inicia sesión para marcar productos como favoritos y encontrarlos más rápido.',
      );
      return;
    }

    if (!isLiked) {
      _ctrl.forward(from: 0);
      HapticFeedback.lightImpact();
    }
    widget.wishlist.toggle(widget.product);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _descuentoStream(String id) {
    return FirebaseFirestore.instance
        .collection('productos')
        .doc(id)
        .collection('descuentos')
        .doc('activo')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _reviewsStream(String id) {
    return FirebaseFirestore.instance
        .collection('productos')
        .doc(id)
        .collection('reviews')
        .snapshots();
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasImg = product.imageUrl.trim().isNotEmpty;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _descuentoStream(product.id),
      builder: (context, descuentoSnap) {
        final d = descuentoSnap.data?.data();
        final activo = (d?['activo'] == true);

        final tipo = (d?['tipo'] ?? 'PORCENTAJE').toString().trim();
        final valor = _toDouble(d?['valor']);

        final hasDescuento = activo && valor > 0;

        final base = product.price;
        double finalPrice = base;
        String badge = '';
        String line = '';

        if (hasDescuento) {
          if (tipo == 'PORCENTAJE') {
            final pct = valor.clamp(0.0, 100.0);
            finalPrice = base * (1 - (pct / 100));
            finalPrice = math.max(0, finalPrice);

            final pctTxt = (pct % 1 == 0)
                ? pct.toStringAsFixed(0)
                : pct.toStringAsFixed(1);

            badge = '-$pctTxt%';
            line = 'DESCUENTO $badge';
          } else {
            finalPrice = math.max(0, base - valor);

            final vTxt = (valor % 1 == 0)
                ? valor.toStringAsFixed(0)
                : valor.toStringAsFixed(2);

            badge = '-Bs $vTxt';
            line = 'DESCUENTO $badge';
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _reviewsStream(product.id),
          builder: (context, reviewSnap) {
            final reviewDocs = reviewSnap.data?.docs ?? [];

            double avgRating = product.rating;
            final totalReviews = reviewDocs.length;

            if (reviewDocs.isNotEmpty) {
              double sum = 0;
              for (final doc in reviewDocs) {
                sum += _toDouble(doc.data()['rating']);
              }
              avgRating = sum / reviewDocs.length;
            }

            return Container(
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        AnimatedBuilder(
                          animation: widget.wishlist,
                          builder: (_, __) {
                            final liked = widget.wishlist.contains(product.id);
                            return _LikeButtonSmooth(
                              controller: _ctrl,
                              liked: liked,
                              onTap: () => _tapLike(liked),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AspectRatio(
                        aspectRatio: 1 / 1,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              // Mantener presionado: imagen en pantalla
                              // completa (el toque abre el detalle).
                              child: ZoomableImage(
                                url: hasImg ? product.imageUrl : '',
                                titulo: product.name,
                                child: Hero(
                                  tag: 'product_${product.id}',
                                  child: hasImg
                                      ? Image.network(
                                          product.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const _NoImage(),
                                        )
                                      : const _NoImage(),
                                ),
                              ),
                            ),
                            if (hasDescuento)
                              Positioned(
                                left: 10,
                                top: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.12),
                                        blurRadius: 10,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    badge,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      product.name.isEmpty ? 'Producto' : product.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Bs. ${(hasDescuento ? finalPrice : base).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.ink,
                                ),
                              ),
                              if (hasDescuento)
                                Text(
                                  'Bs. ${base.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Palette.ink.withOpacity(0.40),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: Color(0xFFFFB300),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          avgRating <= 0 ? '0.0' : avgRating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Palette.ink.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                    if (hasDescuento) ...[
                      const SizedBox(height: 6),
                      Text(
                        line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    /*Text(
                      'Stock: ${product.stock}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink.withOpacity(0.55),
                      ),
                    ),*/
                    const SizedBox(height: 4),
                    Text(
                      '$totalReviews reseña${totalReviews == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink.withOpacity(0.45),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Corazón de favoritos. Al marcarlo: se encoge, explota con un rebote
/// elástico, sale un anillo con una ráfaga de puntitos y suben tres
/// corazoncitos. Al desmarcarlo solo cambia suave.
///
/// [controller] lo dispara la card (`forward(from: 0)`) solo al marcar.
class _LikeButtonSmooth extends StatelessWidget {
  const _LikeButtonSmooth({
    required this.controller,
    required this.liked,
    required this.onTap,
  });

  final AnimationController controller;
  final bool liked;
  final VoidCallback onTap;

  static double _iv(double t, double a, double b, [Curve c = Curves.linear]) {
    return c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    // Encoge → explota (pasa de tamaño) → rebota hasta su tamaño normal.
    final pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.72,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.72,
          end: 1.38,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 26,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.38,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(controller);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 30,
        width: 30,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final t = controller.value;
            final activo = controller.isAnimating && liked;

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Anillo + ráfaga de puntitos.
                if (activo)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CorazonBurstPainter(
                          anillo: _iv(t, 0.10, 0.55, Curves.easeOut),
                          rafaga: _iv(t, 0.14, 0.80, Curves.easeOutCubic),
                        ),
                      ),
                    ),
                  ),

                // Corazoncitos que suben.
                if (activo)
                  for (final (dx, retraso, tam) in const [
                    (-11.0, 0.18, 9.0),
                    (0.0, 0.26, 11.0),
                    (11.0, 0.34, 8.0),
                  ])
                    _CorazonFlotante(
                      progreso: _iv(t, retraso, retraso + 0.55),
                      dx: dx,
                      tam: tam,
                    ),

                // El corazón.
                Transform.scale(
                  scale: activo ? pop.value : 1,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: Container(
                      key: ValueKey(liked),
                      height: 30,
                      width: 30,
                      decoration: BoxDecoration(
                        color: liked
                            ? Palette.button.withValues(alpha: 0.16)
                            : Palette.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: liked
                            ? Palette.button
                            : Palette.ink.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Corazoncito que sube y se desvanece sobre el botón.
class _CorazonFlotante extends StatelessWidget {
  const _CorazonFlotante({
    required this.progreso,
    required this.dx,
    required this.tam,
  });

  final double progreso;
  final double dx;
  final double tam;

  @override
  Widget build(BuildContext context) {
    if (progreso <= 0 || progreso >= 1) return const SizedBox.shrink();
    final subida = Curves.easeOutCubic.transform(progreso);
    // Aparece rápido y se apaga al final.
    final opacidad = progreso < 0.2
        ? progreso / 0.2
        : 1 - Curves.easeIn.transform((progreso - 0.2) / 0.8);
    final balanceo = math.sin(progreso * math.pi * 2) * 3;

    return IgnorePointer(
      child: Transform.translate(
        offset: Offset(dx + balanceo, -8 - 30 * subida),
        child: Opacity(
          opacity: opacidad.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.6 + 0.4 * subida,
            child: Icon(
              Icons.favorite_rounded,
              size: tam,
              color: Palette.button,
            ),
          ),
        ),
      ),
    );
  }
}

/// Anillo que se expande y puntitos de colores que salen en círculo.
class _CorazonBurstPainter extends CustomPainter {
  _CorazonBurstPainter({required this.anillo, required this.rafaga});

  final double anillo;
  final double rafaga;

  static const _colores = [
    Palette.button,
    Palette.statsDanger,
    Palette.primary,
    Palette.secButton,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    if (anillo > 0 && anillo < 1) {
      canvas.drawCircle(
        c,
        10 + 16 * anillo,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - anillo)
          ..color = Palette.button.withValues(alpha: 1 - anillo),
      );
    }

    if (rafaga > 0 && rafaga < 1) {
      const n = 10;
      for (var i = 0; i < n; i++) {
        final ang = (i / n) * math.pi * 2 - math.pi / 2;
        // Puntitos alternados: unos llegan más lejos que otros.
        final lejos = i.isEven ? 26.0 : 19.0;
        final d = 9 + lejos * rafaga;
        final r = (i.isEven ? 2.8 : 2.2) * (1 - rafaga);
        canvas.drawCircle(
          c + Offset(math.cos(ang), math.sin(ang)) * d,
          r,
          Paint()
            ..color = _colores[i % _colores.length].withValues(
              alpha: 1 - rafaga * 0.6,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CorazonBurstPainter old) =>
      old.anillo != anillo || old.rafaga != rafaga;
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Palette.fieldBg,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: Palette.ink.withOpacity(0.25),
          size: 34,
        ),
      ),
    );
  }
}
