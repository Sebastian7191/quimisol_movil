import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';

class AlmacenesFirestore {
  final _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> almacenesStream() {
    return _db
        .collection('almacenes')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> productosStream() {
    return _db.collection('productos').snapshots();
  }

  Future<void> guardarAlmacen({
    required String nombre,
    required String departamento,
    required String descripcion,
  }) async {
    final ref = _db.collection('almacenes');

    await ref.doc().set({
      'nombre': nombre.trim(),
      'departamento': departamento,
      'descripcion': descripcion.trim(),
      'activo': true,
      'createdAt': FieldValue.serverTimestamp(),
      // opcionales (se recalculan en UI igual):
      'productos': 0,
      'stock': 0,
    });
  }

  void printIndexLink(Object error) {
    final raw = error.toString();

    final match = RegExp(
      r'(https:\/\/console\.firebase\.google\.com\/[^\s]+)',
    ).firstMatch(raw);

    if (match != null) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ CREA EL ÍNDICE AQUÍ:');
      debugPrint(match.group(1));
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } else {
      debugPrint('🔥 Firestore error (sin link encontrado): $raw');
    }
  }
}
