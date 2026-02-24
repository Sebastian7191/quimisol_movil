// lib/features/home/home_cliente.dart
//
// ✅ HomePage (HomeCliente) COMPLETA + FILTRO POR DEPARTAMENTO
// ✅ Categorías desde Firestore (collection: categorias)
// ✅ Wishlist (Like) con animación SUAVE (sin flash) + sincronizado con WishlistPage
// ✅ Mostrar DESCUENTO en card (precio final + precio tachado + badge + texto)
// ✅ La imagen NO se achica por el descuento (AspectRatio fijo)
// ✅ Banners desde Firestore (collection: banners) SOLO estado ACTIVO
// ✅ FIX: ya NO parpadea al tocar categorías (streams cacheados)

import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';
import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist_store.dart';
import 'package:quimisol_movil/shared/services/auth_service.dart';

import 'detalle_producto.dart';

class HomeCliente extends StatefulWidget {
  const HomeCliente({super.key});

  @override
  State<HomeCliente> createState() => _HomeClienteState();
}

class _HomeClienteState extends State<HomeCliente> {
  late final AuthService _authService;

  // ✅ Departamento seleccionado
  String _selectedDepto = 'Todos';

  // ✅ Categoría seleccionada (id)
  String _selectedCategoriaId = 'Todos';

  // ✅ Streams cacheados (evita parpadeo)
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _almacenes$;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productos$;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _categorias$;

  // ✅ Wishlist store
  final WishlistStore _wishlist = WishlistStore.I;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
    _wishlist.bind();

    _almacenes$ = FirebaseFirestore.instance
        .collection('almacenes')
        .snapshots();
    _productos$ = FirebaseFirestore.instance
        .collection('productos')
        .snapshots();

    // 🔧 Ajusta si tu colección se llama distinto
    _categorias$ = FirebaseFirestore.instance
        .collection('categorias')
        // si tu campo no es 'nombre', cambia esto o quita orderBy
        .orderBy('nombre')
        .snapshots();
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
                  color: Palette.ink.withValues(alpha: 0.7),
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
                          color: Palette.primary.withValues(alpha: 0.4),
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
    Modular.to.navigate('/login');
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
    setState(() => _selectedDepto = chosen);
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
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

          // Map: almacenId -> departamento
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

          if (!deptos.contains(_selectedDepto)) {
            _selectedDepto = 'Todos';
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                _PinkPedidosHeader(
                  deptos: deptos,
                  selectedDepto: _selectedDepto,
                  onPickDepto: () => _openDeptoPicker(deptos),
                  onLogout: _logout,
                  onBell: () {},
                  onCart: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CarritoPage()),
                    );
                  },
                  onSearch: () {},
                ),

                SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Productos populares',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  color: Palette.ink,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                'view all',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Palette.ink.withValues(alpha: 0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ✅ CATEGORÍAS DESDE FIRESTORE
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _categorias$,
                          builder: (context, catSnap) {
                            if (catSnap.connectionState ==
                                ConnectionState.waiting) {
                              // no loader grande para no “flash”
                              return const SizedBox(height: 42);
                            }

                            final docs = catSnap.data?.docs ?? [];

                            final categorias = <CategoryModel>[
                              const CategoryModel(id: 'Todos', nombre: 'Todos'),
                              ...docs.map((d) {
                                final data = d.data();
                                // 🔧 Ajusta campos si tu doc usa otros nombres
                                final nombre = _s(data['nombre']);
                                return CategoryModel(
                                  id: d.id,
                                  nombre: nombre.isEmpty ? 'Categoría' : nombre,
                                );
                              }),
                            ];

                            // si la seleccion ya no existe
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
                                    onTap: () => setState(
                                      () => _selectedCategoriaId = cat.id,
                                    ),
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

                        // ✅ PRODUCTOS
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

                              // ✅ categoría guardada en producto
                              final categoriaId = _s(data['categoriaId']);
                              final categoriaNombre = _s(
                                data['categoriaNombre'],
                              );

                              return ProductModel(
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

                            // filtro por depto
                            final filteredByDepto = (_selectedDepto == 'Todos')
                                ? allProducts
                                : allProducts.where((prod) {
                                    final dep =
                                        almacenDeptoById[prod.almacenId] ?? '';
                                    return dep == _selectedDepto;
                                  }).toList();

                            // filtro por categoría
                            final filtered = (_selectedCategoriaId == 'Todos')
                                ? filteredByDepto
                                : filteredByDepto.where((p) {
                                    // match por id (ideal)
                                    if (p.categoriaId.isNotEmpty &&
                                        p.categoriaId == _selectedCategoriaId) {
                                      return true;
                                    }
                                    // fallback por nombre (por si tus productos guardan solo el nombre)
                                    return p.categoriaNombre.isNotEmpty &&
                                        p.categoriaNombre.toLowerCase() ==
                                            _selectedCategoriaId.toLowerCase();
                                  }).toList();

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
                                      color: Palette.button.withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Text(
                                    _selectedDepto == 'Todos'
                                        ? 'No hay productos para esta categoría.'
                                        : 'No hay productos para "$_selectedDepto" en esta categoría.',
                                    style: TextStyle(
                                      color: Palette.ink.withValues(alpha: 0.75),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filtered.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,

                                    // ✅ Más alto (tú lo controlas aquí)
                                    // 0.60 = más alto
                                    // 0.65 = menos alto
                                    childAspectRatio: 0.60,
                                  ),
                              itemBuilder: (_, i) {
                                final prod = filtered[i];
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DetalleProductoPage(product: prod),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: _ProductCard(
                                    product: prod,
                                    wishlist: _wishlist,
                                  ),
                                );
                              },
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
  });
}

