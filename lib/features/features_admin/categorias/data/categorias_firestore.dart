import 'package:cloud_firestore/cloud_firestore.dart';

class CategoriasFirestore {
  final CollectionReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('categorias');

  /// Stream de categorías (sin orderBy para evitar problemas)
  Stream<QuerySnapshot<Map<String, dynamic>>> categoriasStream() {
    return _ref.snapshots();
  }

  Future<void> crearCategoria({
    required String nombre,
    required String descripcion,
  }) async {
    await _ref.doc().set({
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarCategoria({
    required String id,
    required String nombre,
    required String descripcion,
  }) async {
    await _ref.doc(id).update({
      'nombre': nombre.trim(),
      'descripcion': descripcion.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarCategoria(String id) async {
    await _ref.doc(id).delete();
  }
}
