// lib/features/admin/productos/controllers/productos_descuentos_controller.dart
//
// ✅ Descuentos por producto (subcolección)
// ✅ Evita errores: NO usa Transaction.get(Query)
// ✅ Mantiene "solo 1 descuento activado" usando batch
// ✅ Deja un resumen en /productos/{productoId} para lectura rápida en móvil
//
// Colecciones:
// - productos/{productoId}
// - productos/{productoId}/descuentos/{descuentoId}
//
// Campos sugeridos en descuento:
//   tipo: "PORCENTAJE" | "MONTO"
//   valor: number
//   estado: "activado" | "desactivado"
//   createdAt, updatedAt: serverTimestamp
//
// Campos sugeridos en producto:
//   descuentoActivo: bool
//   descuentoTipo: "PORCENTAJE" | "MONTO" (opcional)
//   descuentoValor: number (opcional)
//   descuentoIdActivo: string (opcional)
//   descuentoUpdatedAt: timestamp (opcional)

import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos pedidos por ti: PORCENTAJE y MONTO
enum TipoDescuento { porcentaje, monto }

TipoDescuento tipoDescuentoFromString(String? v) {
  final s = (v ?? '').trim().toUpperCase();
  if (s == 'MONTO') return TipoDescuento.monto;
  return TipoDescuento.porcentaje; // default
}

String tipoDescuentoToString(TipoDescuento t) {
  return t == TipoDescuento.monto ? 'MONTO' : 'PORCENTAJE';
}

class DescuentoModel {
  final String id;
  final String productoId;

