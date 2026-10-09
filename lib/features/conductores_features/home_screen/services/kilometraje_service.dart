import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Kilometraje de los repartidores.
///
/// Se guarda en dos lugares:
///
/// 1. En cada pedido, campo `kilometraje` (mapa):
///    - distanciaInicialKm / duracionInicialMin: ruta calculada al marcar
///      "En camino".
///    - desvioKm / desvioMin / desvios: lo que se fue sumando cuando la ruta
///      recalculada quedó más larga que la anterior (el repartidor se desvió).
///    - distanciaTotalKm / duracionTotalMin: inicial + desvíos.
///    - fecha ("yyyy-MM-dd"), fechaEnCamino, repartidorUid, repartidorNombre.
///
/// 2. Totales por repartidor y día en
///    `repartidores_km_diario/{repartidorUid}_{yyyy-MM-dd}`:
///    kmInicial, kmDesvio, kmTotal, minInicial, minDesvio, minTotal, viajes,
///    desvios, fecha, fechaTs, repartidorUid, repartidorNombre, departamento.
class KilometrajeService {
  KilometrajeService({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String coleccionDiaria = 'repartidores_km_diario';

  /// Día local (Bolivia) en formato "yyyy-MM-dd".
  static String fechaKey(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  static double _r2(double v) => double.parse(v.toStringAsFixed(2));
  static double _r1(double v) => double.parse(v.toStringAsFixed(1));

  /// Mapa `kilometraje` del pedido al iniciar el viaje.
  static Map<String, dynamic> datosIniciales({
    required double km,
    required double min,
    required String fecha,
    required String repartidorUid,
    String? repartidorNombre,
  }) {
    final k = _r2(km);
    final m = _r1(min);
    return {
      // Campos anteriores (se mantienen por compatibilidad).
      'distanciaKm': k,
      'duracionEstimadaMin': m,
      'distanciaInicialKm': k,
      'duracionInicialMin': m,
      'desvioKm': 0.0,
      'desvioMin': 0.0,
      'desvios': 0,
      'distanciaTotalKm': k,
      'duracionTotalMin': m,
      'fecha': fecha,
      'fechaEnCamino': FieldValue.serverTimestamp(),
      'repartidorUid': repartidorUid,
      if (repartidorNombre != null && repartidorNombre.isNotEmpty)
        'repartidorNombre': repartidorNombre,
    };
  }

  /// Suma un viaje nuevo a los totales del día.
  Future<void> sumarViajeAlDia({
    required String repartidorUid,
    required String fecha,
    required double km,
    required double min,
    String? repartidorNombre,
    String? departamento,
  }) {
    return _sumarAlDia(
      repartidorUid: repartidorUid,
      fecha: fecha,
      repartidorNombre: repartidorNombre,
      departamento: departamento,
      incrementos: {
        'kmInicial': _r2(km),
        'kmTotal': _r2(km),
        'minInicial': _r1(min),
        'minTotal': _r1(min),
        'viajes': 1,
      },
    );
  }

  /// Registra un desvío: lo suma al pedido y a los totales del día.
  Future<void> registrarDesvio({
    required String pedidoId,
    required String repartidorUid,
    required String fecha,
    required double extraKm,
    required double extraMin,
    String? repartidorNombre,
    String? departamento,
  }) async {
    final km = _r2(extraKm);
    final min = _r1(extraMin);

    try {
      await _db.collection('pedidos').doc(pedidoId).update({
        'kilometraje.desvioKm': FieldValue.increment(km),
        'kilometraje.desvioMin': FieldValue.increment(min),
        'kilometraje.desvios': FieldValue.increment(1),
        'kilometraje.distanciaTotalKm': FieldValue.increment(km),
        'kilometraje.duracionTotalMin': FieldValue.increment(min),
        'kilometraje.ultimoDesvioAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('KilometrajeService: no se pudo guardar desvío en pedido: $e');
    }

    await _sumarAlDia(
      repartidorUid: repartidorUid,
      fecha: fecha,
      repartidorNombre: repartidorNombre,
      departamento: departamento,
      incrementos: {
        'kmDesvio': km,
        'kmTotal': km,
        'minDesvio': min,
        'minTotal': min,
        'desvios': 1,
      },
    );
  }

  Future<void> _sumarAlDia({
    required String repartidorUid,
    required String fecha,
    required Map<String, num> incrementos,
    String? repartidorNombre,
    String? departamento,
  }) async {
    // Nunca debe frenar el flujo del pedido: si falla (p. ej. reglas de
    // Firestore), solo se registra en el log.
    try {
      final partes = fecha.split('-').map(int.parse).toList();
      await _db.collection(coleccionDiaria).doc('${repartidorUid}_$fecha').set({
        'repartidorUid': repartidorUid,
        'fecha': fecha,
        'fechaTs': Timestamp.fromDate(
          DateTime(partes[0], partes[1], partes[2]),
        ),
        if (repartidorNombre != null && repartidorNombre.isNotEmpty)
          'repartidorNombre': repartidorNombre,
        if (departamento != null && departamento.isNotEmpty)
          'departamento': departamento,
        'updatedAt': FieldValue.serverTimestamp(),
        for (final e in incrementos.entries)
          e.key: FieldValue.increment(e.value),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('KilometrajeService: no se pudo actualizar el día: $e');
    }
  }
}
