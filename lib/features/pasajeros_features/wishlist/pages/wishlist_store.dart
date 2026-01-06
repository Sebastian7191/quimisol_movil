import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// 👇 Ajusta este import si tu ProductModel está en otra ruta
import 'package:quimisol_movil/features/pasajeros_features/homepage/pages/home_page_clientes.dart';

class WishlistStore extends ChangeNotifier {
  WishlistStore._();
  static final WishlistStore I = WishlistStore._();

  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final Set<String> _ids = <String>{};
  List<WishItem> _items = const [];

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  String? _boundUid; // ✅ para no re-binder lo mismo

  bool contains(String productId) => _ids.contains(productId);
  Set<String> get ids => _ids;

  // ✅ Para pintar la wishlist (WishlistPage)
  List<WishItem> get items => _items;

  /// ✅ Llamar cuando ya hay usuario logueado (ej: initState del Home / Wishlist)
  void bind() {
    final uid = _auth.currentUser?.uid;

    // ✅ si no hay usuario, limpiar y salir
    if (uid == null) {
      _boundUid = null;
      _sub?.cancel();
      _sub = null;
      _ids.clear();
      _items = const [];
      notifyListeners();
      return;
    }

    // ✅ evita rebind si ya está enlazado al mismo uid
    if (_boundUid == uid && _sub != null) return;
    _boundUid = uid;

    _sub?.cancel();
    _sub = null;

    // ✅ Intentamos con orderBy(createdAt). Si falla, caemos a snapshots sin orderBy.
    Query<Map<String, dynamic>> q = _fire
        .collection('usuarios')
        .doc(uid)
        .collection('wishlist');

    Stream<QuerySnapshot<Map<String, dynamic>>> stream;

    try {
      stream = q.orderBy('createdAt', descending: true).snapshots();
    } catch (_) {
      stream = q.snapshots();
    }

    _sub = stream.listen((snap) {
      // ✅ ids (para pintar el corazón en Home)
      _ids
        ..clear()
        ..addAll(snap.docs.map((d) => d.id));

      // ✅ items (cache)
      _items = snap.docs.map((d) {
        final data = d.data();

        final name = (data['name'] ?? '').toString().trim();

        final priceRaw = data['price'];
        final price = (priceRaw is num)
            ? priceRaw.toDouble()
            : double.tryParse(priceRaw?.toString() ?? '') ?? 0.0;

        final ratingRaw = data['rating'];
        final rating = (ratingRaw is num)
            ? ratingRaw.toDouble()
            : double.tryParse(ratingRaw?.toString() ?? '') ?? 0.0;

        final stockRaw = data['stock'];
        final stock = (stockRaw is num)
            ? stockRaw.toInt()
            : int.tryParse(stockRaw?.toString() ?? '') ?? 0;

        final imageUrl = (data['imageUrl'] ?? '').toString();

        return WishItem(
          id: d.id,
          name: name.isEmpty ? 'Producto' : name,
          price: price,
          rating: rating,
          stock: stock,
          imageUrl: imageUrl,
        );
      }).toList(growable: false);

      notifyListeners();
    }, onError: (_) {
      // Si el orderBy falla en runtime por índices o docs viejos, reintenta sin orderBy:
      _sub?.cancel();
      _sub = q.snapshots().listen((snap) {
        _ids
          ..clear()
          ..addAll(snap.docs.map((d) => d.id));

        _items = snap.docs.map((d) {
          final data = d.data();

          final name = (data['name'] ?? '').toString().trim();

          final priceRaw = data['price'];
          final price = (priceRaw is num)
              ? priceRaw.toDouble()
              : double.tryParse(priceRaw?.toString() ?? '') ?? 0.0;

          final ratingRaw = data['rating'];
          final rating = (ratingRaw is num)
              ? ratingRaw.toDouble()
              : double.tryParse(ratingRaw?.toString() ?? '') ?? 0.0;

          final stockRaw = data['stock'];
          final stock = (stockRaw is num)
              ? stockRaw.toInt()
              : int.tryParse(stockRaw?.toString() ?? '') ?? 0;

          final imageUrl = (data['imageUrl'] ?? '').toString();

          return WishItem(
            id: d.id,
            name: name.isEmpty ? 'Producto' : name,
            price: price,
            rating: rating,
            stock: stock,
            imageUrl: imageUrl,
          );
        }).toList(growable: false);

        notifyListeners();
      });
    });
  }

  /// ✅ Toggle persistente en Firestore (agrega/quita)
  Future<void> toggle(ProductModel p) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = _fire
        .collection('usuarios')
        .doc(uid)
        .collection('wishlist')
        .doc(p.id);

    if (_ids.contains(p.id)) {
      await ref.delete();
    } else {
      await ref.set({
        'productId': p.id,
        'createdAt': FieldValue.serverTimestamp(),

        // ✅ cache para que WishlistPage cargue rápido
        'name': p.name,
        'price': p.price,
        'imageUrl': p.imageUrl,
        'rating': p.rating,
        'stock': p.stock,
        'almacenId': p.almacenId,
      });
    }
  }

  Future<void> remove(String productId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _fire
        .collection('usuarios')
        .doc(uid)
        .collection('wishlist')
        .doc(productId)
        .delete();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ✅ Modelo para WishlistPage
class WishItem {
  final String id;
  final String name;
  final double price;
  final double rating;
  final int stock;
  final String imageUrl;

  const WishItem({
    required this.id,
    required this.name,
    required this.price,
    required this.rating,
    required this.stock,
    required this.imageUrl,
  });
}
