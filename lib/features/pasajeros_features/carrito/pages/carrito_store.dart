import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist_store.dart';

/// Normaliza un departamento para compararlo: sin espacios extra, en
/// minusculas y sin tildes, porque los nombres vienen de Firestore y pueden
/// haberse cargado con o sin acento ("Potosí" vs "Potosi").
String _normDepto(String s) {
  const acentos = <String, String>{
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };

  var out = s.trim().toLowerCase();
  acentos.forEach((con, sin) => out = out.replaceAll(con, sin));

  return out.replaceAll(RegExp(r'\s+'), ' ');
}

/// Conflicto detectado al intentar mezclar departamentos en el carrito.
class CartDeptoConflicto {
  /// Departamento que ya tiene el carrito.
  final String deptoCarrito;

  /// Departamento del producto que se quiso agregar.
  final String deptoProducto;

  const CartDeptoConflicto({
    required this.deptoCarrito,
    required this.deptoProducto,
  });
}

/// Resultado de agregar un producto al carrito.
class AddToCartResult {
  /// null si se agrego correctamente.
  final CartDeptoConflicto? conflicto;

  const AddToCartResult._(this.conflicto);

  const AddToCartResult.ok() : this._(null);
  const AddToCartResult.conflicto(CartDeptoConflicto c) : this._(c);

  bool get agregado => conflicto == null;
}

class CartStore extends ChangeNotifier {
  CartStore._();
  static final CartStore I = CartStore._();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  final List<CartItem> _items = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  StreamSubscription<User?>? _authSub;

  final Map<String, bool> _updating = {};
  final Map<String, Timer> _updatingTimers = {};

  final Map<String, int> _stockCache = {};

  // ✅ Un pedido solo puede salir de un departamento: no se pueden mezclar
  // productos de almacenes de Cochabamba y Santa Cruz en el mismo carrito.
  // productoId -> departamento del almacen ('' si no se pudo resolver)
  final Map<String, String> _deptoProductoCache = {};
  // almacenId -> departamento ('' si no se pudo resolver)
  final Map<String, String> _deptoAlmacenCache = {};

  Set<String> _cartDeptos = {};
  String _deptosKey = '';

  /// true cuando el stream del carrito ya entrego al menos un snapshot.
  bool _cartCargado = false;

  String? _toastMessage;
  String? consumeToast() {
    final t = _toastMessage;
    _toastMessage = null;
    return t;
  }

  List<CartItem> get items => _items;

  /// Departamentos (de los almacenes) presentes en el carrito.
  Set<String> get cartDeptos => _cartDeptos;

  /// Departamento unico del carrito, o null si esta vacio / no se pudo resolver.
  String? get cartDepto => _cartDeptos.length == 1 ? _cartDeptos.first : null;

  /// true si el carrito quedo con productos de mas de un departamento.
  /// No deberia pasar, pero si pasa (datos viejos) hay que bloquear el checkout.
  bool get tieneDeptosMezclados => _cartDeptos.length > 1;

  bool isUpdating(String productId) => _updating[productId] == true;

  void _setToast(String msg) {
    _toastMessage = msg;
    notifyListeners();
  }

  void _setUpdating(String productId, bool v) {
    _updating[productId] = v;
    notifyListeners();
  }

  void _setUpdatingWithMinTime(String productId, bool v, {int minMs = 220}) {
    _updatingTimers[productId]?.cancel();
    _setUpdating(productId, v);

    if (v == false) return;

    _updatingTimers[productId] = Timer(Duration(milliseconds: minMs), () {
      if (_updating[productId] == true) {
        _updating[productId] = false;
        notifyListeners();
      }
    });
  }

