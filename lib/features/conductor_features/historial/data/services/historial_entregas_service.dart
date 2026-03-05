import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialEntregasService {
  final FirebaseFirestore _db;

  HistorialEntregasService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _pedidos =>
      _db.collection('pedidos');

  /// ✅ Método que tu Page ya está llamando
  /// Historial (idealmente entregados). Si aún no tienes estado "Entregado",
  /// puedes dejarlo sin filtro por estado.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamEntregas(String repartidorUid) {
    return _pedidos
        .where('repartidorUid', isEqualTo: repartidorUid)
        // 👇 si YA tienes estado entregado, descomenta y ajusta el texto exacto
        // .where('estado', isEqualTo: 'Entregado')
        .orderBy('updatedAt', descending: true) // ✅ existe en tu doc
        .limit(100)
        .snapshots();
  }

  /// ✅ Solo entregados (cuando definas bien el estado)
  Stream<QuerySnapshot<Map<String, dynamic>>> streamEntregados(String repartidorUid) {
    return _pedidos
        .where('repartidorUid', isEqualTo: repartidorUid)
        .where('estado', isEqualTo: 'Entregado') // ajusta exacto
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .snapshots();
  }
}
