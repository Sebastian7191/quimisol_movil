import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist_store.dart';

class CartStore extends ChangeNotifier {
  CartStore._();
  static final CartStore I = CartStore._();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final List<CartItem> _items = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  // ✅ re-bindeo automático al restaurar sesión (app restart)
  StreamSubscription<User?>? _authSub;

  // ✅ estado por item (para mostrar loader en UI)
  final Map<String, bool> _updating = {};
  final Map<String, Timer> _updatingTimers = {};

  List<CartItem> get items => _items;

  bool isUpdating(String productId) => _updating[productId] == true;

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

  /* ---------------- INIT / BIND ---------------- */

  void init() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((_) => bind());
    bind();
  }

  /// ✅ engancha listener a usuarios/{uid}/carrito
  void bind() {
    _sub?.cancel();

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _items.clear();
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

      notifyListeners();
    });
  }

  /* ---------------- HELPERS ---------------- */

  int _findIndex(String productId) => _items.indexWhere((e) => e.id == productId);

  DocumentReference<Map<String, dynamic>> _cartRef(String uid, String productId) {
    return _fire.collection('usuarios').doc(uid).collection('carrito').doc(productId);
  }

  /* ---------------- ACCIONES ---------------- */

  /// ✅ NUEVO: Agregar producto al carrito con cantidad (qty)
  /// - Si el producto ya existe: incrementa qty
  /// - Si no existe: crea doc con qty
  Future<void> addProductWithQty({
    required String productId,
    required String name,
    required double price,
    required String imageUrl,
    required int qty,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final safeQty = qty <= 0 ? 1 : qty;

    final ref = _cartRef(uid, productId);

    // ✅ usamos transaction para sumar si ya existe
    await _fire.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        tx.update(ref, {
          'qty': FieldValue.increment(safeQty),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.set(ref, {
          'name': name,
          'price': price,
          'qty': safeQty,
          'imageUrl': imageUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  /// ✅ Agregar desde wishlist (y eliminar de wishlist)
  Future<void> addFromWishlist(WishItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final cartRef = _fire
        .collection('usuarios')
        .doc(uid)
        .collection('carrito')
        .doc(item.id);

    final wishRef = _fire
        .collection('usuarios')
        .doc(uid)
        .collection('wishlist')
        .doc(item.id);

    await _fire.runTransaction((tx) async {
      tx.set(cartRef, {
        'name': item.name,
        'price': item.price,
        'qty': 1,
        'imageUrl': item.imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.delete(wishRef);
    });
  }

  // -----------------------------
  // ✅ OPTIMISTIC QTY (INSTANTE)
  // -----------------------------

  Future<void> incQty(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final idx = _findIndex(productId);
    if (idx == -1) return;

    final current = _items[idx];
    _items[idx] = current.copyWith(qty: current.qty + 1);
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

  Future<void> remove(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _fire
        .collection('usuarios')
        .doc(uid)
        .collection('carrito')
        .doc(productId)
        .delete();
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

  /* ---------------- CHECKOUT -> PEDIDOS (ROOT) ---------------- */

  /// ✅ Crea pedido en /pedidos/{pedidoId}
  /// ✅ crea índice en /usuarios/{uid}/pedidos/{pedidoId}
  /// ✅ borra carrito
  ///
  /// ✅ NUEVO:
  /// - también guarda 'departamento' (y 'direccion') a nivel raíz del pedido e índice
  ///   para filtros rápidos.
  Future<String?> checkoutToPedidos({
    required UbicacionSeleccionada ubicacion,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    // 1) leer carrito
    final carritoSnap = await _fire.collection('usuarios').doc(uid).collection('carrito').get();
    if (carritoSnap.docs.isEmpty) return null;

    // 2) construir items
    final items = <Map<String, dynamic>>[];
    double totalProductos = 0.0;

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
      totalProductos += price * fixedQty;

      items.add({
        'productId': d.id,
        'name': name,
        'price': price,
        'qty': fixedQty,
        'imageUrl': imageUrl,
      });
    }

    // 3) crear pedido (ROOT)
    final code = _gen6Digits();

    final pedidoDoc = _fire.collection('pedidos').doc(); // ✅ ROOT /pedidos
    final userIndexDoc = _fire
        .collection('usuarios')
        .doc(uid)
        .collection('pedidos')
        .doc(pedidoDoc.id); // ✅ índice (mismo id)

    const double costoEnvio = 0.0;
    final totalFinal = totalProductos + costoEnvio;

    final payload = <String, dynamic>{
      'codigo': code,
      'estado': 'pendiente',

      // ✅ para filtros rápidos
      'departamento': ubicacion.departamento,
      'direccion': ubicacion.direccion,

      'total': totalProductos, // productos
      'costo_envio': costoEnvio,
      'fecha_entrega': null,
      'conteoItems': items.length,
      'items': items,

      // ✅ snapshot completo
      'ubicacion': ubicacion.toJson(),

      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
    };

    final indexPayload = <String, dynamic>{
      'pedidoId': pedidoDoc.id,
      'codigo': code,
      'estado': 'pendiente',

      // ✅ para filtros rápidos también en el índice
      'departamento': ubicacion.departamento,
      'direccion': ubicacion.direccion,

      'total': totalFinal, // total final (productos + envío)
      'costo_envio': costoEnvio,
      'fecha_entrega': null,
      'conteoItems': items.length,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': uid,
    };

    // 4) batch
    final batch = _fire.batch();
    batch.set(pedidoDoc, payload);
    batch.set(userIndexDoc, indexPayload);

    for (final d in carritoSnap.docs) {
      batch.delete(d.reference);
    }

    await batch.commit();
    return pedidoDoc.id;
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

/* ---------------- MODEL ---------------- */

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

/// ✅ Para enviar la ubicación elegida al pedido (snapshot)
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
