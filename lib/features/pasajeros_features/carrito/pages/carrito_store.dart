import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'package:quimisol_movil/features/pasajeros_features/wishlist/pages/wishlist_store.dart';

class CartStore extends ChangeNotifier {
  CartStore._();
  static final CartStore I = CartStore._();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;

  final List<CartItem> _items = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  StreamSubscription<User?>? _authSub;

  final Map<String, bool> _updating = {};
  final Map<String, Timer> _updatingTimers = {};

  final Map<String, int> _stockCache = {};

  String? _toastMessage;
  String? consumeToast() {
    final t = _toastMessage;
    _toastMessage = null;
    return t;
  }

  List<CartItem> get items => _items;

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

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _items.clear();
      _stockCache.clear();
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
  }

  Future<void> addFromWishlist(WishItem item) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final stock = await _getStock(item.id);
    if (stock <= 0) {
      _setToast(_stockMsg(stock));
      return;
    }

    final cartRef = _fire.collection('usuarios').doc(uid).collection('carrito').doc(item.id);
    final wishRef = _fire.collection('usuarios').doc(uid).collection('wishlist').doc(item.id);

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

    final carritoSnap = await _fire.collection('usuarios').doc(uid).collection('carrito').get();
    if (carritoSnap.docs.isEmpty) return null;

    String? comprobanteUrlFinal = comprobanteUrl;

    if (comprobanteBytes != null && comprobanteBytes.isNotEmpty) {
      comprobanteUrlFinal = await _subirComprobante(
        uid: uid,
        bytes: comprobanteBytes,
        fileName: comprobanteNombre,
        tipoPago: tipoPago,
      );
    }

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
        'subtotal': price * fixedQty,
      });
    }

    final code = _gen6Digits();

    final pedidoDoc = _fire.collection('pedidos').doc();
    final userIndexDoc = _fire
        .collection('usuarios')
        .doc(uid)
        .collection('pedidos')
        .doc(pedidoDoc.id);

    const double costoEnvio = 0.0;
    final totalFinal = totalProductos + costoEnvio;

    final payload = <String, dynamic>{
      'codigo': code,
      'estado': 'pendiente',
      'tipo_pago': tipoPago,
      'estado_pago': estadoPago,
      'departamento': ubicacion.departamento,
      'direccion': ubicacion.direccion,
      'total': totalFinal,
      'subtotal': totalProductos,
      'costo_envio': costoEnvio,
      'fecha_entrega': null,
      'conteoItems': items.length,
      'items': items,
      'ubicacion': ubicacion.toJson(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'comprobante_url': comprobanteUrlFinal,
      'comprobante_nombre': comprobanteNombre,
      'qr_image_url': qrImageUrl,
      'qr_descarga_url': qrDescargaUrl,
      'observacion_pago': observacionPago,
    };

    final indexPayload = <String, dynamic>{
      'pedidoId': pedidoDoc.id,
      'codigo': code,
      'estado': 'pendiente',
      'tipo_pago': tipoPago,
      'estado_pago': estadoPago,
      'departamento': ubicacion.departamento,
      'direccion': ubicacion.direccion,
      'total': totalFinal,
      'subtotal': totalProductos,
      'costo_envio': costoEnvio,
      'fecha_entrega': null,
      'conteoItems': items.length,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'uid': uid,
      'comprobante_url': comprobanteUrlFinal,
      'comprobante_nombre': comprobanteNombre,
      'qr_image_url': qrImageUrl,
      'observacion_pago': observacionPago,
    };

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