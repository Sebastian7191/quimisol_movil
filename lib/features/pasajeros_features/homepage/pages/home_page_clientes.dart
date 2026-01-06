// lib/features/home/home_cliente.dart
//
// ✅ HomePage (HomeCliente) COMPLETA + FILTRO POR DEPARTAMENTO
// ✅ Wishlist (Like) con animación SUAVE (sin flash) + sincronizado con WishlistPage

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';
import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist_store.dart';

import 'package:quimisol_movil/shared/services/auth_service.dart';
import 'package:quimisol_movil/core/theme/palette.dart';

// ✅ Import de la página de detalle
import 'detalle_producto.dart';

class HomeCliente extends StatefulWidget {
  const HomeCliente({super.key});

  @override
  State<HomeCliente> createState() => _HomeClienteState();
}

class _HomeClienteState extends State<HomeCliente> {
  late final AuthService _authService;

  int _selectedCategory = 0;

  // ✅ Departamento seleccionado (para filtrar productos)
  String _selectedDepto = 'Todos';

  // ✅ Categorías reducidas (más compacto visualmente)
  final List<_CatModel> categories = const [
    _CatModel(label: 'Botella'),
    _CatModel(label: 'Tapa'),
    _CatModel(label: 'Limpieza'),
    _CatModel(label: 'Químicos'),
    _CatModel(label: 'Envases'),
  ];

  // ✅ Wishlist store (ChangeNotifier)
  final WishlistStore _wishlist = WishlistStore.I;

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();

    _wishlist.bind();
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await _authService.logout();
    Modular.to.navigate('/login');
  }

  // ✅ Stream almacenes
  Stream<QuerySnapshot<Map<String, dynamic>>> _almacenesStream() {
    return FirebaseFirestore.instance.collection('almacenes').snapshots();
  }

  // ✅ Stream productos
  Stream<QuerySnapshot<Map<String, dynamic>>> _productosStream() {
    return FirebaseFirestore.instance.collection('productos').snapshots();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _almacenesStream(),
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
            final dep = (data['departamento'] ?? '').toString().trim();
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
                                  color: Palette.ink.withOpacity(0.55),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            runAlignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: List.generate(categories.length, (index) {
                              final cat = categories[index];
                              final selected = index == _selectedCategory;

                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedCategory = index),
                                child: _CategoryPill(
                                  label: cat.label,
                                  selected: selected,
                                ),
                              );
                            }),
                          ),
                        ),

                        const SizedBox(height: 12),

                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _productosStream(),
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

                              final nombre =
                                  (data['nombre'] ?? data['name'] ?? '')
                                      .toString();

                              final description =
                                  (data['description'] ??
                                          data['descripcion'] ??
                                          '')
                                      .toString();

                              final precioRaw = data['precio'];
                              final precio = (precioRaw is num)
                                  ? precioRaw.toDouble()
                                  : double.tryParse(
                                          precioRaw?.toString() ?? '',
                                        ) ??
                                        0.0;

                              final imagenUrl =
                                  (data['imagenUrl'] ?? data['imageUrl'] ?? '')
                                      .toString();

                              final ratingRaw = data['rating'];
                              final rating = (ratingRaw is num)
                                  ? ratingRaw.toDouble()
                                  : double.tryParse(
                                          ratingRaw?.toString() ?? '',
                                        ) ??
                                        0.0;

                              final almacenId = (data['almacenId'] ?? '')
                                  .toString()
                                  .trim();

                              final stockRaw = data['stock'];
                              final stock = (stockRaw is num)
                                  ? stockRaw.toInt()
                                  : int.tryParse(stockRaw?.toString() ?? '') ??
                                        0;

                              return ProductModel(
                                id: p.id,
                                name: nombre,
                                description: description,
                                price: precio,
                                rating: rating,
                                imageUrl: imagenUrl,
                                almacenId: almacenId,
                                stock: stock,
                              );
                            }).toList();

                            final filteredByDepto = (_selectedDepto == 'Todos')
                                ? allProducts
                                : allProducts.where((prod) {
                                    final dep =
                                        almacenDeptoById[prod.almacenId] ?? '';
                                    return dep == _selectedDepto;
                                  }).toList();

                            if (filteredByDepto.isEmpty) {
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
                                    _selectedDepto == 'Todos'
                                        ? 'No hay productos registrados aún.'
                                        : 'No hay productos para "$_selectedDepto".',
                                    style: TextStyle(
                                      color: Palette.ink.withOpacity(0.75),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              );
                            }

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredByDepto.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: 0.78,
                                  ),
                              itemBuilder: (_, i) {
                                final prod = filteredByDepto[i];
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
                                    wishlist:
                                        _wishlist, // ✅ pasa store para escuchar SOLO el like
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

class _CatModel {
  final String label;
  const _CatModel({required this.label});
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

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    required this.imageUrl,
    required this.almacenId,
    required this.stock,
  });
}