class _BannerModel {
  final String title;
  final String subtitle;
  final String buttonText; // se mantiene igual visualmente
  final String imageUrl;

  const _BannerModel({
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
    required this.onPickDepto,
    required this.onLogout,
    required this.onBell,
    required this.onCart,
    required this.onSearch,
  });

  final List<String> deptos;
  final String selectedDepto;
  final VoidCallback onPickDepto;

  final Future<void> Function() onLogout;
  final VoidCallback onBell;
  final VoidCallback onCart;
  final VoidCallback onSearch;

  @override
  State<_PinkPedidosHeader> createState() => _PinkPedidosHeaderState();
}

class _PinkPedidosHeaderState extends State<_PinkPedidosHeader> {
  late final PageController _pageController;
  int _page = 0;

  // ✅ stream cacheado para no “flash”
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _banners$;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);

    _banners$ = FirebaseFirestore.instance
        .collection('banners')
        .where('estado', isEqualTo: 'ACTIVO')
        .snapshots();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _s(dynamic v) => (v ?? '').toString().trim();

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
                  _TopIconButton(
                    icon: Icons.shopping_cart_outlined,
                    onTap: widget.onCart,
                  ),
                  const SizedBox(width: 10),
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
                                color: Colors.white.withValues(alpha: 0.15),
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
                                      color: Colors.white.withValues(alpha: 0.9),
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

              // buscador (igual)
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Palette.white,
                  borderRadius: BorderRadius.circular(26),
                ),
                padding: const EdgeInsets.only(left: 14, right: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: Palette.ink.withValues(alpha: 0.50),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Buscar productos',
                        style: TextStyle(
                          color: Palette.ink.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: widget.onSearch,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        height: 38,
                        width: 38,
                        decoration: BoxDecoration(
                          color: Palette.button,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.search_rounded, color: Palette.white),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ✅ Carrusel: MISMO DISEÑO, datos desde Firestore
              SizedBox(
                height: 170,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _banners$,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      // no “flash” fuerte
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
                          final title = _s(data['titulo']);
                          final subtitle = _s(data['subtitulo']);
                          final image = _s(data['imagen']);
                          return _BannerModel(
                            title: title.isEmpty ? 'New Collection' : title,
                            subtitle: subtitle.isEmpty
                                ? 'Discount 50% for\nthe first transaction'
                                : subtitle,
                            imageUrl: image,
                            buttonText: 'Ver más',
                          );
                        })
                        .where((b) => b.imageUrl.isNotEmpty)
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
                            onTap: () {},
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
                color: Colors.black.withValues(alpha: 0.12),
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
                        color: Palette.ink.withValues(alpha: 0.25),
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
    final cardBg = Palette.white.withValues(alpha: 0.92);

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
                  child: Image.network(banner.imageUrl, fit: BoxFit.cover),
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
                      color: Palette.ink.withValues(alpha: 0.55),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
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
          color: Colors.white.withValues(alpha: 0.18),
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
        color: Colors.white.withValues(alpha: active ? 0.95 : 0.45),
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
            color: Colors.black.withValues(alpha: 0.04),
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
          color: selected ? Palette.ink : Palette.ink.withValues(alpha: 0.65),
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
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tapLike(bool isLiked) {
    if (!isLiked) _ctrl.forward(from: 0);
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
      builder: (context, snap) {
        final d = snap.data?.data();
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

        return Container(
          decoration: BoxDecoration(
            color: Palette.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                // Like arriba derecha
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

                // ✅ Imagen con altura fija (no se achica por descuento)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    // ✅ controla “alto” visual de la imagen aquí
                    aspectRatio: 16 / 10,
                    child: Stack(
                      children: [
                        Positioned.fill(
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
                                    color: Colors.black.withValues(alpha: 0.12),
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
                  maxLines: 1,
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
                                color: Palette.ink.withValues(alpha: 0.40),
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
                      product.rating <= 0
                          ? '0.0'
                          : product.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Palette.ink.withValues(alpha: 0.65),
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

                Text(
                  'Stock: ${product.stock}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Palette.ink.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LikeButtonSmooth extends StatelessWidget {
  const _LikeButtonSmooth({
    required this.controller,
    required this.liked,
    required this.onTap,
  });

  final AnimationController controller;
  final bool liked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pop = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.18,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 50,
      ),
    ]).animate(controller);

    final fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 45),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 30,
        width: 30,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: controller,
              builder: (_, __) => Opacity(
                opacity: fade.value * 0.9,
                child: Container(
                  height: 20 + (fade.value * 14),
                  width: 20 + (fade.value * 14),
                  decoration: BoxDecoration(
                    color: Palette.button.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            ScaleTransition(
              scale: pop,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
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
                    color: Palette.card,
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
        ),
      ),
    );
  }
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
          color: Palette.ink.withValues(alpha: 0.25),
          size: 34,
        ),
      ),
    );
  }
}
