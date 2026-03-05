import 'package:cloud_firestore/cloud_firestore.dart';


class DashboardFirestore {
  final FirebaseFirestore _db;
  DashboardFirestore(this._db);

  Stream<QuerySnapshot<Map<String, dynamic>>> pedidosStream({
    DateTime? from,
    String? estado,
    String? departamento,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('pedidos');

    if (from != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (departamento != null) {
      q = q.where('departamento', isEqualTo: departamento);
    }

    // Estado: tu BD guarda "En camino" con mayúsculas.
    // No podemos hacer where case-insensitive, así que si filtras por estado,
    // aplicamos un where por la forma "bonita".
    if (estado != null) {
      q = q.where('estado', isEqualTo: _prettyEstado(estado));
    }

    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> productosStream({
    String? almacenId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('productos');
    if (almacenId != null) {
      q = q.where('almacenId', isEqualTo: almacenId);
    }
    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> usuariosStream() =>
      _db.collection('usuarios').snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> almacenesStream() =>
      _db.collection('almacenes').where('activo', isEqualTo: true).snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> repartidoresStream({
    String? almacenId,
  }) {
    Query<Map<String, dynamic>> q = _db.collection('repartidores');
    if (almacenId != null) {
      q = q.where('almacenId', isEqualTo: almacenId);
    }
    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> bannersStream() =>
      _db.collection('banners').snapshots();

  static String _prettyEstado(String raw) {
    final e = raw.trim().toLowerCase();
    if (e == 'pendiente') return 'Pendiente';
    if (e == 'aceptado') return 'Aceptado';
    if (e == 'en camino' || e == 'en_camino' || e == 'encamino') return 'En camino';
    if (e == 'entregado') return 'Entregado';
    if (e == 'cancelado') return 'Cancelado';
    return raw;
  }
}