  void init() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((_) => bind());
    bind();
  }

  void bind() {
    _sub?.cancel();
    _cartCargado = false;

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _items.clear();
      _stockCache.clear();
      _cartDeptos = {};
      _deptosKey = '';
      _cartCargado = false;
      notifyListeners();
      return;
    }

    _sub = _fire
        .collection('usuarios')
        .doc(uid)
        .collection('carrito')
        .snapshots()
        .listen((snap) {
      _items
        ..clear()
        ..addAll(
          snap.docs.map((d) {
            final data = d.data();

            final name = (data['name'] ?? '').toString();
            final price = (data['price'] is num)
                ? (data['price'] as num).toDouble()
                : double.tryParse((data['price'] ?? '0').toString()) ?? 0.0;

            final qty = (data['qty'] is num)
                ? (data['qty'] as num).toInt()
                : int.tryParse((data['qty'] ?? '1').toString()) ?? 1;

            final imageUrl = (data['imageUrl'] ?? '').toString();

            return CartItem(
              id: d.id,
              name: name,
              price: price,
              qty: qty <= 0 ? 1 : qty,
              imageUrl: imageUrl,
            );
          }),
        );

      for (final it in _items) {
        _prefetchStock(it.id);
      }

      _cartCargado = true;
      _refreshCartDeptos();

      notifyListeners();
    });
  }

  int _findIndex(String productId) => _items.indexWhere((e) => e.id == productId);

  DocumentReference<Map<String, dynamic>> _cartRef(String uid, String productId) {
    return _fire.collection('usuarios').doc(uid).collection('carrito').doc(productId);
  }

  Future<void> _prefetchStock(String productId) async {
    if (_stockCache.containsKey(productId)) return;
    final s = await _fetchStock(productId);
    _stockCache[productId] = s;
  }

  Future<int> _fetchStock(String productId) async {
    try {
      final doc = await _fire.collection('productos').doc(productId).get();
      if (!doc.exists) return 0;
      final data = doc.data() as Map<String, dynamic>;
      final raw = data['stock'];

      if (raw is num) return raw.toInt();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> _getStock(String productId) async {
    if (_stockCache.containsKey(productId)) return _stockCache[productId] ?? 0;
    final s = await _fetchStock(productId);
    _stockCache[productId] = s;
    return s;
  }

  String _stockMsg(int stock) {
    if (stock <= 0) return 'Uy 😕 por ahora no hay stock disponible de este producto.';
    return 'Solo tenemos $stock unidad${stock == 1 ? "" : "es"} disponible${stock == 1 ? "" : "s"} por ahora 🙂';
  }

  // ===========================================================
  // Departamento del carrito
  //
  // Un producto pertenece a un almacen (productos/{id}.almacenId) y cada
  // almacen vive en un departamento (almacenes/{id}.departamento). Como el
  // pedido se despacha y entrega dentro de un solo departamento, el carrito
  // no puede mezclar productos de almacenes de departamentos distintos.
  // ===========================================================

  Future<String> _fetchDeptoDeAlmacen(String almacenId) async {
    final cached = _deptoAlmacenCache[almacenId];
    if (cached != null) return cached;

    try {
      final doc = await _fire.collection('almacenes').doc(almacenId).get();
      final dep = (doc.data()?['departamento'] ?? '').toString().trim();
      _deptoAlmacenCache[almacenId] = dep;
      return dep;
    } catch (_) {
      return '';
    }
  }

  Future<String> _fetchDeptoDeProducto(String productId) async {
    try {
      final doc = await _fire.collection('productos').doc(productId).get();
      if (!doc.exists) return '';

      final almacenId = (doc.data()?['almacenId'] ?? '').toString().trim();
      if (almacenId.isEmpty) return '';

      return await _fetchDeptoDeAlmacen(almacenId);
    } catch (_) {
      return '';
    }
  }

  /// Departamento del almacen de un producto ('' si no se puede resolver).
  Future<String> getDeptoDeProducto(String productId) async {
    final cached = _deptoProductoCache[productId];
    if (cached != null) return cached;

    final dep = await _fetchDeptoDeProducto(productId);
    _deptoProductoCache[productId] = dep;
    return dep;
  }

  /// Deduplica por nombre normalizado (no por texto exacto) para que
  /// "Potosi" y "Potosí" no cuenten como dos departamentos distintos.
  Set<String> _dedupeDeptos(Iterable<String> deps) {
    final porClave = <String, String>{};

    for (final dep in deps) {
      final limpio = dep.trim();
      if (limpio.isEmpty) continue;
      porClave.putIfAbsent(_normDepto(limpio), () => limpio);
    }

    return porClave.values.toSet();
  }

  /// Recalcula los departamentos presentes en el carrito.
  /// Solo hace trabajo si cambio el conjunto de productos (no al cambiar qty).
  Future<void> _refreshCartDeptos({bool force = false}) async {
    final ids = _items.map((e) => e.id).toSet().toList()..sort();
    final key = ids.join('|');

    if (!force && key == _deptosKey) return;
    _deptosKey = key;

    if (ids.isEmpty) {
      if (_cartDeptos.isNotEmpty) {
        _cartDeptos = {};
        notifyListeners();
      }
      return;
    }

    final deps = await Future.wait(ids.map(getDeptoDeProducto));
    final nuevos = _dedupeDeptos(deps);

    // El set de productos pudo cambiar mientras resolviamos.
    final idsAhora = _items.map((e) => e.id).toSet().toList()..sort();
    if (idsAhora.join('|') != key) return;

    if (!setEquals(nuevos, _cartDeptos)) {
      _cartDeptos = nuevos;
      notifyListeners();
    }
  }

  /// Fuerza un recalculo (util al entrar al carrito).
  Future<void> refreshCartDeptos() => _refreshCartDeptos(force: true);

  /// Lee el carrito directo de Firestore y resuelve sus departamentos.
  /// Solo se usa cuando el listener todavia no entrego datos.
  Future<Set<String>> _deptosDelCarritoRemoto() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return {};

    try {
      final snap = await _fire
          .collection('usuarios')
          .doc(uid)
          .collection('carrito')
          .get();

      if (snap.docs.isEmpty) return {};

      final deps = await Future.wait(
        snap.docs.map((d) => getDeptoDeProducto(d.id)),
      );

      return _dedupeDeptos(deps);
    } catch (_) {
      return {};
    }
  }

  /// Revisa si agregar [productId] mezclaria departamentos.
  /// Devuelve null si no hay conflicto.
  Future<CartDeptoConflicto?> verificarDepartamento(String productId) async {
    final deptoProducto = await getDeptoDeProducto(productId);
    if (deptoProducto.isEmpty) return null;

    // Si el stream del carrito todavia no entrego su primer snapshot, _items
    // esta vacio aunque el carrito tenga cosas. Leemos directo para no dejar
    // pasar una mezcla solo por llegar antes que el listener.
    final Set<String> actuales;
    if (!_cartCargado) {
      actuales = await _deptosDelCarritoRemoto();
    } else {
      if (_items.isEmpty) return null;
      await _refreshCartDeptos(force: true);
      actuales = _cartDeptos;
    }

    if (actuales.isEmpty) return null;

    final coincide =
        actuales.any((d) => _normDepto(d) == _normDepto(deptoProducto));
    if (coincide) return null;

    return CartDeptoConflicto(
      deptoCarrito: actuales.first,
      deptoProducto: deptoProducto,
    );
  }

  Future<CartCheckoutPreview?> buildCheckoutPreview({
    double costoEnvio = 0.0,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final carritoSnap =
        await _fire.collection('usuarios').doc(uid).collection('carrito').get();

    if (carritoSnap.docs.isEmpty) return null;

    final previewItems = <CartCheckoutItemPreview>[];
    double subtotal = 0.0;

    for (final d in carritoSnap.docs) {
      final data = d.data();

      final name = (data['name'] ?? '').toString();
      final price = (data['price'] is num)
          ? (data['price'] as num).toDouble()
          : double.tryParse((data['price'] ?? '0').toString()) ?? 0.0;

      final qty = (data['qty'] is num)
          ? (data['qty'] as num).toInt()
          : int.tryParse((data['qty'] ?? '1').toString()) ?? 1;

      final imageUrl = (data['imageUrl'] ?? '').toString();
      final fixedQty = qty <= 0 ? 1 : qty;
      final subtotalItem = price * fixedQty;

      subtotal += subtotalItem;

      previewItems.add(
        CartCheckoutItemPreview(
          productId: d.id,
          name: name,
          price: price,
          qty: fixedQty,
          imageUrl: imageUrl,
          subtotal: subtotalItem,
        ),
      );
    }

    return CartCheckoutPreview(
      items: previewItems,
      subtotal: subtotal,
      costoEnvio: costoEnvio,
      total: subtotal + costoEnvio,
      conteoItems: previewItems.length,
    );
  }

  /// Agrega un producto al carrito.
  ///
  /// Si el producto pertenece a un almacen de otro departamento devuelve
  /// [AddToCartResult.conflicto] SIN tocar el carrito, para que la UI pregunte
  /// al cliente. Si confirma, se vuelve a llamar con [vaciarCarrito] en true.
  Future<AddToCartResult> addProductWithQty({
    required String productId,
    required String name,
    required double price,
    required String imageUrl,
    required int qty,
    bool vaciarCarrito = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const AddToCartResult.ok();

    if (vaciarCarrito) {
      await clear();
    } else {
      final conflicto = await verificarDepartamento(productId);
      if (conflicto != null) return AddToCartResult.conflicto(conflicto);
    }

    final safeQty = qty <= 0 ? 1 : qty;

    final stock = await _getStock(productId);
    if (stock > 0 && safeQty > stock) {
      _setToast(_stockMsg(stock));
    }

    final ref = _cartRef(uid, productId);

    await _fire.runTransaction((tx) async {
      final snap = await tx.get(ref);

      int finalQtyToSet = safeQty;

      if (stock > 0) {
        finalQtyToSet = finalQtyToSet.clamp(1, stock);
      } else {
        finalQtyToSet = finalQtyToSet.clamp(1, 9999);
      }

      if (snap.exists) {
        final currentQty = ((snap.data()?['qty'] ?? 1) is num)
            ? (snap.data()?['qty'] as num).toInt()
            : int.tryParse((snap.data()?['qty'] ?? '1').toString()) ?? 1;

        int newQty = currentQty + finalQtyToSet;

        if (stock > 0 && newQty > stock) {
          newQty = stock;
          _setToast(_stockMsg(stock));
        }

        tx.update(ref, {
          'qty': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'name': name,
          'price': price,
          'qty': finalQtyToSet,
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    return const AddToCartResult.ok();
  }

  Future<AddToCartResult> addFromWishlist(
    WishItem item, {
    bool vaciarCarrito = false,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const AddToCartResult.ok();

    final stock = await _getStock(item.id);
    if (stock <= 0) {
      _setToast(_stockMsg(stock));
      return const AddToCartResult.ok();
    }

    if (vaciarCarrito) {
      await clear();
    } else {
      final conflicto = await verificarDepartamento(item.id);
      if (conflicto != null) return AddToCartResult.conflicto(conflicto);
    }

    // El producto se queda en favoritos: agregarlo al carrito no es "moverlo".
    final cartRef = _cartRef(uid, item.id);

    await _fire.runTransaction((tx) async {
      final snap = await tx.get(cartRef);

      if (snap.exists) {
        // Ya estaba en el carrito (se puede agregar varias veces desde
        // favoritos), asi que sumamos una unidad sin pasarnos del stock.
        final actual = ((snap.data()?['qty'] ?? 1) is num)
            ? (snap.data()?['qty'] as num).toInt()
            : int.tryParse((snap.data()?['qty'] ?? '1').toString()) ?? 1;

        if (actual >= stock) {
          _setToast(_stockMsg(stock));
          return;
        }

        tx.update(cartRef, {
          'qty': actual + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      tx.set(cartRef, {
        'name': item.name,
        'price': item.price,
        'qty': 1,
        'imageUrl': item.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return const AddToCartResult.ok();
  }

  Future<void> incQty(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final idx = _findIndex(productId);
    if (idx == -1) return;

    final current = _items[idx];
    final desired = current.qty + 1;

    final stock = await _getStock(productId);
    if (stock > 0 && desired > stock) {
      _setToast(_stockMsg(stock));
      return;
    }

    _items[idx] = current.copyWith(qty: desired);
    _setUpdatingWithMinTime(productId, true);
    notifyListeners();

    try {
      await _cartRef(uid, productId).update({'qty': FieldValue.increment(1)});
      _updating[productId] = false;
      notifyListeners();
    } catch (_) {
      final nowIdx = _findIndex(productId);
      if (nowIdx != -1) {
        final cur = _items[nowIdx];
        final back = (cur.qty - 1) <= 1 ? 1 : (cur.qty - 1);
        _items[nowIdx] = cur.copyWith(qty: back);
      }
      _updating[productId] = false;
      notifyListeners();
    }
  }

  Future<void> decQty(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final idx = _findIndex(productId);
    if (idx == -1) return;

    final current = _items[idx];
    if (current.qty <= 1) return;

    _items[idx] = current.copyWith(qty: current.qty - 1);
    _setUpdatingWithMinTime(productId, true);
    notifyListeners();

    try {
      await _cartRef(uid, productId).update({'qty': FieldValue.increment(-1)});
      _updating[productId] = false;
      notifyListeners();
    } catch (_) {
      final nowIdx = _findIndex(productId);
      if (nowIdx != -1) {
        final cur = _items[nowIdx];
        _items[nowIdx] = cur.copyWith(qty: cur.qty + 1);
      }
      _updating[productId] = false;
      notifyListeners();
    }
  }

  Future<void> setQty(String productId, int qty) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final idx = _findIndex(productId);
    if (idx == -1) return;

    int newQty = qty <= 1 ? 1 : qty;

    final stock = await _getStock(productId);
    if (stock > 0 && newQty > stock) {
      newQty = stock;
      _setToast(_stockMsg(stock));
      if (newQty <= 0) return;
    }

    final current = _items[idx];
    final oldQty = current.qty;
    _items[idx] = current.copyWith(qty: newQty);

    _setUpdatingWithMinTime(productId, true);
    notifyListeners();

    try {
      await _cartRef(uid, productId).set(
        {
          'qty': newQty,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      _updating[productId] = false;
      notifyListeners();
    } catch (_) {
      final nowIdx = _findIndex(productId);
      if (nowIdx != -1) {
        final cur = _items[nowIdx];
        _items[nowIdx] = cur.copyWith(qty: oldQty);
      }
      _updating[productId] = false;
      notifyListeners();
    }
  }

  Future<void> remove(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _fire.collection('usuarios').doc(uid).collection('carrito').doc(productId).delete();
  }

  Future<void> clear() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await _fire.collection('usuarios').doc(uid).collection('carrito').get();
    final batch = _fire.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  Future<String?> _subirComprobante({
    required String uid,
    required Uint8List bytes,
    String? fileName,
    String tipoPago = 'qr',
  }) async {
    final cleanName = (fileName == null || fileName.trim().isEmpty)
        ? 'comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg'
        : fileName.trim();

    final ext = _extensionFromName(cleanName);
    final finalName =
        'comp_${DateTime.now().millisecondsSinceEpoch}_${_gen6Digits()}.$ext';
    final path = 'pagos/comprobantes/$uid/$finalName';

    final ref = _storage.ref().child(path);

    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: _contentTypeFromExt(ext),
        customMetadata: {
          'uid': uid,
          'tipo_pago': tipoPago,
          'nombre_original': cleanName,
        },
      ),
    );

    return await ref.getDownloadURL();
  }

  String _extensionFromName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.jpg')) return 'jpg';
    if (lower.endsWith('.heic')) return 'heic';
    return 'jpg';
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpeg':
      case 'jpg':
        return 'image/jpeg';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<String?> checkoutToPedidos({
    required UbicacionSeleccionada ubicacion,
    String tipoPago = 'efectivo',
    String estadoPago = 'pendiente',
    Uint8List? comprobanteBytes,
    String? comprobanteUrl,
    String? comprobanteNombre,
    String? qrImageUrl,
    String? qrDescargaUrl,
    String? observacionPago,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    String? comprobanteUrlFinal = comprobanteUrl;

    if (comprobanteBytes != null && comprobanteBytes.isNotEmpty) {
      comprobanteUrlFinal = await _subirComprobante(
        uid: uid,
        bytes: comprobanteBytes,
        fileName: comprobanteNombre,
        tipoPago: tipoPago,
      );
    }

    // El stock se valida y se descuenta del lado del servidor, dentro de
    // una transacción de Firestore junto con la creación del pedido, para
    // que dos compras simultáneas de la última unidad no puedan pasar ambas.
    try {
      final result = await _functions.httpsCallable('crearPedido').call({
        'ubicacion': ubicacion.toJson(),
        'tipoPago': tipoPago,
        'estadoPago': estadoPago,
        'comprobanteUrl': comprobanteUrlFinal,
        'comprobanteNombre': comprobanteNombre,
        'qrImageUrl': qrImageUrl,
        'qrDescargaUrl': qrDescargaUrl,
        'observacionPago': observacionPago,
      });

      return result.data['pedidoId'] as String?;
    } on FirebaseFunctionsException catch (e) {
      throw Exception(e.message ?? 'No se pudo crear el pedido.');
    }
  }

  String _gen6Digits() {
    final r = Random().nextInt(1000000);
    return r.toString().padLeft(6, '0');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _authSub?.cancel();
    for (final t in _updatingTimers.values) {
      t.cancel();
    }
    _updatingTimers.clear();
    super.dispose();
  }
}

class CartItem {
  final String id;
  final String name;
  final double price;
  final int qty;
  final String imageUrl;

  const CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.qty,
    required this.imageUrl,
  });

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? qty,
    String? imageUrl,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      qty: qty ?? this.qty,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class UbicacionSeleccionada {
  final String id;
  final String nombre;
  final String direccion;
  final String departamento;
  final double lat;
  final double lng;

  const UbicacionSeleccionada({
    required this.id,
    required this.nombre,
    required this.direccion,
    required this.departamento,
    required this.lat,
    required this.lng,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nombre': nombre,
        'direccion': direccion,
        'departamento': departamento,
        'lat': lat,
        'lng': lng,
      };
}

class CartCheckoutItemPreview {
  final String productId;
  final String name;
  final double price;
  final int qty;
  final String imageUrl;
  final double subtotal;

  const CartCheckoutItemPreview({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    required this.imageUrl,
    required this.subtotal,
  });
}

class CartCheckoutPreview {
  final List<CartCheckoutItemPreview> items;
  final double subtotal;
  final double costoEnvio;
  final double total;
  final int conteoItems;

  const CartCheckoutPreview({
    required this.items,
    required this.subtotal,
    required this.costoEnvio,
    required this.total,
    required this.conteoItems,
  });
}