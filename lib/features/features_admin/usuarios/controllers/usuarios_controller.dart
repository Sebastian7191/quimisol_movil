import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/user_row.dart';

class UsuariosController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Search & filter
  final TextEditingController searchCtrl = TextEditingController();
  String roleFilter = 'Todos';

  // ================= STREAM =================

  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream() {
    return _db
        .collection('usuarios')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  // ================= FILTER =================

  bool matches({
    required Map<String, dynamic> data,
    required String query,
    required String roleFilter,
  }) {
    final name = (data['name'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? '').toString().toLowerCase();
    final role = (data['role'] ?? '').toString().toLowerCase();

    if (roleFilter != 'Todos' && role != roleFilter) return false;
    if (query.isEmpty) return true;

    final q = query.toLowerCase();
    return name.contains(q) || email.contains(q) || role.contains(q);
  }

  // ================= MAP =================

  List<UserRow> buildUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String query,
    String roleFilter,
  ) {
    return docs
        .where(
          (d) => matches(data: d.data(), query: query, roleFilter: roleFilter),
        )
        .map((d) => UserRow.fromFirestore(d.id, d.data()))
        .toList();
  }

  // ================= ROLE =================

  Future<void> setRole({required String uid, required String role}) async {
    final userRef = _db.collection('usuarios').doc(uid);

    final adminRef = _db.collection('admins').doc(uid);
    final clienteRef = _db.collection('clientes').doc(uid);
    final repartidorRef = _db.collection('repartidores').doc(uid);

    final snap = await userRef.get();
    final userData = snap.data() ?? {};

    final payload = <String, dynamic>{
      'uid': uid,
      'role': role,
      'name': userData['name'],
      'email': userData['email'],
      'photo': userData['photo'],
      'updated_at': FieldValue.serverTimestamp(),
      'from': 'usuarios',
    };

    final batch = _db.batch();

    // usuarios
    final update = {'role': role, 'updated_at': FieldValue.serverTimestamp()};

    if (role != 'repartidor') {
      update['almacenId'] = FieldValue.delete();
    }

    batch.set(userRef, update, SetOptions(merge: true));

    // limpiar roles
    batch.delete(adminRef);
    batch.delete(clienteRef);
    batch.delete(repartidorRef);

    // asignar nuevo rol
    if (role == 'admin') {
      batch.set(adminRef, payload, SetOptions(merge: true));
    } else if (role == 'cliente') {
      batch.set(clienteRef, payload, SetOptions(merge: true));
    } else if (role == 'repartidor') {
      final almacenId = (userData['almacenId'] ?? '').toString();
      if (almacenId.isNotEmpty) payload['almacenId'] = almacenId;
      batch.set(repartidorRef, payload, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // ================= ALMACÉN =================

  Stream<QuerySnapshot<Map<String, dynamic>>> almacenesStream() {
    return _db
        .collection('almacenes')
        .where('activo', isEqualTo: true)
        .snapshots();
  }

  Future<void> setAlmacen({
    required String uid,
    required String almacenId,
  }) async {
    final batch = _db.batch();

    final userRef = _db.collection('usuarios').doc(uid);
    final repRef = _db.collection('repartidores').doc(uid);

    batch.set(repRef, {
      'almacenId': almacenId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.set(userRef, {
      'almacenId': almacenId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // ================= DISPOSE =================

  void dispose() {
    searchCtrl.dispose();
  }
}
