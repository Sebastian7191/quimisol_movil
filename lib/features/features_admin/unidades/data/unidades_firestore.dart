import 'package:cloud_firestore/cloud_firestore.dart';

class UnidadesFirestore {
  final CollectionReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('unidades');

  /// Stream de unidades (sin orderBy para evitar problemas)
  Stream<QuerySnapshot<Map<String, dynamic>>> unidadesStream() {
    return _ref.snapshots();
  }

  Future<void> crearUnidad({
    required String nombre,
    required String abreviatura,
    required String descripcion,
  }) async {
    await _ref.doc().set({
      'nombre': nombre.trim(),
      'abreviatura': abreviatura.trim(),
      'descripcion': descripcion.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarUnidad({
    required String id,
    required String nombre,
    required String abreviatura,
    required String descripcion,
  }) async {
    await _ref.doc(id).update({
      'nombre': nombre.trim(),
      'abreviatura': abreviatura.trim(),
      'descripcion': descripcion.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarUnidad(String id) async {
    await _ref.doc(id).delete();
  }
}
