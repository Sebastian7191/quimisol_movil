import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:quimisol_movil/features/features_admin/almacenes/data/almacenes_firestore.dart';

class AlmacenesController {
  String selectedDepto = 'Todos';

  final departamentos = const [
    'Todos',
    'La Paz',
    'Cochabamba',
    'Santa Cruz',
    'Oruro',
    'Potosí',
    'Chuquisaca',
    'Tarija',
    'Beni',
    'Pando',
  ];

  final firestore = AlmacenesFirestore();

  Stream<QuerySnapshot<Map<String, dynamic>>> almacenesStream() {
    return firestore.almacenesStream();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> productosStream() {
    return firestore.productosStream();
  }

  Future<void> guardarAlmacen({
    required String nombre,
    required String departamento,
    required String descripcion,
    String ubicacion = '',
  }) async {
    return firestore.guardarAlmacen(
      nombre: nombre,
      departamento: departamento,
      descripcion: descripcion,
      ubicacion: ubicacion,
    );
  }

  void printFirestoreIndexLink(Object error) {
    firestore.printIndexLink(error);
  }

  /// Construye la lista de almacenes ya con los cálculos de productos/stock
  /// y aplica el filtro por departamento (usa `selectedDepto`).
  List<Map<String, dynamic>> buildAlmacenesList(
    List<dynamic> almacenesDocs,
    List<dynamic> productosDocs,
  ) {
    final Map<String, int> productosCountByAlmacen = {};
    final Map<String, int> stockTotalByAlmacen = {};

    for (final p in productosDocs) {
      final data = (p as QueryDocumentSnapshot<Map<String, dynamic>>).data();
      final almacenId = (data['almacenId'] ?? '').toString().trim();
      if (almacenId.isEmpty) continue;

      final stockRaw = data['stock'];
      final stock = (stockRaw is num) ? stockRaw.toInt() : 0;

      productosCountByAlmacen[almacenId] =
          (productosCountByAlmacen[almacenId] ?? 0) + 1;

      stockTotalByAlmacen[almacenId] =
          (stockTotalByAlmacen[almacenId] ?? 0) + stock;
    }

    final all = almacenesDocs.map((d) {
      final doc = d as QueryDocumentSnapshot<Map<String, dynamic>>;
      final data = doc.data();
      final id = doc.id;

      final productos = productosCountByAlmacen[id] ?? 0;
      final stock = stockTotalByAlmacen[id] ?? 0;

      return {
        'id': id,
        'nombre': (data['nombre'] ?? '').toString(),
        'departamento': (data['departamento'] ?? '').toString(),
        'descripcion': (data['descripcion'] ?? '').toString(),
        'ubicacion': (data['ubicacion'] ?? '').toString(),
        'productos': productos,
        'stock': stock,
        'activo': (data['activo'] is bool) ? (data['activo'] as bool) : true,
      };
    }).toList();

    if (selectedDepto == 'Todos') return all;
    return all.where((a) => a['departamento'] == selectedDepto).toList();
  }
}


