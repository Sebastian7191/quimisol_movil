// lib/features/pasajeros_features/pedidos/services/pedido_review_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PedidoReviewService {
  final _fire = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String get _uid => _auth.currentUser?.uid ?? '';

  /// Stream en tiempo real de pedidos Entregados (hasta 10, por fecha desc).
  /// El listener filtra en el cliente cuáles aún no tienen reviewEntrega.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchDeliveredOrders() {
    if (_uid.isEmpty) return const Stream.empty();

    return _fire
        .collection('pedidos')
        .where('uid', isEqualTo: _uid)
        .where('estado', isEqualTo: 'Entregado')
        .orderBy('updatedAt', descending: true)
        .limit(10)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPagosRechazados() {
    if (_uid.isEmpty) return const Stream.empty();
    return _fire
        .collection('pedidos')
        .where('uid', isEqualTo: _uid)
        .where('estado_pago', isEqualTo: 'rechazado')
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> findPendingDeliveredOrder() async {
    if (_uid.isEmpty) return null;

    final snap = await _fire
        .collection('pedidos')
        .where('uid', isEqualTo: _uid)
        .where('estado', isEqualTo: 'Entregado')
        .orderBy('updatedAt', descending: true)
        .limit(10)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final reviewEntrega = data['reviewEntrega'];
      if (reviewEntrega == null) {
        return doc;
      }
    }

    return null;
  }

  /// Marca el pedido como "sin reseña" para que no vuelva a aparecer el flujo.
  Future<void> skipEntregaReview({required String pedidoId}) async {
    if (_uid.isEmpty) return;

    await _fire.collection('pedidos').doc(pedidoId).set({
      'reviewEntrega': {
        'clienteUid': _uid,
        'skipped': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> saveEntregaReview({
    required String pedidoId,
    required int rating,
    required String comentario,
  }) async {
    if (_uid.isEmpty) return;

    await _fire.collection('pedidos').doc(pedidoId).set({
      'reviewEntrega': {
        'clienteUid': _uid,
        'rating': rating,
        'comentario': comentario.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> saveProductReviews({
    required String pedidoId,
    required List<Map<String, dynamic>> reviews,
  }) async {
    if (_uid.isEmpty) return;

    final batch = _fire.batch();

    for (final r in reviews) {
      final productId = (r['productId'] ?? '').toString().trim();
      if (productId.isEmpty) continue;

      final productName = (r['name'] ?? '').toString().trim();
      final imageUrl = (r['imageUrl'] ?? '').toString().trim();
      final rating = (r['rating'] ?? 0) as int;
      final comentario = (r['comentario'] ?? '').toString().trim();

      final pedidoReviewRef = _fire
          .collection('pedidos')
          .doc(pedidoId)
          .collection('reviewsProductos')
          .doc(productId);

      batch.set(pedidoReviewRef, {
        'pedidoId': pedidoId,
        'productId': productId,
        'clienteUid': _uid,
        'productName': productName,
        'imageUrl': imageUrl,
        'rating': rating,
        'comentario': comentario,
        'createdAt': FieldValue.serverTimestamp(),
      });

      final globalProductReviewRef = _fire
          .collection('productos')
          .doc(productId)
          .collection('reviews')
          .doc();

      batch.set(globalProductReviewRef, {
        'pedidoId': pedidoId,
        'productId': productId,
        'clienteUid': _uid,
        'productName': productName,
        'imageUrl': imageUrl,
        'rating': rating,
        'comentario': comentario,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }
}