  final String tipo; // "PORCENTAJE" | "MONTO"
  final num valor; // e.g. 20 (si porcentaje = 20%), si monto = 20 Bs
  final String estado; // "activado" | "desactivado"

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DescuentoModel({
    required this.id,
    required this.productoId,
    required this.tipo,
    required this.valor,
    required this.estado,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActivo => estado == 'activado';

  Map<String, dynamic> toMap() {
    return {
      'productoId': productoId,
      'tipo': tipo,
      'valor': valor,
      'estado': estado,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DescuentoModel fromDoc(
    String productoId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final created = data['createdAt'];
    final updated = data['updatedAt'];

    return DescuentoModel(
      id: doc.id,
      productoId: productoId,
      tipo: (data['tipo'] ?? 'PORCENTAJE').toString(),
      valor: (data['valor'] is num) ? (data['valor'] as num) : 0,
      estado: (data['estado'] ?? 'desactivado').toString(),
      createdAt: created is Timestamp ? created.toDate() : null,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }
}

class ProductosDescuentosController {
  ProductosDescuentosController({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _productosRef() =>
      _db.collection('productos');

  DocumentReference<Map<String, dynamic>> productoRef(String productoId) =>
      _productosRef().doc(productoId);

  CollectionReference<Map<String, dynamic>> descuentosRef(String productoId) =>
      productoRef(productoId).collection('descuentos');

  /// ---------- Lecturas ----------

  Stream<List<DescuentoModel>> streamDescuentos(String productoId) {
    return descuentosRef(productoId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) => DescuentoModel.fromDoc(productoId, d)).toList());
  }

  Stream<DescuentoModel?> streamDescuentoActivo(String productoId) {
    return descuentosRef(productoId)
        .where('estado', isEqualTo: 'activado')
        .limit(1)
        .snapshots()
        .map((qs) {
      if (qs.docs.isEmpty) return null;
      return DescuentoModel.fromDoc(productoId, qs.docs.first);
    });
  }

  Future<DescuentoModel?> getDescuentoActivo(String productoId) async {
    final qs = await descuentosRef(productoId)
        .where('estado', isEqualTo: 'activado')
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;
    return DescuentoModel.fromDoc(productoId, qs.docs.first);
  }

  /// ---------- Lógica de precio ----------

  /// Calcula el precio final dado un precio base.
  /// - PORCENTAJE: 20 => -20%
  /// - MONTO: 20 => -20 Bs
  /// Nunca baja de 0.
  double precioConDescuento({
    required double precioBase,
    required TipoDescuento tipo,
    required double valor,
  }) {
    double finalPrice = precioBase;

    if (tipo == TipoDescuento.porcentaje) {
      final pct = valor.clamp(0, 100);
      finalPrice = precioBase - (precioBase * (pct / 100.0));
    } else {
      finalPrice = precioBase - valor;
    }

    if (finalPrice.isNaN || finalPrice.isInfinite) return precioBase;
    if (finalPrice < 0) return 0.0;
    return finalPrice;
  }

  /// ---------- Escrituras ----------

  /// Crea un descuento.
  /// Si [activar] es true:
  /// - desactiva cualquiera que esté activado
  /// - activa este descuento
  /// - actualiza resumen del descuento en /productos/{productoId}
  Future<void> crearDescuento({
    required String productoId,
    required TipoDescuento tipo,
    required num valor,
    bool activar = true,
  }) async {
    final tipoStr = tipoDescuentoToString(tipo);

    _validarValor(tipo, valor);

    // pre-lectura para batch (evitar Transaction.get(query))
    final activos = await descuentosRef(productoId)
        .where('estado', isEqualTo: 'activado')
        .get();

    final newDoc = descuentosRef(productoId).doc();

    final batch = _db.batch();

    // 1) desactivar activos
    for (final d in activos.docs) {
      batch.update(d.reference, {
        'estado': 'desactivado',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // 2) crear nuevo
    batch.set(newDoc, {
      'productoId': productoId,
      'tipo': tipoStr,
      'valor': valor,
      'estado': activar ? 'activado' : 'desactivado',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 3) resumen en producto
    if (activar) {
      batch.update(productoRef(productoId), {
        'descuentoActivo': true,
        'descuentoTipo': tipoStr,
        'descuentoValor': valor,
        'descuentoIdActivo': newDoc.id,
        'descuentoUpdatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // si lo creas desactivado, no tocamos resumen
      // (o puedes forzarlo a false si quieres)
    }

    await batch.commit();
  }

  /// Activa un descuento existente, desactivando los demás.
  Future<void> activarDescuento({
    required String productoId,
    required String descuentoId,
  }) async {
    final ref = descuentosRef(productoId).doc(descuentoId);

    final doc = await ref.get();
    if (!doc.exists) {
      throw Exception('El descuento no existe.');
    }

    final data = doc.data() ?? {};
    final tipoStr = (data['tipo'] ?? 'PORCENTAJE').toString();
    final valor = (data['valor'] is num) ? (data['valor'] as num) : 0;

    // pre-lectura activos
    final activos = await descuentosRef(productoId)
        .where('estado', isEqualTo: 'activado')
        .get();

    final batch = _db.batch();

    // desactivar otros activos
    for (final d in activos.docs) {
      if (d.id == descuentoId) continue;
      batch.update(d.reference, {
        'estado': 'desactivado',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // activar este
    batch.update(ref, {
      'estado': 'activado',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // resumen producto
    batch.update(productoRef(productoId), {
      'descuentoActivo': true,
      'descuentoTipo': tipoStr,
      'descuentoValor': valor,
      'descuentoIdActivo': descuentoId,
      'descuentoUpdatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Desactiva un descuento.
  /// Si era el activo, apaga el resumen en producto.
  Future<void> desactivarDescuento({
    required String productoId,
    required String descuentoId,
  }) async {
    final ref = descuentosRef(productoId).doc(descuentoId);

    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final eraActivo = (data['estado'] ?? '') == 'activado';

    final batch = _db.batch();

    batch.update(ref, {
      'estado': 'desactivado',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (eraActivo) {
      batch.update(productoRef(productoId), {
        'descuentoActivo': false,
        'descuentoTipo': FieldValue.delete(),
        'descuentoValor': FieldValue.delete(),
        'descuentoIdActivo': FieldValue.delete(),
        'descuentoUpdatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Elimina un descuento.
  /// Si era el activo, también apaga el resumen en producto.
  Future<void> eliminarDescuento({
    required String productoId,
    required String descuentoId,
  }) async {
    final ref = descuentosRef(productoId).doc(descuentoId);

    final doc = await ref.get();
    if (!doc.exists) return;

    final data = doc.data() ?? {};
    final eraActivo = (data['estado'] ?? '') == 'activado';

    final batch = _db.batch();
    batch.delete(ref);

    if (eraActivo) {
      batch.update(productoRef(productoId), {
        'descuentoActivo': false,
        'descuentoTipo': FieldValue.delete(),
        'descuentoValor': FieldValue.delete(),
        'descuentoIdActivo': FieldValue.delete(),
        'descuentoUpdatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// ---------- Validación ----------
  void _validarValor(TipoDescuento tipo, num valor) {
    final v = valor.toDouble();
    if (v.isNaN || v.isInfinite) {
      throw Exception('Valor de descuento inválido.');
    }

    if (v < 0) {
      throw Exception('El descuento no puede ser negativo.');
    }

    if (tipo == TipoDescuento.porcentaje && v > 100) {
      throw Exception('El porcentaje no puede ser mayor a 100.');
    }
  }
}
