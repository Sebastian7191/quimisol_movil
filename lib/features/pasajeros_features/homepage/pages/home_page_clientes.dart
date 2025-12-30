// lib/features/home/home_cliente.dart
//
// ✅ HomePage (HomeCliente) COMPLETA
// - Categorías sin emojis, centradas y más compactas
// - Al tocar un producto navega a: detalle_producto.dart
// - Incluye Hero tag para animación de imagen
//
// Requiere: palette.dart en quimisol_movil/core/theme/palette.dart
// Requiere: detalle_producto.dart (lo haremos después)

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito.dart';

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

  // ✅ Categorías reducidas (más compacto visualmente)
  final List<_CatModel> categories = const [
    _CatModel(label: 'Botella'),
    _CatModel(label: 'Tapa'),
    _CatModel(label: 'Limpieza'),
    _CatModel(label: 'Químicos'),
    _CatModel(label: 'Envases'),
  ];

  // ✅ Modelo público (para poder pasarlo a detalle_producto.dart)
  final List<ProductModel> products = const [
    ProductModel(
      name: 'Ichiraku Ramen',
      price: 15.00,
      rating: 4.5,
      imageUrl:
          'https://images.unsplash.com/photo-1604908554162-45f20aefc17a?auto=format&fit=crop&w=800&q=60',
    ),
    ProductModel(
      name: 'Philadelphia roll',
      price: 9.50,
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1563612116625-3012372fccce?auto=format&fit=crop&w=800&q=60',
    ),
    ProductModel(
      name: 'Salmon sushi',
      price: 12.00,
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1553621042-f6e147245754?auto=format&fit=crop&w=800&q=60',
    ),
    ProductModel(
      name: 'Miso soup',
      price: 6.00,
      rating: 4.6,
      imageUrl:
          'https://images.unsplash.com/photo-1604908176997-125f25cc5007?auto=format&fit=crop&w=800&q=60',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _authService = Modular.get<AuthService>();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _PinkPedidosHeader(
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
                              fontSize: 30, // ✅ NO tocado
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

                    // ✅ Categorías centradas + compactas
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

                    // ✅ Productos: tocar -> DetalleProductoPage
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.78,
                          ),
                      itemBuilder: (_, i) => InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DetalleProductoPage(product: products[i]),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: _ProductCard(product: products[i]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- MODELS ---------------- */

class _CatModel {
  final String label;
  const _CatModel({required this.label});
}

// ✅ Público para que detalle_producto.dart lo use
class ProductModel {
  final String name;
  final double price;
  final double rating;
  final String imageUrl;

  const ProductModel({
    required this.name,
    required this.price,
    required this.rating,
    required this.imageUrl,
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
    required this.onLogout,
    required this.onBell,
    required this.onCart,
    required this.onSearch,
  });

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
    final kPinkA = Palette.button; // rosa
    final kPinkB = Palette.gradientEnd; // rosa pastel

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
                      onTap: () {},
                      borderRadius: BorderRadius.circular(14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Luis Espinal 587',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
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
                    child: Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white70, width: 2),
                        image: const DecorationImage(
                          image: NetworkImage(
                            'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=200&q=60',
                          ),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
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
                        'Search Furniture',
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

              // ✅ Carrusel banners
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
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
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: Palette.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    size: 18,
                    color: Palette.ink.withOpacity(0.75),
                  ),
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Hero(
                  tag: 'product_${product.name}_${product.imageUrl}',
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
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
                  '\$ ${product.price.toStringAsFixed(2)}',
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
                  product.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Palette.ink.withOpacity(0.65),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
