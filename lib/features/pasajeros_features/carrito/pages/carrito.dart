// lib/features/pasajeros_features/carrito/pages/carrito.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:quimisol_movil/core/theme/palette.dart';
import 'package:quimisol_movil/features/pasajeros_features/carrito/pages/carrito_store.dart';
import 'package:quimisol_movil/features/pasajeros_features/pagos/pages/metodo_pago_page.dart';

class CarritoPage extends StatefulWidget {
  const CarritoPage({super.key});

  @override
  State<CarritoPage> createState() => _CarritoPageState();
}

class _CarritoPageState extends State<CarritoPage> {
  final CartStore _store = CartStore.I;

  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  // selección de ubicación
  UbicacionSeleccionada? _selectedUbic;
  bool _paying = false;

  // ✅ departamentos permitidos (según almacenes del carrito)
  Set<String> _allowedDeptos = {};
  bool _loadingDeptos = false;
  Timer? _deptoDebounce;

  // ✅ Evita parpadeo: solo recalcula si cambió el set de productos (no por qty)
  String _lastProductsKey = '';

  // ✅ FIX PARPADEO: cachea el stream de ubicaciones
  Stream<QuerySnapshot<Map<String, dynamic>>>? _ubicStream;
  String _ubicStreamKey = '';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _store.bind(); // asegura cargar carrito al entrar
      await _refreshAllowedDeptos(force: true); // calcula deptos permitidos
    });
  }

  @override
  void dispose() {
    _deptoDebounce?.cancel();
    _store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    // ✅ mostrar mensaje friendly si hay
    final msg = _store.consumeToast();
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    // ✅ SOLO recalcular deptos si cambió el set de productIds (add/remove/clear)
    final keyNow = _currentProductsKey();
    if (keyNow != _lastProductsKey) {
      _deptoDebounce?.cancel();
      _deptoDebounce = Timer(const Duration(milliseconds: 250), () {
        _refreshAllowedDeptos(force: true);
      });
    }

    // ✅ igual se necesita rebuild para qty/precios, pero el stream ya no se reinicia
    setState(() {});
  }

  List<CartItem> get _items => _store.items;

  double get _subtotal {
    double sum = 0;
    for (final it in _items) {
      sum += it.price * it.qty;
    }
    return sum;
  }

  double get _shipping => 0;

  // ✅ total (según precio guardado en carrito)
  double get _total =>
      (_subtotal + _shipping) < 0 ? 0 : (_subtotal + _shipping);

  CollectionReference<Map<String, dynamic>> get _ubicRef =>
      _fire.collection('usuarios').doc(_uid).collection('ubicaciones');

  String _norm(String s) => s.trim().toLowerCase();

  String _currentProductsKey() {
    final ids = _items.map((e) => e.id).toSet().toList()..sort();
    return ids.join('|');
  }

  /// ✅ FIX PARPADEO:
  /// - NO crea Stream nuevo en cada build
  /// - SOLO cambia cuando cambia _allowedDeptos
  Stream<QuerySnapshot<Map<String, dynamic>>> _ubicStreamFiltered() {
    final keyList = _allowedDeptos.toList()..sort();
    final key = keyList.join('|');

    if (_ubicStream != null && _ubicStreamKey == key) {
      return _ubicStream!;
    }

    _ubicStreamKey = key;

    if (_allowedDeptos.isEmpty) {
      _ubicStream = _ubicRef.snapshots();
      return _ubicStream!;
    }

    final list = keyList;
    if (list.length <= 10) {
      _ubicStream = _ubicRef.where('departamento', whereIn: list).snapshots();
      return _ubicStream!;
    }

    _ubicStream = _ubicRef.snapshots();
    return _ubicStream!;
  }

  /// ✅ Calcula departamentos permitidos leyendo:
  /// carrito -> productos/{id} -> almacenId -> almacenes/{almacenId}.departamento
  Future<void> _refreshAllowedDeptos({bool force = false}) async {
    if (_uid.isEmpty) return;

    final keyNow = _currentProductsKey();
    if (!force && keyNow == _lastProductsKey) return;

    _lastProductsKey = keyNow;

    if (_items.isEmpty) {
      if (mounted) {
        setState(() {
          _allowedDeptos = {};
          _loadingDeptos = false;

          // ✅ reset stream cache
          _ubicStream = null;
          _ubicStreamKey = '';
        });
      }
      return;
    }

    if (mounted) setState(() => _loadingDeptos = true);

    try {
      final productIds = _items.map((e) => e.id).toSet().toList();

      final productFutures = productIds.map((pid) async {
        final doc = await _fire.collection('productos').doc(pid).get();
        if (!doc.exists) return null;
        final data = doc.data() as Map<String, dynamic>;
        final almacenId = (data['almacenId'] ?? '').toString().trim();
        if (almacenId.isEmpty) return null;
        return almacenId;
      }).toList();

      final almacenIdsRaw = await Future.wait(productFutures);
      final almacenIds = almacenIdsRaw.whereType<String>().toSet().toList();

      if (almacenIds.isEmpty) {
        if (mounted) {
          setState(() {
            _allowedDeptos = {};
            _loadingDeptos = false;

            // ✅ reset stream cache
            _ubicStream = null;
            _ubicStreamKey = '';
          });
        }
        return;
      }

      final depFutures = almacenIds.map((aid) async {
        final doc = await _fire.collection('almacenes').doc(aid).get();
        if (!doc.exists) return null;
        final data = doc.data() as Map<String, dynamic>;
        final dep = (data['departamento'] ?? '').toString().trim();
        if (dep.isEmpty) return null;
        return dep;
      }).toList();

      final depsRaw = await Future.wait(depFutures);
      final deps = depsRaw.whereType<String>().toSet();

      if (mounted) {
        setState(() {
          _allowedDeptos = deps;
          _loadingDeptos = false;

          // ✅ importantísimo: solo cuando cambian deptos
          _ubicStream = null;
          _ubicStreamKey = '';
        });

        if (_selectedUbic != null &&
            !_allowedDeptos
                .map(_norm)
                .contains(_norm(_selectedUbic!.departamento))) {
          _selectedUbic = null;
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingDeptos = false);
    }
  }

  Future<void> _payNow() async {
    if (_uid.isEmpty) return;
    if (_items.isEmpty) return;

    if (_selectedUbic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una ubicación para la entrega.'),
        ),
      );
      return;
    }

    if (_allowedDeptos.isNotEmpty &&
        !_allowedDeptos
            .map(_norm)
            .contains(_norm(_selectedUbic!.departamento))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La ubicación debe ser del mismo departamento del almacén.',
          ),
        ),
      );
      return;
    }

    setState(() => _paying = true);

    try {
      final pedidoId = await _store.checkoutToPedidos(
        ubicacion: _selectedUbic!,
      );

      if (!mounted) return;

      if (pedidoId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo crear el pedido.')),
        );
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pedido creado ✅')));

      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _goToPaymentPage() async {
    if (_uid.isEmpty) return;
    if (_items.isEmpty) return;

    if (_selectedUbic == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una ubicación para la entrega.'),
        ),
      );
      return;
    }

    if (_allowedDeptos.isNotEmpty &&
        !_allowedDeptos
            .map(_norm)
            .contains(_norm(_selectedUbic!.departamento))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La ubicación debe ser del mismo departamento del almacén.',
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MetodoPagoPage(
          ubicacion: _selectedUbic!,
          subtotal: _subtotal,
          shipping: _shipping,
          total: _total,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Palette.button;
    final ink = Palette.ink;

    return Scaffold(
      backgroundColor: Palette.fieldBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back_rounded, color: ink),
                  ),
                  Expanded(
                    child: Text(
                      'Tu Carrito',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _items.isEmpty ? null : _store.clear,
                    child: Text(
                      'Vaciar',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
                child: Column(
                  children: [
                    ...List.generate(_items.length, (i) {
                      final item = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _CartCard(
                          item: item,
                          primary: primary,
                          isUpdating: _store.isUpdating(item.id),
                          onRemove: () => _store.remove(item.id),
                          onMinus: () => _store.decQty(item.id),
                          onPlus: () => _store.incQty(item.id),
                          onSetQty: (v) => _store.setQty(item.id, v),
                        ),
                      );
                    }),

                    if (_items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 30),
                        child: Column(
                          children: [
                            Icon(
                              Icons.shopping_cart_outlined,
                              size: 52,
                              color: ink.withOpacity(0.35),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Tu carrito está vacío',
                              style: TextStyle(
                                color: ink.withOpacity(0.65),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    if (_items.isNotEmpty) ...[
                      if (_loadingDeptos)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Verificando departamento del almacén...',
                                  style: TextStyle(
                                    color: ink.withOpacity(0.65),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_allowedDeptos.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Ubicaciones disponibles en: ${_allowedDeptos.join(", ")}',
                              style: TextStyle(
                                color: ink.withOpacity(0.55),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),

                      _UbicacionDropdown(
                        stream: _ubicStreamFiltered(),
                        ink: ink,
                        primary: primary,
                        selected: _selectedUbic,
                        onChanged: (u) => setState(() => _selectedUbic = u),
                        allowedDeptos: _allowedDeptos,
                      ),

                      const SizedBox(height: 16),

                      _SummaryRow(
                        left: 'Subtotal',
                        right: 'Bs. ${_subtotal.toStringAsFixed(2)}',
                        rightColor: ink,
                      ),
                      const SizedBox(height: 10),
                      _SummaryRow(
                        left: 'Envío',
                        right: 'Gratis',
                        rightColor: primary,
                      ),

                      const SizedBox(height: 18),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Total a pagar',
                          style: TextStyle(
                            color: ink.withOpacity(0.55),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Bs. ${_total.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 36,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              child: SizedBox(
                height: 58,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: (_items.isEmpty || _paying || _loadingDeptos)
                      ? null
                      : _goToPaymentPage,
                  child: _paying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Hacer pedido',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                            ),
                          ],
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

/* ---------------- Widgets ---------------- */

class _UbicacionDropdown extends StatelessWidget {
  const _UbicacionDropdown({
    required this.stream,
    required this.ink,
    required this.primary,
    required this.selected,
    required this.onChanged,
    required this.allowedDeptos,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final Color ink;
  final Color primary;
  final UbicacionSeleccionada? selected;
  final ValueChanged<UbicacionSeleccionada?> onChanged;
  final Set<String> allowedDeptos;

  String _norm(String s) => s.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _box(
            ink: ink,
            child: Row(
              children: const [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Text('Cargando ubicaciones...'),
              ],
            ),
          );
        }

        var docs = snap.data?.docs ?? [];

        if (allowedDeptos.isNotEmpty) {
          final allowedNorm = allowedDeptos.map(_norm).toSet();
          docs = docs.where((d) {
            final dep = (d.data()['departamento'] ?? '').toString();
            return allowedNorm.contains(_norm(dep));
          }).toList();
        }

        if (docs.isEmpty) {
          return _box(
            ink: ink,
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: ink.withOpacity(0.45)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No hay ubicaciones para el departamento del almacén.',
                    style: TextStyle(
                      color: ink.withOpacity(0.70),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final options = docs.map((d) {
          final data = d.data();
          final nombre = (data['nombre'] ?? 'Ubicación').toString();
          final direccion = (data['direccion'] ?? data['address'] ?? '')
              .toString();
          final departamento = (data['departamento'] ?? '').toString().trim();

          final latRaw = data['lat'] ?? data['latitud'];
          final lngRaw = data['lng'] ?? data['longitud'];

          final lat = (latRaw is num)
              ? latRaw.toDouble()
              : double.tryParse(latRaw?.toString() ?? '') ?? 0.0;
          final lng = (lngRaw is num)
              ? lngRaw.toDouble()
              : double.tryParse(lngRaw?.toString() ?? '') ?? 0.0;

          final dirFinal = direccion.isNotEmpty
              ? direccion
              : 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';

          return UbicacionSeleccionada(
            id: d.id,
            nombre: nombre,
            direccion: dirFinal,
            departamento: departamento,
            lat: lat,
            lng: lng,
          );
        }).toList();

        final Map<String, List<UbicacionSeleccionada>> grouped = {};
        for (final u in options) {
          final key = u.departamento.isEmpty
              ? 'Sin departamento'
              : u.departamento;
          grouped.putIfAbsent(key, () => []).add(u);
        }

        final depts = grouped.keys.toList()
          ..sort((a, b) {
            if (a == 'Sin departamento') return 1;
            if (b == 'Sin departamento') return -1;
            return a.toLowerCase().compareTo(b.toLowerCase());
          });

        for (final k in depts) {
          grouped[k]!.sort(
            (a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()),
          );
        }

        final items = <DropdownMenuItem<UbicacionSeleccionada>>[];
        final selectedWidgets = <Widget>[];

        for (final dept in depts) {
          items.add(
            DropdownMenuItem<UbicacionSeleccionada>(
              enabled: false,
              value: null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  dept,
                  style: TextStyle(
                    color: ink.withOpacity(0.55),
                    fontWeight: FontWeight.w900,
                    fontSize: 12.4,
                  ),
                ),
              ),
            ),
          );
          selectedWidgets.add(const SizedBox.shrink());

          for (final u in grouped[dept]!) {
            items.add(
              DropdownMenuItem<UbicacionSeleccionada>(
                value: u,
                child: Text(
                  u.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.6,
                  ),
                ),
              ),
            );

            selectedWidgets.add(
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  u.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.8,
                  ),
                ),
              ),
            );
          }
        }

        UbicacionSeleccionada? current = selected;
        if (current == null || !options.any((o) => o.id == current!.id)) {
          current = options.first;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onChanged(current),
          );
        } else {
          current = options.firstWhere((o) => o.id == current!.id);
        }

        return _box(
          ink: ink,
          child: Row(
            children: [
              Icon(Icons.place_rounded, color: primary),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<UbicacionSeleccionada>(
                    value: current,
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ink.withOpacity(0.60),
                    ),
                    items: items,
                    selectedItemBuilder: (_) => selectedWidgets,
                    onChanged: (v) {
                      if (v == null) return;
                      onChanged(v);
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _box({required Widget child, required Color ink}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Palette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ink.withOpacity(0.06)),
      ),
      child: child,
    );
  }
}

/* ---------------- CART CARD (DESCUENTO ABAJO) ---------------- */

class _CartCard extends StatelessWidget {
  const _CartCard({
    required this.item,
    required this.primary,
    required this.isUpdating,
    required this.onRemove,
    required this.onMinus,
    required this.onPlus,
    required this.onSetQty,
  });

  final CartItem item;
  final Color primary;
  final bool isUpdating;
  final VoidCallback onRemove;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onSetQty;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _descuentoStream(String id) {
    return FirebaseFirestore.instance
        .collection('productos')
        .doc(id)
        .collection('descuentos')
        .doc('activo')
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _productoOnce(String id) {
    return FirebaseFirestore.instance.collection('productos').doc(id).get();
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _productoOnce(item.id),
      builder: (context, prodSnap) {
        final prod = prodSnap.data?.data();

        // ✅ base price desde productos; fallback al precio guardado en carrito
        final basePrice = _toDouble(prod?['price']);
        final base = basePrice > 0 ? basePrice : item.price;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _descuentoStream(item.id),
          builder: (context, dsSnap) {
            final d = dsSnap.data?.data();

            final bool activo = (d?['activo'] == true);
            final String tipo = (d?['tipo'] ?? 'PORCENTAJE').toString().trim();
            final double valor = _toDouble(d?['valor']);

            final bool hasDescuento = activo && valor > 0;

            double finalPrice = base;
            String badge = '';
            String line = '';

            if (hasDescuento) {
              if (tipo == 'PORCENTAJE') {
                final pct = valor.clamp(0.0, 100.0);
                finalPrice = base * (1 - (pct / 100.0));
                finalPrice = math.max(0.0, finalPrice);

                final pctTxt = (pct % 1 == 0)
                    ? pct.toStringAsFixed(0)
                    : pct.toStringAsFixed(1);

                badge = '-$pctTxt%';
                line = ' $badge';
              } else {
                finalPrice = math.max(0.0, base - valor);

                final vTxt = (valor % 1 == 0)
                    ? valor.toStringAsFixed(0)
                    : valor.toStringAsFixed(2);

                badge = '-Bs $vTxt';
                line = ' $badge';
              }
            }

            // ✅ precio que se muestra (si hay descuento, muestra precio final)
            final priceToShow = hasDescuento ? finalPrice : item.price;

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Palette.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ink.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          item.imageUrl,
                          height: 62,
                          width: 62,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 62,
                            width: 62,
                            color: ink.withOpacity(0.06),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: ink.withOpacity(0.45),
                            ),
                          ),
                        ),
                      ),
                      if (hasDescuento)
                        Positioned(
                          left: 4,
                          top: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.14),
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
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: onRemove,
                              child: SizedBox(
                                height: 38,
                                width: 38,
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 22,
                                  color: ink.withOpacity(0.45),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Bs. ${priceToShow.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: hasDescuento
                                              ? Colors.red
                                              : primary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child: isUpdating
                                            ? SizedBox(
                                                key: const ValueKey('load'),
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: primary,
                                                ),
                                              )
                                            : const SizedBox(
                                                key: ValueKey('none'),
                                              ),
                                      ),
                                    ],
                                  ),
                                  if (hasDescuento) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      'Bs. ${base.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        color: ink.withOpacity(0.45),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12.2,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      line,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.red.withOpacity(0.95),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12.0,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            _QtyPill(
                              qty: item.qty,
                              primary: primary,
                              onMinus: onMinus,
                              onPlus: onPlus,
                              onSetQty: onSetQty,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/* ---------------- QTY PILL (EDITABLE) ---------------- */

class _QtyPill extends StatefulWidget {
  const _QtyPill({
    required this.qty,
    required this.primary,
    required this.onMinus,
    required this.onPlus,
    required this.onSetQty,
  });

  final int qty;
  final Color primary;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<int> onSetQty;

  @override
  State<_QtyPill> createState() => _QtyPillState();
}

class _QtyPillState extends State<_QtyPill> {
  late final TextEditingController _c;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.qty.toString());
  }

  @override
  void didUpdateWidget(covariant _QtyPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.qty != widget.qty && _c.text != widget.qty.toString()) {
      _c.text = widget.qty.toString();
    }
  }

  void _commit() {
    final raw = _c.text.trim();
    final v = int.tryParse(raw) ?? widget.qty;
    final fixed = v <= 1 ? 1 : v;
    if (fixed.toString() != _c.text) _c.text = fixed.toString();
    widget.onSetQty(fixed);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 138),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: widget.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.primary.withOpacity(0.16)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _QtyBtn(
              icon: Icons.remove_rounded,
              onTap: widget.onMinus,
              color: widget.primary,
            ),
            SizedBox(
              width: 34,
              child: TextField(
                controller: _c,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 3,
                decoration: const InputDecoration(
                  counterText: '',
                  isDense: true,
                  border: InputBorder.none,
                ),
                style: TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
                onSubmitted: (_) => _commit(),
                onEditingComplete: _commit,
                onTapOutside: (_) => _commit(),
              ),
            ),
            _QtyBtn(
              icon: Icons.add_rounded,
              onTap: widget.onPlus,
              color: widget.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn({required this.icon, required this.onTap, required this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 34,
        width: 34,
        alignment: Alignment.center,
        child: Icon(icon, size: 24, color: color),
      ),
    );
  }
}

/* ---------------- SUMMARY ---------------- */

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.left,
    required this.right,
    required this.rightColor,
  });

  final String left;
  final String right;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    final ink = Palette.ink;

    return Row(
      children: [
        Text(
          left,
          style: TextStyle(
            color: ink.withOpacity(0.55),
            fontWeight: FontWeight.w800,
          ),
        ),
        const Spacer(),
        Text(
          right,
          style: TextStyle(color: rightColor, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}