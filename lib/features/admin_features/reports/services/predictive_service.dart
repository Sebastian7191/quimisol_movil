import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class PredictiveReportService {
  PredictiveReportService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions = (functions ?? FirebaseFunctions.instanceFor(region: 'us-central1')),
        _db = (firestore ?? FirebaseFirestore.instance);

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;

  /// Llama a generatePredictiveReportOnDemand y devuelve reportId
  Future<String> generate({
    int historyWeeks = 12,
    int horizonDays = 28,
    bool deliveredOnly = true,
    int? limitProducts,
    String? departamento,
  }) async {
    final callable = _functions.httpsCallable('generatePredictiveReportOnDemand');

    final params = <String, dynamic>{
      'historyWeeks': historyWeeks,
      'horizonDays': horizonDays,
      'deliveredOnly': deliveredOnly,
      if (limitProducts != null) 'limitProducts': limitProducts,
      if (departamento != null && departamento.trim().isNotEmpty) 'departamento': departamento.trim(),
    };

    final res = await callable.call(params);

    final data = (res.data as Map?)?.cast<String, dynamic>();
    if (data == null || data['ok'] != true || data['reportId'] == null) {
      throw StateError('Respuesta inesperada de la Cloud Function: ${res.data}');
    }
    return data['reportId'] as String;
  }

  /// Stream del doc del reporte
  Stream<DocumentSnapshot<Map<String, dynamic>>> reportStream(String reportId) {
    return _db.collection('reports').doc(reportId).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> reportOnce(String reportId) {
    return _db.collection('reports').doc(reportId).get();
  }
}