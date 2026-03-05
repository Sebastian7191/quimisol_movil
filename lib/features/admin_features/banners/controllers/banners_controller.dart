import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/banners_firestore.dart';

class BannersController {
  final firestore = BannersFirestore();

  final TextEditingController searchCtrl = TextEditingController();
  String search = '';

  BannersController() {
    searchCtrl.addListener(() {
      search = searchCtrl.text.trim().toLowerCase();
    });
  }

  void dispose() {
    searchCtrl.dispose();
  }

  /// Stream público para la UI
  Stream<QuerySnapshot<Map<String, dynamic>>> bannersStream() {
    return firestore.bannersStream();
  }

  /// Map + sort + filter
  List<Map<String, dynamic>> buildCards(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final rows = docs.map((d) {
      final data = d.data();
      final ts = data['createdAt'];
      DateTime? created;
      if (ts is Timestamp) created = ts.toDate();

      return {
        'docId': d.id,
        'titulo': (data['titulo'] ?? '').toString(),
        'subtitulo': (data['subtitulo'] ?? '').toString(),
        'imagen': (data['imagen'] ?? '').toString(),
        'estado': (data['estado'] ?? 'INACTIVO').toString(),
        'idproducto': (data['idproducto'] ?? '').toString(),
        'createdAt': created,
      };
    }).toList();

    // sort por createdAt desc
    rows.sort((a, b) {
      final da = a['createdAt'] as DateTime?;
      final db = b['createdAt'] as DateTime?;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    // filtro búsqueda
    if (search.isEmpty) return rows;

    return rows.where((r) {
      final t = (r['titulo'] as String).toLowerCase();
      final s = (r['subtitulo'] as String).toLowerCase();
      final p = (r['idproducto'] as String).toLowerCase();
      return t.contains(search) || s.contains(search) || p.contains(search);
    }).toList();
  }

  Future<void> crearBanner({
    required String titulo,
    required String subtitulo,
    required String imagen,
    required String estado, // ACTIVO / INACTIVO
    required String idproducto,
  }) {
    return firestore.crearBanner(
      titulo: titulo,
      subtitulo: subtitulo,
      imagen: imagen,
      estado: estado,
      idproducto: idproducto,
    );
  }

  Future<void> actualizarBanner({
    required String docId,
    required String titulo,
    required String subtitulo,
    required String imagen,
    required String estado,
    required String idproducto,
  }) {
    return firestore.actualizarBanner(
      id: docId,
      titulo: titulo,
      subtitulo: subtitulo,
      imagen: imagen,
      estado: estado,
      idproducto: idproducto,
    );
  }

  Future<void> eliminarBanner(String docId) {
    return firestore.eliminarBanner(docId);
  }
}
