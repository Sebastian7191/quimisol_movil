import 'package:flutter/material.dart';

class Formulario3ResultadoItem {
  int item;

  final TextEditingController parametrosCtrl;
  final TextEditingController metodoEnsayoCtrl;
  final TextEditingController unidadCtrl;
  final TextEditingController ldCtrl;
  final TextEditingController limitesMaximosCtrl;
  final TextEditingController resultadosCtrl;

  Formulario3ResultadoItem({
    required this.item,
    String parametros = '',
    String metodoEnsayo = '',
    String unidad = '',
    String ld = '',
    String limitesMaximos = '',
    String resultados = '',
  })  : parametrosCtrl = TextEditingController(text: parametros),
        metodoEnsayoCtrl = TextEditingController(text: metodoEnsayo),
        unidadCtrl = TextEditingController(text: unidad),
        ldCtrl = TextEditingController(text: ld),
        limitesMaximosCtrl = TextEditingController(text: limitesMaximos),
        resultadosCtrl = TextEditingController(text: resultados);

  factory Formulario3ResultadoItem.fromMap(Map<String, dynamic> map) {
    return Formulario3ResultadoItem(
      item: (map['item'] as num?)?.toInt() ?? 1,
      parametros: (map['parametros'] ?? '').toString(),
      metodoEnsayo: (map['metodoEnsayo'] ?? '').toString(),
      unidad: (map['unidad'] ?? '').toString(),
      ld: (map['ld'] ?? '').toString(),
      limitesMaximos: (map['limitesMaximos'] ?? '').toString(),
      resultados: (map['resultados'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'item': item,
      'parametros': parametrosCtrl.text.trim(),
      'metodoEnsayo': metodoEnsayoCtrl.text.trim(),
      'unidad': unidadCtrl.text.trim(),
      'ld': ldCtrl.text.trim(),
      'limitesMaximos': limitesMaximosCtrl.text.trim(),
      'resultados': resultadosCtrl.text.trim(),
    };
  }

  void dispose() {
    parametrosCtrl.dispose();
    metodoEnsayoCtrl.dispose();
    unidadCtrl.dispose();
    ldCtrl.dispose();
    limitesMaximosCtrl.dispose();
    resultadosCtrl.dispose();
  }
}