import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/categorias_firestore.dart';

class CategoriasController {
  final firestore = CategoriasFirestore();

  final TextEditingController searchCtrl = TextEditingController();
  String search = '';

  CategoriasController() {
    searchCtrl.addListener(() {
      search = searchCtrl.text.trim().toLowerCase();
    });
  }

  void dispose() {
    searchCtrl.dispose();
  }

  /// Stream público para la UI
  Stream<QuerySnapshot<Map<String, dynamic>>> categoriasStream() {
    return firestore.categoriasStream();
  }

  /// Map + sort + filter (misma lógica que unidades)
  List<Map<String, dynamic>> buildRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final rows = docs.map((d) {
      final data = d.data();
      final ts = data['createdAt'];
      DateTime? created;
      if (ts is Timestamp) created = ts.toDate();

      return {
        'id': d.id,
        'nombre': (data['nombre'] ?? '').toString(),
        'descripcion': (data['descripcion'] ?? '').toString(),
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
      final n = (r['nombre'] as String).toLowerCase();
      final d = (r['descripcion'] as String).toLowerCase();
      return n.contains(search) || d.contains(search);
    }).toList();
  }

  Future<void> crearCategoria({
    required String nombre,
    required String descripcion,
  }) {
    return firestore.crearCategoria(
      nombre: nombre,
      descripcion: descripcion,
    );
  }

  Future<void> actualizarCategoria({
    required String id,
    required String nombre,
    required String descripcion,
  }) {
    return firestore.actualizarCategoria(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
    );
  }

  Future<void> eliminarCategoria(String id) {
    return firestore.eliminarCategoria(id);
  }
}
