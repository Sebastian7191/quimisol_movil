import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/unidades_firestore.dart';

class UnidadesController {
  final firestore = UnidadesFirestore();

  final TextEditingController searchCtrl = TextEditingController();
  String search = '';

  UnidadesController() {
    searchCtrl.addListener(() {
      search = searchCtrl.text.trim().toLowerCase();
    });
  }

  void dispose() {
    searchCtrl.dispose();
  }

  /// Stream público para la UI
  Stream<QuerySnapshot<Map<String, dynamic>>> unidadesStream() {
    return firestore.unidadesStream();
  }

  /// Map + sort + filter (MISMA lógica que ya tenías)
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
        'abreviatura': (data['abreviatura'] ?? '').toString(),
        'descripcion': (data['descripcion'] ?? '').toString(),
        'createdAt': created,
      };
    }).toList();

    // sort por createdAt
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
      final ab = (r['abreviatura'] as String).toLowerCase();
      return n.contains(search) || ab.contains(search);
    }).toList();
  }

  Future<void> crearUnidad({
    required String nombre,
    required String abreviatura,
    required String descripcion,
  }) {
    return firestore.crearUnidad(
      nombre: nombre,
      abreviatura: abreviatura,
      descripcion: descripcion,
    );
  }

  Future<void> actualizarUnidad({
    required String id,
    required String nombre,
    required String abreviatura,
    required String descripcion,
  }) {
    return firestore.actualizarUnidad(
      id: id,
      nombre: nombre,
      abreviatura: abreviatura,
      descripcion: descripcion,
    );
  }

  Future<void> eliminarUnidad(String id) {
    return firestore.eliminarUnidad(id);
  }
}