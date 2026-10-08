import 'package:cloud_firestore/cloud_firestore.dart';

class RepartidorOption {
  final String uid;
  final String nombre;
  final String almacenId;

  RepartidorOption({
    required this.uid,
    required this.nombre,
    required this.almacenId,
  });

  factory RepartidorOption.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final data = d.data();

    return RepartidorOption(
      uid: d.id,
      nombre: (data['name'] ?? data['nombre'] ?? 'Repartidor').toString(),
      almacenId: (data['almacenId'] ?? '').toString(),
    );
  }
}