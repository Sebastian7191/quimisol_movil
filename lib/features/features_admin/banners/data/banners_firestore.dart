import 'package:cloud_firestore/cloud_firestore.dart';

class BannersFirestore {
  final CollectionReference<Map<String, dynamic>> _ref =
      FirebaseFirestore.instance.collection('banners');

  Stream<QuerySnapshot<Map<String, dynamic>>> bannersStream() {
    return _ref.snapshots();
  }

  Future<void> crearBanner({
    required String titulo,
    required String subtitulo,
    required String imagen,
    required String estado, // ACTIVO / INACTIVO
    required String idproducto,
  }) async {
    await _ref.doc().set({
      'titulo': titulo.trim(),
      'subtitulo': subtitulo.trim(),
      'imagen': imagen.trim(),
      'estado': estado.trim(),
      'idproducto': idproducto.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarBanner({
    required String id,
    required String titulo,
    required String subtitulo,
    required String imagen,
    required String estado,
    required String idproducto,
  }) async {
    await _ref.doc(id).update({
      'titulo': titulo.trim(),
      'subtitulo': subtitulo.trim(),
      'imagen': imagen.trim(),
      'estado': estado.trim(),
      'idproducto': idproducto.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> eliminarBanner(String id) async {
    await _ref.doc(id).delete();
  }
}