class _BannerModel {
  final String title;
  final String subtitle;
  final String buttonText;
  final String imageUrl;

  const _BannerModel({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.imageUrl,
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

  final List<_BannerModel> _banners = const [
    _BannerModel(
      title: 'New Collection',
      subtitle: 'Discount 50% for\nthe first transaction',
      buttonText: 'Shop Now',
      imageUrl:
          'https://images.unsplash.com/photo-1549187774-b4e9b0445b41?auto=format&fit=crop&w=900&q=60',
    ),
    _BannerModel(
      title: 'Productos nuevos',
      subtitle: 'Ahorra hoy en\nseleccionados',
      buttonText: 'Ver más',
      imageUrl:
          'https://images.unsplash.com/photo-1582582429415-6a54a44b31b3?auto=format&fit=crop&w=900&q=60',
    ),
    _BannerModel(
      title: 'Super ofertas',
      subtitle: 'Hasta 30% en\nlimpieza y envases',
      buttonText: 'Comprar',
      imageUrl:
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?auto=format&fit=crop&w=900&q=60',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
                                snap.data?.data()?['photoUrl'] as String?;

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
                    Icon(
                      Icons.search_rounded,
                      color: Palette.ink.withOpacity(0.50),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Buscar productos',
                        style: TextStyle(
                          color: Palette.ink.withOpacity(0.45),
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
              SizedBox(
                height: 170,
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _banners.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) => _FurnitureBannerCard(
                        banner: _banners[i],
                        onTap: () {},
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_banners.length, (i) {
                          final active = i == _page;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _Dot(active: active),
                          );
                        }),
                      ),
                    ),
                  ],
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
                      color: Palette.ink.withOpacity(0.55),
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
      duration: const Duration(milliseconds: 380), // ✅ más corto = más nítido
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _tapLike(bool isLiked) {
    // Si va a quedar "like", animamos pop+burst; si es unlike, hacemos solo un "shrink" suave
    if (!isLiked) _ctrl.forward(from: 0);
    widget.wishlist.toggle(widget.product);
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasImg = product.imageUrl.trim().isNotEmpty;

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
            // ✅ Like arriba derecha (escucha SOLO al store, sin setState global)
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

            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Hero(
                  tag: 'product_${product.id}',
                  child: hasImg
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => const _NoImage(),
                        )
                      : const _NoImage(),
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
                Text(
                  'Bs. ${product.price.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Palette.ink,
                  ),
                ),
                const Spacer(),
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
                    color: Palette.ink.withOpacity(0.65),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Stock: ${product.stock}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Palette.ink.withOpacity(0.55),
              ),
            ),
          ],
        ),
      ),
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
            // Burst discreto (solo cuando haces like)
            AnimatedBuilder(
              animation: controller,
              builder: (_, __) => Opacity(
                opacity: fade.value * 0.9,
                child: Container(
                  height: 20 + (fade.value * 14),
                  width: 20 + (fade.value * 14),
                  decoration: BoxDecoration(
                    color: Palette.button.withOpacity(0.16),
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
                        : Palette.ink.withOpacity(0.75),
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
          color: Palette.ink.withOpacity(0.25),
          size: 34,
        ),
      ),
    );
  }
}
